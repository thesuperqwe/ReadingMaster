import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class EditBookQuestionsPage extends StatefulWidget {
  const EditBookQuestionsPage({super.key, required this.bookId});

  final String bookId;

  @override
  State<EditBookQuestionsPage> createState() => _EditBookQuestionsPageState();
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
        if (optionCController.text.trim().isNotEmpty)
          {'option_key': 'C', 'content': optionCController.text.trim()},
      ],
    };
  }
}

class _EditBookQuestionsPageState extends State<EditBookQuestionsPage> {
  final _apiService = ApiService();

  BookDetail? _book;
  List<QuizQuestion> _questions = [];
  List<_QuestionDraft> _drafts = [];
  bool _loading = true;
  bool _saving = false;
  bool _generatingAI = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final draft in _drafts) {
      draft.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final book = await _apiService.getBook(widget.bookId);
      final questions = await _apiService.getQuiz(widget.bookId);
      if (!mounted) return;
      setState(() {
        _book = book;
        _questions = questions;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _addEmptyDraft() {
    setState(() => _drafts.add(_QuestionDraft()));
  }

  _QuestionDraft _draftFromGenerated(Map<String, dynamic> item) {
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
    return draft;
  }

  Future<void> _generateQuestionsWithAI() async {
    setState(() {
      _generatingAI = true;
      _error = null;
    });

    try {
      final generated = await _apiService.generateQuizAI(bookId: widget.bookId);
      if (generated.isEmpty) {
        if (mounted) setState(() => _error = 'AI 没有生成题目，请稍后再试');
        return;
      }

      for (final draft in _drafts) {
        draft.dispose();
      }
      final newDrafts = generated.map(_draftFromGenerated).toList();
      if (!mounted) return;
      setState(() => _drafts = newDrafts);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已生成 ${newDrafts.length} 道草稿，请检查后保存')),
      );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _generatingAI = false);
    }
  }

  Future<void> _saveDrafts() async {
    if (_drafts.isEmpty) {
      setState(() => _error = '请先添加或生成题目');
      return;
    }

    final payloads = <Map<String, dynamic>>[];
    for (var i = 0; i < _drafts.length; i++) {
      final draft = _drafts[i];
      if (draft.questionController.text.trim().isEmpty ||
          draft.optionAController.text.trim().isEmpty ||
          draft.optionBController.text.trim().isEmpty) {
        setState(() => _error = '请完善第 ${i + 1} 题，题目和 A、B 选项不能为空');
        return;
      }
      final json = draft.toJson();
      final options = (json['options'] as List<dynamic>)
          .map((item) => item as Map<String, dynamic>)
          .toList();
      final hasCorrect = options.any(
        (option) => option['option_key'] == json['correct_option'],
      );
      if (!hasCorrect) {
        setState(() => _error = '第 ${i + 1} 题的正确答案对应选项不能为空');
        return;
      }
      payloads.add(json);
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      for (final payload in payloads) {
        await _apiService.addQuestion(widget.bookId, payload);
      }

      for (final draft in _drafts) {
        draft.dispose();
      }
      if (!mounted) return;
      setState(() => _drafts = []);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已保存 ${payloads.length} 道题')),
      );
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('添加题目')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _book == null
              ? Center(child: Text('加载失败：$_error'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SectionTitle(
                          _book?.title ?? '本书',
                          subtitle: '为已有图书补充阅读理解题',
                        ),
                        const SizedBox(height: 18),
                        _existingQuestions(),
                        const SizedBox(height: 18),
                        _draftSection(),
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _existingQuestions() {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            '已有题目',
            subtitle: _questions.isEmpty ? '暂无题目' : '${_questions.length} 题',
          ),
          if (_questions.isNotEmpty) ...[
            const SizedBox(height: 12),
            ..._questions.map(_questionCard),
          ],
        ],
      ),
    );
  }

  Widget _questionCard(QuizQuestion question) {
    final chapterText = question.chapterTitle ?? '全书';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SurfaceCard(
        color: AppColors.panel,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question.question,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink),
            ),
            const SizedBox(height: 6),
            Text(
              '章节：$chapterText',
              style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 6),
            ...question.options.map(
              (option) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${option.key}. ${option.content}',
                  style: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _draftSection() {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(
            '待保存题目',
            subtitle: _drafts.isEmpty ? '暂无草稿' : '${_drafts.length} 道草稿',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.icon(
                  onPressed: _generatingAI ? null : _generateQuestionsWithAI,
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: Text(_generatingAI ? '生成中…' : 'AI 生成题目'),
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: '手动添加题目',
                  onPressed: _addEmptyDraft,
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
          ),
          if (_generatingAI) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          if (_drafts.isNotEmpty) ...[
            const SizedBox(height: 12),
            ..._drafts.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _draftCard(entry.key, entry.value),
                  ),
                ),
          ],
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _saving ? null : _saveDrafts,
            child: Text(_saving ? '保存中…' : '保存题目'),
          ),
        ],
      ),
    );
  }

  Widget _draftCard(int index, _QuestionDraft draft) {
    final book = _book;
    return SurfaceCard(
      color: AppColors.panel,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '第 ${index + 1} 题',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
          ),
          const SizedBox(height: 12),
          if (book != null)
            DropdownButtonFormField<int?>(
              initialValue: draft.chapterIndex,
              decoration: const InputDecoration(labelText: '关联章节'),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('不关联章节'),
                ),
                ...book.chapters.map(
                  (chapter) => DropdownMenuItem<int?>(
                    value: chapter.index,
                    child: Text(chapter.title),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => draft.chapterIndex = value),
            ),
          if (book != null) const SizedBox(height: 12),
          TextField(
            controller: draft.questionController,
            decoration: const InputDecoration(labelText: '题目'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: draft.optionAController,
            decoration: const InputDecoration(labelText: '选项 A'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: draft.optionBController,
            decoration: const InputDecoration(labelText: '选项 B'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: draft.optionCController,
            decoration: const InputDecoration(labelText: '选项 C（可选）'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: draft.correctOption,
            decoration: const InputDecoration(labelText: '正确答案'),
            items: const [
              DropdownMenuItem(value: 'A', child: Text('A')),
              DropdownMenuItem(value: 'B', child: Text('B')),
              DropdownMenuItem(value: 'C', child: Text('C')),
            ],
            onChanged: (value) => setState(() => draft.correctOption = value ?? 'A'),
          ),
        ],
      ),
    );
  }
}