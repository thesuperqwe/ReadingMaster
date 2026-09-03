import 'dart:convert';

import '../../services/web_file_picker.dart';
import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

enum _Source { text, file, photo }

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
  int _photoCount = 0;
  String? _error;
  String _parsedPreview = '';

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
      _parsedPreview = _buildParsedPreview(chapters);
    });
  }

  String _buildParsedPreview(List<ParsedChapter> chapters) {
    final buffer = StringBuffer();
    for (var i = 0; i < chapters.length; i++) {
      buffer.writeln('${i + 1}. ${chapters[i].title}');
      buffer.writeln(chapters[i].content);
      if (i != chapters.length - 1) buffer.writeln();
    }
    return buffer.toString().trim();
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
    final files = await pickWebFiles(multiple: false);
    if (files.isEmpty) return;

    setState(() {
      _parsing = true;
      _error = null;
    });

    try {
      final file = files.first;
      final parsed = await _apiService.parseEbook(
        filename: file.name,
        bytes: file.bytes,
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

  Future<void> _pickAndParsePhotos() async {
    final files = await pickWebFiles(accept: 'image/*', multiple: true);
    if (files.isEmpty) return;

    setState(() {
      _parsing = true;
      _error = null;
    });

    try {
      final images = <Map<String, String>>[];
      for (final file in files) {
        images.add({
          'data': base64Encode(file.bytes),
          'mime_type': _mimeTypeForName(file.name),
        });
      }
      if (images.isEmpty) {
        throw Exception('没有读取到图片数据');
      }

      final parsed = await _apiService.parseOcr(images);

      if (!mounted) return;
      setState(() {
        _photoCount = files.length;
        if (_titleController.text.trim().isEmpty && files.isNotEmpty) {
          _titleController.text = '拍照导入图书';
        }
      });
      _applyParsed(parsed.chapters);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _parsing = false);
    }
  }

  String _mimeTypeForName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.heif')) return 'image/heif';
    return 'image/jpeg';
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
    final editor = SingleChildScrollView(
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
                ButtonSegment(
                  value: _Source.photo,
                  label: Text('拍照导入'),
                  icon: Icon(Icons.photo_camera_rounded),
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
            else if (_source == _Source.file)
              _buildFileContentCard()
            else
              _buildPhotoContentCard(),
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
    );

    return Scaffold(
      appBar: AppBar(title: const Text('添加图书')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final sideBySide = constraints.maxWidth >= 980 && _parsedPreview.isNotEmpty;
          if (sideBySide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: editor),
                SizedBox(
                  width: 420,
                  height: double.infinity,
                  child: _parsedPreviewPanel(),
                ),
              ],
            );
          }

          return Column(
            children: [
              Expanded(child: editor),
              if (_parsedPreview.isNotEmpty)
                SizedBox(height: 360, child: _parsedPreviewPanel()),
            ],
          );
        },
      ),
    );
  }

  Widget _parsedPreviewPanel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 24, 24, 24),
      child: Container(
        height: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '解析文本预览',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
            ),
            const Divider(height: 20, color: AppColors.line),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  _parsedPreview,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.55,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ),
          ],
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
            '支持 PDF、EPUB、TXT、Markdown、HTML、DOCX、FB2。',
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

  Widget _buildPhotoContentCard() {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilledButton.icon(
            onPressed: _parsing ? null : _pickAndParsePhotos,
            icon: const Icon(Icons.photo_camera_rounded),
            label: Text(_parsing ? '识别中…' : '拍照 / 选择照片'),
          ),
          if (_photoCount > 0) ...[
            const SizedBox(height: 10),
            Text(
              '已选择 $_photoCount 张图片',
              style: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
            ),
          ],
          const SizedBox(height: 6),
          const Text(
            '拍下实体书的正文页面，系统会自动识别文字并拆分成章节。可一次选择多张照片。',
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