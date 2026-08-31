import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class AddBookPage extends StatefulWidget {
  const AddBookPage({super.key});

  @override
  State<AddBookPage> createState() => _AddBookPageState();
}

class _QuestionDraft {
  final questionController = TextEditingController();
  final optionAController = TextEditingController();
  final optionBController = TextEditingController();
  final optionCController = TextEditingController();
  String correctOption = 'A';

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
  final List<_QuestionDraft> _questions = [];
  bool _saving = false;
  bool _generatingAI = false;
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
    for (final question in _questions) {
      question.dispose();
    }
    super.dispose();
  }

  void _addQuestion() {
    setState(() => _questions.add(_QuestionDraft()));
  }

  Future<void> _importEbook() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['txt', 'md'],
    );
    if (file == null) return;

    final bytes = await file.readAsBytes();
    final text = utf8.decode(bytes);

    setState(() {
      if (_titleController.text.trim().isEmpty) {
        final title = file.name.replaceAll(RegExp(r'\.(txt|md)$', caseSensitive: false), '');
        _titleController.text = title;
      }
      _contentController.text = text;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已导入：${file.name}')),
      );
    }
  }

  Future<void> _generateQuestionsWithAI() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty || content.isEmpty) {
      setState(() => _error = '请先填写书名和正文');
      return;
    }

    setState(() {
      _generatingAI = true;
      _error = null;
    });

    try {
      final generated = await _apiService.generateQuizAI(
        text: '$title\n\n$content',
      );

      for (final question in _questions) {
        question.dispose();
      }
      _questions.clear();

      for (final item in generated) {
        final draft = _QuestionDraft();
        draft.questionController.text = item['question']?.toString() ?? '';
        draft.correctOption = item['correct_option']?.toString() ?? 'A';
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
    if (_titleController.text.trim().isEmpty || _contentController.text.trim().isEmpty) {
      setState(() => _error = '标题和正文不能为空');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final questions = _questions
          .where((question) => question.questionController.text.trim().isNotEmpty)
          .map((question) => question.toJson())
          .toList();

      await _apiService.createBook(
        title: _titleController.text.trim(),
        level: _level,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        category: _categoryController.text.trim().isEmpty
            ? null
            : _categoryController.text.trim(),
        content: _contentController.text.trim(),
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
              SurfaceCard(
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
              ),
              const SizedBox(height: 16),
              SurfaceCard(
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
                        OutlinedButton.icon(
                          onPressed: _importEbook,
                          icon: const Icon(Icons.upload_file_rounded),
                          label: const Text('导入电子书'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '空行分隔不同的阅读页。',
                      style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _contentController,
                      minLines: 8,
                      maxLines: 18,
                      decoration: const InputDecoration(hintText: '在这里输入正文……'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    '阅读理解题',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
                  ),
                  Wrap(
                    spacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _addQuestion,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('手动添加'),
                      ),
                      FilledButton.icon(
                        onPressed: _generatingAI ? null : _generateQuestionsWithAI,
                        icon: const Icon(Icons.auto_awesome_rounded),
                        label: const Text('AI 生成'),
                      ),
                    ],
                  ),
                ],
              ),
              if (_generatingAI) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              ..._questions.map(_buildQuestionCard),
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