import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

enum _Source { text, file }

class AddBookPage extends StatefulWidget {
  const AddBookPage({super.key});

  @override
  State<AddBookPage> createState() => _AddBookPageState();
}

class _ChapterDraft {
  _ChapterDraft({required String title, required this.content})
      : titleController = TextEditingController(text: title);

  final String content;
  final TextEditingController titleController;

  void dispose() => titleController.dispose();
}

class _QuestionDraft {
  final questionController = TextEditingController();
  final optionAController = TextEditingController();
  final optionBController = TextEditingController();
  final optionCController = TextEditingController();
  String correctOption = 'A';
  int? chapterIndex;

  void dispose() {
    questionController.dispose();
    optionAController.dispose();
    optionBController.dispose();
    optionCController.dispose();
  }

  Map<String, dynamic> toJson() {
    return {
      'question': questionController.text.trim(),
      'correct_option': correctOption,
      if (chapterIndex != null) 'chapter_index': chapterIndex,
      'options': [
        {'option_key': 'A', 'content': optionAController.text.trim()},
        {'option_key': 'B', 'content': optionBController.text.trim()},
        {'option_key': 'C', 'content': optionCController.text.trim()},
      ],
    };
  }
}

class _AddBookPageState extends State<AddBookPage> {
  final _apiService = ApiService();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  final _contentController = TextEditingController();
  String _level = 'LEVEL_2';
  _Source _source = _Source.text;
  final List<_ChapterDraft> _chapters = [];
  final List<_QuestionDraft> _questions = [];
  bool _saving = false;
  bool _generatingAI = false;
  bool _parsing = false;
  String? _fileName;
  String? _error;

  static const _levels = [
    ('LEVEL_1', 'Level 1 · 启蒙'),
    ('LEVEL_2', 'Level 2 · 基础'),
    ('LEVEL_3', 'Level 3 · 进阶'),
    ('LEVEL_4', 'Level 4 · 提高'),
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _contentController.dispose();
    for (final chapter in _chapters) {
      chapter.dispose();
    }
    for (final question in _questions) {
      question.dispose();
    }
    super.dispose();
  }

  void _applyParsed(List<ParsedChapter> chapters) {
    for (final chapter in _chapters) {
      chapter.dispose();
    }
    for (final question in _questions) {
      question.dispose();
    }
    _chapters.clear();
    _questions.clear();

    final chapterDrafts = <_ChapterDraft>[];
    final questionDrafts = <_QuestionDraft>[];
    for (var i = 0; i < chapters.length; i++) {
      chapterDrafts.add(
        _ChapterDraft(title: chapters[i].title, content: chapters[i].content),
      );
      for (var j = 0; j < 3; j++) {
        final question = _QuestionDraft();
        question.chapterIndex = i;
        questionDrafts.add(question);
      }
    }

    setState(() {
      _chapters.addAll(chapterDrafts);
      _questions.addAll(questionDrafts);
    });
  }

  Future<void> _parseText() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      setState(() => _error = '请先填写正文');
      return;
    }

    setState(() {
      _parsing = true;
      _error = null;
    });

    try {
      final parsed = await _apiService.parseText(content);
      if (!mounted) return;
      _applyParsed(parsed.chapters);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _parsing = false);
    }
  }

  Future<void> _pickAndParseFile() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt', 'md'],
    );
    if (file == null) return;

    setState(() {
      _parsing = true;
      _error = null;
    });

    try {
      final bytes = await file.readAsBytes();
      final parsed = await _apiService.parseEbook(
        filename: file.name,
        bytes: bytes,
      );

      if (!mounted) return;
      setState(() {
        _fileName = file.name;
        if (_titleController.text.trim().isEmpty) {
          _titleController.text = file.name.replaceAll(
            RegExp(r'\.(pdf|txt|md)$', caseSensitive: false),
            '',
          );
        }
      });
      _applyParsed(parsed.chapters);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _parsing = false);
    }
  }

  void _addQuestionForChapter(int index) {
    final draft = _QuestionDraft();
    draft.chapterIndex = index;
    setState(() => _questions.add(draft));
  }

  Future<void> _generateQuestionsWithAI() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = '请先填写书名');
      return;
    }
    if (_chapters.isEmpty) {
      setState(() => _error = '请先解析章节');
      return;
    }

    setState(() {
      _generatingAI = true;
      _error = null;
    });

    try {
      final text = _chapters
          .map((chapter) => '${chapter.titleController.text.trim()}\n\n${chapter.content}')
          .join('\n\n');
      final generated = await _apiService.generateQuizAI(text: '$title\n\n$text');

      for (final question in _questions) {
        question.dispose();
      }
      _questions.clear();

      for (final item in generated) {
        final draft = _QuestionDraft();
        draft.questionController.text = item['question']?.toString() ?? '';
        draft.correctOption = item['correct_option']?.toString() ?? 'A';
        draft.chapterIndex = (item['chapter_index'] as num?)?.toInt();
        final options = (item['options'] as List<dynamic>? ?? []);
        if (options.isNotEmpty) {
          draft.optionAController.text = options[0]['content']?.toString() ?? '';
        }
        if (options.length > 1) {
          draft.optionBController.text = options[1]['content']?.toString() ?? '';
        }
        if (options.length > 2) {
          draft.optionCController.text = options[2]['content']?.toString() ?? '';
        }
        _questions.add(draft);
      }
      setState(() {});
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _generatingAI = false);
    }
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) {
      setState(() => _error = '请填写书名');
      return;
    }
    if (_chapters.isEmpty) {
      setState(() => _error = '请先解析章节或导入文件');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final chapters = <Map<String, String>>[];
      for (var i = 0; i < _chapters.length; i++) {
        final title = _chapters[i].titleController.text.trim();
        chapters.add({
          'title': title.isEmpty ? '第 ${i + 1} 部分' : title,
          'content': _chapters[i].content,
        });
      }

      final questions = _questions
          .where((question) => question.questionController.text.trim().isNotEmpty)
          .map((question) => question.toJson())
          .toList();

      await _apiService.createBookFromChapters(
        title: _titleController.text.trim(),
        level: _level,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        category: _categoryController.text.trim().isEmpty
            ? null
            : _categoryController.text.trim(),
        chapters: chapters,
        questions: questions,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('添加图书')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<_Source>(
                segments: const [
                  ButtonSegment(
                    value: _Source.text,
                    label: Text('粘贴正文'),
                    icon: Icon(Icons.edit_note_rounded),
                  ),
                  ButtonSegment(
                    value: _Source.file,
                    label: Text('导入文件'),
                    icon: Icon(Icons.upload_file_rounded),
                  ),
                ],
                selected: {_source},
                onSelectionChanged: (selection) =>
                    setState(() => _source = selection.first),
              ),
              const SizedBox(height: 16),
              _buildInfoCard(),
              const SizedBox(height: 16),
              if (_source == _Source.text)
                _buildTextContentCard()
              else
                _buildFileContentCard(),
              const SizedBox(height: 22),
              ..._buildQuestionSection(),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(_saving ? '保存中…' : '保存图书'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return SurfaceCard(
      child: Column(
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: '书名'),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _level,
            decoration: const InputDecoration(labelText: '等级'),
            items: _levels
                .map((option) => DropdownMenuItem(value: option.$1, child: Text(option.$2)))
                .toList(),
            onChanged: (value) => setState(() => _level = value ?? 'LEVEL_2'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _categoryController,
            decoration: const InputDecoration(labelText: '分类，例如 animals'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(labelText: '简介'),
          ),
        ],
      ),
    );
  }

  Widget _buildTextContentCard() {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '正文',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
                ),
              ),
              FilledButton.icon(
                onPressed: _parsing ? null : _parseText,
                icon: const Icon(Icons.auto_stories_rounded),
                label: Text(_parsing ? '解析中…' : '解析章节'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '空行分隔不同的阅读页。解析章节后可逐章设置题目。',
            style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contentController,
            minLines: 8,
            maxLines: 18,
            decoration: const InputDecoration(hintText: '在这里输入正文……'),
          ),
          if (_parsing) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }

  Widget _buildFileContentCard() {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilledButton.icon(
            onPressed: _parsing ? null : _pickAndParseFile,
            icon: const Icon(Icons.upload_file_rounded),
            label: Text(_parsing ? '解析中…' : '选择文件'),
          ),
          if (_fileName != null) ...[
            const SizedBox(height: 10),
            Text(
              _fileName!,
              style: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
            ),
          ],
          const SizedBox(height: 6),
          const Text(
            '支持 PDF、TXT、Markdown。',
            style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
          ),
          if (_parsing) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildQuestionSection() {
    if (_chapters.isEmpty) {
      return const [
        SurfaceCard(
          child: Text('解析章节后，即可在这里按章节设置题目。'),
        ),
      ];
    }

    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            '阅读理解题',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
          ),
          FilledButton.icon(
            onPressed: _generatingAI ? null : _generateQuestionsWithAI,
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text('AI 生成全部'),
          ),
        ],
      ),
      if (_generatingAI) ...[
        const SizedBox(height: 12),
        const LinearProgressIndicator(),
      ],
      const SizedBox(height: 14),
      ..._chapters.asMap().entries.map(
            (entry) => _buildChapterGroup(entry.key, entry.value),
          ),
    ];
  }

  Widget _buildChapterGroup(int index, _ChapterDraft chapter) {
    final chapterQuestions = _questions
        .where((question) => question.chapterIndex == index)
        .toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: chapter.titleController,
                  decoration: const InputDecoration(labelText: '章节标题'),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${chapterQuestions.length} 题',
                style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
              ),
              const SizedBox(width: 6),
              TextButton.icon(
                onPressed: () => _addQuestionForChapter(index),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('添加题目'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (chapterQuestions.isEmpty)
            const Text(
              '暂无题目',
              style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
            )
          else
            ...chapterQuestions.map(
              (question) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildQuestionCard(question),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(_QuestionDraft question) {
    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: question.questionController,
            decoration: const InputDecoration(labelText: '题目'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: question.optionAController,
            decoration: const InputDecoration(labelText: '选项 A'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: question.optionBController,
            decoration: const InputDecoration(labelText: '选项 B'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: question.optionCController,
            decoration: const InputDecoration(labelText: '选项 C'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: question.correctOption,
            decoration: const InputDecoration(labelText: '正确答案'),
            items: const [
              DropdownMenuItem(value: 'A', child: Text('A')),
              DropdownMenuItem(value: 'B', child: Text('B')),
              DropdownMenuItem(value: 'C', child: Text('C')),
            ],
            onChanged: (value) => setState(() => question.correctOption = value ?? 'A'),
          ),
        ],
      ),
    );
  }
}