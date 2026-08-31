import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../services/offline_dictionary.dart';
import '../../theme/app_theme.dart';
import '../quiz/quiz_page.dart';
import '../quiz/quiz_result_page.dart';
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
  List<BookChapter> _chapters = const [];
  List<BookPageModel> _segments = const [];
  int _chapterIndex = 0;
  int _pageIndex = 0;
  double _fontScale = 1.0;
  int _activeCharIndex = -1;
  bool _loading = true;
  bool _finishing = false;
  List<QuizQuestion> _allQuestions = const [];
  int _quizCorrect = 0;
  int _quizTotal = 0;
  bool _hasChapterQuestions = false;
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
    unawaited(_reportProgress());
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
      final quiz = await _apiService.getQuiz(widget.bookId);
      _sessionStartedAt = DateTime.now();
      setState(() {
        _book = book;
        _session = session;
        _chapters = book.chapters;
        _allQuestions = quiz;
        _hasChapterQuestions = quiz.any((q) => q.chapterIndex != null);
      });
      if (book.chapters.isNotEmpty) {
        await _loadChapter(0);
      }
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadChapter(int index) async {
    final book = _book;
    final session = _session;
    if (book == null || session == null) return;
    if (index < 0 || index >= book.chapters.length) return;
    if (_speaking) await _tts.stop();

    final chapter = await _apiService.getChapter(book.id, index);
    if (!mounted) return;
    setState(() {
      _chapterIndex = index;
      _segments = chapter.segments;
      _pageIndex = 0;
      _speaking = false;
      _activeCharIndex = -1;
    });
    if (_segments.isNotEmpty) {
      await _apiService.recordEvent(
        sessionId: session.id,
        eventType: 'PAGE_VIEW',
        pageNo: _segments.first.pageNo,
      );
    }
    await _reportProgress();
  }

  Future<Word> _lookupWord(String text) async {
    final offline = OfflineDictionary.lookup(text);
    if (offline != null) return offline;
    return _apiService.getWord(text);
  }

  Future<void> _changePage(int index) async {
    if (_segments.isEmpty) return;
    if (index < 0 || index >= _segments.length) return;
    if (_speaking) await _tts.stop();
    setState(() {
      _pageIndex = index;
      _speaking = false;
      _activeCharIndex = -1;
    });
    final session = _session;
    if (session != null) {
      await _apiService.recordEvent(
        sessionId: session.id,
        eventType: 'PAGE_VIEW',
        pageNo: _segments[_pageIndex].pageNo,
      );
    }
    await _reportProgress();
  }

  Future<void> _goPrev() async {
    if (_pageIndex > 0) {
      await _changePage(_pageIndex - 1);
    } else if (_chapterIndex > 0) {
      await _loadChapter(_chapterIndex - 1);
    }
  }

  Future<void> _goNext() async {
    if (_pageIndex < _segments.length - 1) {
      await _changePage(_pageIndex + 1);
    } else {
      await _onChapterComplete();
    }
  }

  void _openChapterSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          children: _chapters.asMap().entries.map((entry) {
            final chapter = entry.value;
            final selected = entry.key == _chapterIndex;
            return ListTile(
              selected: selected,
              title: Text(chapter.title),
              subtitle: Text('${chapter.segmentCount} 页 · ${chapter.wordCount} 词'),
              trailing: selected ? const Icon(Icons.check_rounded) : null,
              onTap: () {
                Navigator.of(ctx).pop();
                _loadChapter(entry.key);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _openWord(String rawWord) async {
    if (_session == null || _segments.isEmpty) return;
    final word = rawWord.replaceAll(RegExp(r"[^a-zA-Z']"), '').toLowerCase();
    if (word.isEmpty) return;

    try {
      await _apiService.recordEvent(
        sessionId: _session!.id,
        eventType: 'WORD_CLICK',
        pageNo: _segments[_pageIndex].pageNo,
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
        contextText: _segments[_pageIndex].content,
        onSpeak: () => _apiService.recordEvent(
          sessionId: _session!.id,
          eventType: 'WORD_AUDIO',
          pageNo: _segments[_pageIndex].pageNo,
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
    if (_segments.isEmpty) return;
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
      await _tts.speak(_segments[_pageIndex].content);
    } catch (_) {
      if (!mounted) return;
      setState(() => _speaking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂时无法播放语音')),
      );
    }
  }

  Future<void> _reportProgress() async {
    final session = _session;
    final book = _book;
    if (session == null || book == null) return;
    final total = book.chapters.fold<int>(0, (sum, chapter) => sum + chapter.segmentCount);
    if (total == 0 || _segments.isEmpty) return;
    final durationSeconds = DateTime.now()
        .difference(_sessionStartedAt ?? DateTime.now())
        .inSeconds;
    final progress =
        (_segments[_pageIndex].pageNo / total).clamp(0.0, 1.0).toDouble();
    try {
      await _apiService.updateReadingProgress(
        sessionId: session.id,
        durationSeconds: durationSeconds,
        progress: progress,
      );
    } catch (_) {
      // Progress reporting is best-effort and should not interrupt reading.
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

  bool _chapterHasQuestions(int index) =>
      _allQuestions.any((q) => q.chapterIndex == index);

  Future<void> _onChapterComplete() async {
    final book = _book;
    if (book == null || _segments.isEmpty) return;
    final isLastChapter = _chapterIndex >= _chapters.length - 1;
    final chapterQuestions = _chapterHasQuestions(_chapterIndex)
        ? _allQuestions.where((q) => q.chapterIndex == _chapterIndex).toList()
        : const <QuizQuestion>[];

    if (_hasChapterQuestions && chapterQuestions.isNotEmpty) {
      final correct = await Navigator.of(context).push<int>(
        MaterialPageRoute(
          builder: (_) => QuizPage(
            bookId: widget.bookId,
            childId: widget.childId,
            chapterIndex: _chapterIndex,
            chapterTitle: book.chapters[_chapterIndex].title,
            questions: chapterQuestions,
            pages: _segments,
          ),
        ),
      );
      if (!mounted || correct == null) return;
      _quizCorrect += correct;
      _quizTotal += chapterQuestions.length;
      if (isLastChapter) {
        await _finishSession(_quizCorrect, _quizTotal);
      } else {
        await _loadChapter(_chapterIndex + 1);
      }
    } else if (isLastChapter) {
      await _finishAndQuiz();
    } else {
      await _loadChapter(_chapterIndex + 1);
    }
  }

  Future<void> _finishSession(int correct, int total) async {
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
          builder: (_) => QuizResultPage(
            total: total,
            correct: correct,
            bookId: widget.bookId,
            childId: widget.childId,
          ),
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
    final chapter = _chapters.isEmpty
        ? null
        : _chapters[_chapterIndex.clamp(0, _chapters.length - 1)];

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(book.title),
        actions: [
          IconButton(
            tooltip: '章节',
            onPressed: _chapters.isEmpty ? null : _openChapterSheet,
            icon: const Icon(Icons.menu_book_rounded),
          ),
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
      body: _segments.isEmpty
          ? const Center(child: Text('本书暂无内容'))
          : Column(
              children: [
                _chapterHeader(chapter),
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
                        child: _segmentContent(),
                      ),
                    ),
                  ),
                ),
                _pageControls(),
              ],
            ),
    );
  }

  Widget _chapterHeader(BookChapter? chapter) {
    final total = _chapters.length;
    return InkWell(
      onTap: total == 0 ? null : _openChapterSheet,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
        child: Row(
          children: [
            Expanded(
              child: Text(
                chapter?.title ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
            if (total > 0)
              Text(
                '第 ${_chapterIndex + 1} / $total 章',
                style: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
              ),
          ],
        ),
      ),
    );
  }

  Widget _segmentContent() {
    final content = _segments[_pageIndex].content;
    final tokens = _wordTokens(content);
    return Wrap(
      spacing: 8,
      runSpacing: 14,
      children: tokens.map((token) {
        final active = _activeCharIndex >= token.start && _activeCharIndex < token.end;
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
    );
  }

  Widget _pageControls() {
    final isFirstPage = _pageIndex == 0;
    final isLastSegment = _pageIndex == _segments.length - 1;
    final isLastChapter = _chapterIndex == _chapters.length - 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
      child: Column(
        children: [
          Align(
            alignment: Alignment.center,
            child: Text(
              '第 ${_pageIndex + 1} / ${_segments.length} 页',
              style: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
            ),
          ),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: isFirstPage && _chapterIndex == 0 ? null : _goPrev,
                icon: const Icon(Icons.chevron_left_rounded),
                label: Text(isFirstPage ? '上一章' : '上一页'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Slider(
                  value: _pageIndex.toDouble(),
                  min: 0,
                  max: (_segments.length - 1).toDouble(),
                  divisions: _segments.length > 1 ? _segments.length - 1 : null,
                  onChanged: (value) => _changePage(value.round()),
                ),
              ),
              const SizedBox(width: 10),
              if (isLastSegment && isLastChapter)
                FilledButton(
                  onPressed: _finishing ? null : _goNext,
                  child: const Text('完成并做题'),
                )
              else if (isLastSegment)
                FilledButton.icon(
                  onPressed: _goNext,
                  icon: const Icon(Icons.chevron_right_rounded),
                  label: Text(
                    _hasChapterQuestions && _chapterHasQuestions(_chapterIndex)
                        ? '完成本章'
                        : '下一章',
                  ),
                )
              else
                FilledButton.icon(
                  onPressed: _goNext,
                  icon: const Icon(Icons.chevron_right_rounded),
                  label: const Text('下一页'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}