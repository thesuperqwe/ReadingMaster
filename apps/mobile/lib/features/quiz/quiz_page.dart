import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/api_service.dart';
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
      final questions = await _apiService.getQuiz(widget.bookId);
      setState(() => _questions = questions);
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
    return Scaffold(
      appBar: AppBar(title: Text('阅读理解 ${_index + 1}/${_questions.length}')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(question.question, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),
            ...question.options.map(
              (option) => ListTile(
                leading: Icon(
                  _selected == option.key
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                ),
                title: Text(option.content),
                onTap: () => setState(() => _selected = option.key),
              ),
            ),
            const Spacer(),
            FilledButton(
              onPressed: _selected == null || _submitting ? null : _submitCurrent,
              child: Text(_index + 1 == _questions.length ? '提交结果' : '下一题'),
            ),
          ],
        ),
      ),
    );
  }
}
