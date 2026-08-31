import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'quiz_result_page.dart';

class QuizPage extends StatefulWidget {
  const QuizPage({super.key, required this.bookId, required this.childId});

  final String bookId;
  final String childId;

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final _apiService = ApiService();
  BookDetail? _book;
  List<QuizQuestion> _questions = [];
  int _index = 0;
  String? _selected;
  bool _loading = true;
  bool _submitting = false;
  int _correctCount = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bookFuture = _apiService.getBook(widget.bookId);
      final quizFuture = _apiService.getQuiz(widget.bookId);
      final book = await bookFuture;
      final questions = await quizFuture;
      setState(() {
        _book = book;
        _questions = questions;
      });
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitCurrent() async {
    final question = _questions[_index];
    if (_selected == null) return;

    setState(() => _submitting = true);
    try {
      final result = await _apiService.submitQuiz(
        childId: widget.childId,
        questionId: question.id,
        selectedOption: _selected!,
      );
      if (result.isCorrect == true) _correctCount += 1;

      if (_index + 1 >= _questions.length) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => QuizResultPage(
              total: _questions.length,
              correct: _correctCount,
              bookId: widget.bookId,
              childId: widget.childId,
            ),
          ),
        );
      } else {
        setState(() {
          _index += 1;
          _selected = null;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showOriginalSheet() {
    if (_book == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.72,
          child: _originalTextCard(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('阅读理解')),
        body: Center(child: Text(_error!)),
      );
    }
    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('阅读理解')),
        body: const Center(child: Text('这本书还没有题目')),
      );
    }

    final question = _questions[_index];
    final total = _questions.length;
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('阅读理解'),
        actions: [
          if (!wide)
            IconButton(
              tooltip: '查看原文',
              onPressed: _showOriginalSheet,
              icon: const Icon(Icons.menu_book_rounded),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 5, child: _originalTextCard()),
                    const SizedBox(width: 20),
                    Expanded(flex: 5, child: _quizPanel(question, total)),
                  ],
                )
              : _quizPanel(question, total),
        ),
      ),
    );
  }

  Widget _originalTextCard() {
    final book = _book;
    if (book == null) {
      return const SurfaceCard(child: Center(child: Text('原文加载中…')));
    }

    return SurfaceCard(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.menu_book_rounded, color: AppColors.primaryDark),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    book.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...book.pages.map(
              (page) => Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (book.pages.length > 1) ...[
                      Text(
                        '第 ${page.pageNo} 页',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkSoft,
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      page.content,
                      style: const TextStyle(
                        fontSize: 17,
                        height: 1.6,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quizPanel(QuizQuestion question, int total) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              '第 ${_index + 1} 题 / 共 $total 题',
              style: const TextStyle(fontSize: 14, color: AppColors.inkSoft),
            ),
            const Spacer(),
            Text(
              '${_index + 1}/$total',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: (_index + 1) / total,
            minHeight: 8,
            backgroundColor: AppColors.line,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 26),
        SurfaceCard(
          color: AppColors.panel,
          child: Text(
            question.question,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink, height: 1.4),
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: question.options
                  .map(
                    (option) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _optionTile(option),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _selected == null || _submitting ? null : _submitCurrent,
          child: Text(_index + 1 == total ? '提交结果' : '下一题'),
        ),
      ],
    );
  }

  Widget _optionTile(QuizOption option) {
    final selected = _selected == option.key;
    return Material(
      color: selected ? AppColors.primarySoft : AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => setState(() => _selected = option.key),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? AppColors.primary : AppColors.line),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : AppColors.panel,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    option.key,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : AppColors.primaryDark,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  option.content,
                  style: const TextStyle(fontSize: 16, color: AppColors.ink),
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle_rounded, color: AppColors.primaryDark),
            ],
          ),
        ),
      ),
    );
  }
}