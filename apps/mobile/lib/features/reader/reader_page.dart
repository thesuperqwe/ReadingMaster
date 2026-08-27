import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/api_service.dart';
import '../quiz/quiz_page.dart';
import 'word_popup.dart';

class ReaderPage extends StatefulWidget {
  const ReaderPage({super.key, required this.bookId, required this.childId});

  final String bookId;
  final String childId;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  final _apiService = ApiService();
  BookDetail? _book;
  ReadingSession? _session;
  int _pageIndex = 0;
  bool _loading = true;
  bool _finishing = false;
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
      final book = await _apiService.getBook(widget.bookId);
      final session = await _apiService.startSession(
        childId: widget.childId,
        bookId: widget.bookId,
      );
      await _apiService.recordEvent(
        sessionId: session.id,
        eventType: 'PAGE_VIEW',
        pageNo: 1,
      );
      setState(() {
        _book = book;
        _session = session;
      });
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changePage(int index) async {
    if (_book == null || _session == null) return;
    setState(() => _pageIndex = index);
    await _apiService.recordEvent(
      sessionId: _session!.id,
      eventType: 'PAGE_VIEW',
      pageNo: index + 1,
    );
  }

  Future<void> _openWord(String rawWord) async {
    if (_session == null) return;
    final word = rawWord.replaceAll(RegExp(r"[^a-zA-Z']"), '').toLowerCase();
    if (word.isEmpty) return;

    try {
      await _apiService.recordEvent(
        sessionId: _session!.id,
        eventType: 'WORD_CLICK',
        pageNo: _pageIndex + 1,
        word: word,
      );
      final detail = await _apiService.getWord(word);
      if (!mounted) return;
      await showWordPopup(context, detail, lookup: _apiService.getWord);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂时无法查询这个单词')),
      );
    }
  }

  Future<void> _finishAndQuiz() async {
    if (_session == null || _book == null) return;
    setState(() => _finishing = true);

    try {
      await _apiService.finishSession(
        sessionId: _session!.id,
        durationSeconds: 0,
        progress: 1,
        completed: true,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => QuizPage(bookId: widget.bookId, childId: widget.childId),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _finishing = false;
          _error = error.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('阅读器')),
        body: Center(child: Text(_error!)),
      );
    }

    final book = _book!;
    final page = book.pages[_pageIndex];
    final isLast = _pageIndex == book.pages.length - 1;

    return Scaffold(
      appBar: AppBar(title: Text(book.title)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 12,
                  children: page.content
                      .split(RegExp(r'\s+'))
                      .where((word) => word.isNotEmpty)
                      .map(
                        (word) => GestureDetector(
                          onTap: () => _openWord(word),
                          child: Text(
                            word,
                            style: const TextStyle(fontSize: 28, height: 1.35),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${_pageIndex + 1} / ${book.pages.length}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton(
                  onPressed: _pageIndex == 0 ? null : () => _changePage(_pageIndex - 1),
                  child: const Text('上一页'),
                ),
                if (isLast)
                  FilledButton(
                    onPressed: _finishing ? null : _finishAndQuiz,
                    child: const Text('完成并做题'),
                  )
                else
                  FilledButton(
                    onPressed: () => _changePage(_pageIndex + 1),
                    child: const Text('下一页'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
