import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../services/offline_dictionary.dart';
import '../../theme/app_theme.dart';
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
  final _tts = FlutterTts();
  BookDetail? _book;
  ReadingSession? _session;
  int _pageIndex = 0;
  double _fontScale = 1.0;
  bool _loading = true;
  bool _finishing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initTts();
    _load();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
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

  Future<Word> _lookupWord(String text) async {
    final offline = OfflineDictionary.lookup(text);
    if (offline != null) return offline;
    return _apiService.getWord(text);
  }

  Future<void> _changePage(int index) async {
    if (_book == null || _session == null) return;
    if (index < 0 || index >= _book!.pages.length) return;
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
      final detail = await _lookupWord(word);
      if (!mounted) return;
      await showWordPopup(
        context,
        detail,
        lookup: _lookupWord,
        aiLookup: (word, {context}) =>
            _apiService.explainWordAI(word, context: context),
        contextText: _book!.pages[_pageIndex].content,
        onSpeak: () => _apiService.recordEvent(
          sessionId: _session!.id,
          eventType: 'WORD_AUDIO',
          pageNo: _pageIndex + 1,
          word: detail.word,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂时无法查询这个单词')),
      );
    }
  }

  Future<void> _speakPage() async {
    if (_book == null) return;
    try {
      await _tts.stop();
      await _tts.speak(_book!.pages[_pageIndex].content);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂时无法播放语音')),
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
      appBar: AppBar(
        centerTitle: true,
        title: Text(book.title),
        actions: [
          IconButton(
            tooltip: '缩小字体',
            onPressed: () => setState(
              () => _fontScale = (_fontScale - 0.1).clamp(0.85, 1.5),
            ),
            icon: const Icon(Icons.text_decrease_rounded),
          ),
          IconButton(
            tooltip: '放大字体',
            onPressed: () => setState(
              () => _fontScale = (_fontScale + 0.1).clamp(0.85, 1.5),
            ),
            icon: const Icon(Icons.text_increase_rounded),
          ),
          IconButton(
            tooltip: '朗读本页',
            onPressed: _speakPage,
            icon: const Icon(Icons.volume_up_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(24, 12, 24, 8),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.line),
              ),
              child: SingleChildScrollView(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 14,
                    children: page.content
                        .split(RegExp(r'\s+'))
                        .where((word) => word.isNotEmpty)
                        .map(
                          (word) => GestureDetector(
                            onTap: () => _openWord(word),
                            child: Text(
                              word,
                              style: TextStyle(
                                fontSize: 28 * _fontScale,
                                height: 1.4,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Text(
                    '${_pageIndex + 1} / ${book.pages.length}',
                    style: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
                  ),
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed:
                          _pageIndex == 0 ? null : () => _changePage(_pageIndex - 1),
                      icon: const Icon(Icons.chevron_left_rounded),
                      label: const Text('上一页'),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Slider(
                        value: _pageIndex.toDouble(),
                        min: 0,
                        max: (book.pages.length - 1).toDouble(),
                        divisions: book.pages.length > 1 ? book.pages.length - 1 : null,
                        onChanged: (value) => _changePage(value.round()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (isLast)
                      FilledButton(
                        onPressed: _finishing ? null : _finishAndQuiz,
                        child: const Text('完成并做题'),
                      )
                    else
                      FilledButton.icon(
                        onPressed: () => _changePage(_pageIndex + 1),
                        icon: const Icon(Icons.chevron_right_rounded),
                        label: const Text('下一页'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
