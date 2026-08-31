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

class _WordToken {
  const _WordToken({required this.start, required this.end, required this.text});

  final int start;
  final int end;
  final String text;
}

class _ReaderPageState extends State<ReaderPage> {
  final _apiService = ApiService();
  final _tts = FlutterTts();
  BookDetail? _book;
  ReadingSession? _session;
  int _pageIndex = 0;
  double _fontScale = 1.0;
  int _activeCharIndex = -1;
  bool _loading = true;
  bool _finishing = false;
  bool _speaking = false;
  DateTime? _sessionStartedAt;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initTts();
    _load();
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    _tts.setProgressHandler((text, start, end, word) {
      if (mounted) setState(() => _activeCharIndex = start);
    });
    _tts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _speaking = false;
          _activeCharIndex = -1;
        });
      }
    });
    _tts.setCancelHandler(() {
      if (mounted) {
        setState(() {
          _speaking = false;
          _activeCharIndex = -1;
        });
      }
    });
    _tts.setErrorHandler((_) {
      if (mounted) {
        setState(() {
          _speaking = false;
          _activeCharIndex = -1;
        });
      }
    });
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
      _sessionStartedAt = DateTime.now();
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
    if (_speaking) await _tts.stop();
    setState(() {
      _pageIndex = index;
      _speaking = false;
      _activeCharIndex = -1;
    });
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

  Future<void> _toggleReadAlong() async {
    if (_book == null) return;
    if (_speaking) {
      await _tts.stop();
      if (mounted) {
        setState(() {
          _speaking = false;
          _activeCharIndex = -1;
        });
      }
      return;
    }

    await _tts.stop();
    if (!mounted) return;
    setState(() {
      _speaking = true;
      _activeCharIndex = -1;
    });
    try {
      await _tts.speak(_book!.pages[_pageIndex].content);
    } catch (_) {
      if (!mounted) return;
      setState(() => _speaking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂时无法播放语音')),
      );
    }
  }

  Future<void> _finishAndQuiz() async {
    if (_session == null || _book == null) return;
    setState(() => _finishing = true);
    try {
      final durationSeconds = DateTime.now()
          .difference(_sessionStartedAt ?? DateTime.now())
          .inSeconds;
      await _apiService.finishSession(
        sessionId: _session!.id,
        durationSeconds: durationSeconds,
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

  List<_WordToken> _wordTokens(String text) {
    return RegExp(r'\S+')
        .allMatches(text)
        .map((match) => _WordToken(
              start: match.start,
              end: match.end,
              text: match.group(0)!,
            ))
        .toList();
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
    final tokens = _wordTokens(page.content);

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
            tooltip: _speaking ? '停止朗读' : '朗读本页',
            onPressed: _toggleReadAlong,
            icon: Icon(_speaking ? Icons.stop_rounded : Icons.volume_up_rounded),
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
                    children: tokens.map((token) {
                      final active = _activeCharIndex >= token.start &&
                          _activeCharIndex < token.end;
                      return GestureDetector(
                        onTap: () => _openWord(token.text),
                        child: Text(
                          token.text,
                          style: TextStyle(
                            fontSize: 28 * _fontScale,
                            height: 1.4,
                            color: active ? AppColors.primaryDark : AppColors.ink,
                            fontWeight: active ? FontWeight.w800 : FontWeight.w400,
                            backgroundColor: active ? AppColors.primarySoft : null,
                          ),
                        ),
                      );
                    }).toList(),
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