import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../services/speech_recognition.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'quiz_result_page.dart';

class QuizPage extends StatefulWidget {
  const QuizPage({
    super.key,
    required this.bookId,
    required this.childId,
    this.chapterIndex,
    this.chapterTitle,
    this.questions,
    this.pages,
  });

  final String bookId;
  final String childId;
  final int? chapterIndex;
  final String? chapterTitle;
  final List<QuizQuestion>? questions;
  final List<BookPageModel>? pages;

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final _apiService = ApiService();
  final _speech = createSpeechRecognition();
  final _voiceAnswerController = TextEditingController();

  BookDetail? _book;
  List<BookPageModel> _pages = [];
  List<QuizQuestion> _questions = [];
  int _index = 0;
  String? _selected;
  bool _loading = true;
  bool _submitting = false;
  bool _voiceMode = false;
  bool _speechSupported = false;
  bool _voiceSubmitting = false;
  bool _recording = false;
  String _voiceTranscript = '';
  VoiceQuizResult? _voiceResult;
  QuizAttempt? _attemptResult;
  int _correctCount = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _speechSupported = _speech.isSupported;
    _voiceMode = false;
    _load();
  }

  @override
  void dispose() {
    _voiceAnswerController.dispose();
    super.dispose();
  }

  void _switchMode(bool voiceMode) {
    if (voiceMode && !_speechSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前浏览器不支持语音识别，请使用选项答题。')),
      );
      return;
    }
    setState(() {
      _voiceMode = voiceMode;
      _selected = null;
      _voiceTranscript = '';
      _voiceResult = null;
      _attemptResult = null;
      _voiceAnswerController.clear();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bookFuture = _apiService.getBook(widget.bookId);
      final pagesFuture = widget.pages != null
          ? Future.value(widget.pages!)
          : _apiService.getBookContent(widget.bookId);
      final quizFuture = widget.questions != null
          ? Future.value(widget.questions!)
          : _apiService.getQuiz(widget.bookId);
      final book = await bookFuture;
      final pages = await pagesFuture;
      final allQuestions = await quizFuture;
      final questions = widget.chapterIndex != null
          ? allQuestions
              .where((q) => q.chapterIndex == widget.chapterIndex)
              .toList()
          : allQuestions;
      setState(() {
        _book = book;
        _pages = pages;
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
      if (mounted) setState(() => _attemptResult = result);
      if (!mounted) return;
      if (result.isCorrect != true && result.correctOption != null) {
        final correctText = _optionContent(question, result.correctOption!);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('正确答案：${result.correctOption}. $correctText')),
        );
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

  Future<void> _submitVoiceCurrent() async {
    final question = _questions[_index];
    final answer = _voiceTranscript.trim();
    if (answer.isEmpty) return;

    setState(() => _voiceSubmitting = true);
    try {
      final result = await _apiService.submitVoiceQuiz(
        childId: widget.childId,
        questionId: question.id,
        studentAnswer: answer,
      );
      if (result.isCorrect) _correctCount += 1;
      if (mounted) setState(() => _voiceResult = result);
      if (!mounted) return;
      if (!result.isCorrect && result.correctOption != null) {
        final correctText = _optionContent(question, result.correctOption!);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('正确答案：${result.correctOption}. $correctText')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('语音答题提交失败：$error')),
        );
      }
    } finally {
      if (mounted) setState(() => _voiceSubmitting = false);
    }
  }

  Future<void> _advance() async {
    if (_index + 1 >= _questions.length) {
      if (!mounted) return;
      if (widget.chapterIndex != null) {
        Navigator.of(context).pop(_correctCount);
      } else {
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
      }
    } else {
      setState(() {
        _index += 1;
        _selected = null;
        _voiceTranscript = '';
        _voiceResult = null;
        _attemptResult = null;
        _voiceAnswerController.clear();
      });
    }
  }

  Future<void> _startVoice() async {
    if (_recording || _voiceSubmitting) return;
    setState(() {
      _recording = true;
      _voiceTranscript = '';
      _voiceResult = null;
    });
    try {
      final transcript = await _speech.listen();
      if (mounted) {
        setState(() => _voiceTranscript = transcript.trim());
        _voiceAnswerController.text = transcript.trim();
      }
    } catch (error) {
      if (mounted) {
        final message = error is StateError ? error.message : error.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('语音识别失败：$message')),
        );
      }
    } finally {
      if (mounted) setState(() => _recording = false);
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
        title: Text(widget.chapterTitle ?? '阅读理解'),
        actions: [
          if (_speech.isSupported)
            IconButton(
              tooltip: _voiceMode ? '切换到选择答题' : '切换到语音答题',
              onPressed: () => setState(() => _voiceMode = !_voiceMode),
              icon: Icon(_voiceMode ? Icons.check_circle_rounded : Icons.mic_rounded),
            ),
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
            ..._pages.map(
              (page) => Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_pages.length > 1) ...[
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
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
              value: false,
              label: Text('选项答题'),
              icon: Icon(Icons.radio_button_checked_rounded),
            ),
            ButtonSegment(
              value: true,
              label: Text('语音问答'),
              icon: Icon(Icons.mic_rounded),
            ),
          ],
          selected: {_voiceMode},
          onSelectionChanged: (selection) => _switchMode(selection.first),
        ),
        const SizedBox(height: 16),
        _quizHeader(question, total),
        const SizedBox(height: 20),
        Expanded(
          child: _voiceMode
              ? _voiceAnswerArea(question)
              : _optionAnswerArea(question),
        ),
        if (!_voiceMode && _attemptResult != null) ...[
          const SizedBox(height: 12),
          _choiceFeedback(question, _attemptResult!),
        ],
        const SizedBox(height: 12),
        if (_voiceMode)
          FilledButton(
            onPressed: _voiceSubmitting || _voiceTranscript.trim().isEmpty
                ? null
                : (_voiceResult != null ? _advance : _submitVoiceCurrent),
            child: Text(
              _voiceResult != null
                  ? (_index + 1 == total ? '提交结果' : '下一题')
                  : '提交答案',
            ),
          )
        else
          FilledButton(
            onPressed: _selected == null || _submitting
                ? null
                : (_attemptResult != null ? _advance : _submitCurrent),
            child: Text(
              _attemptResult != null
                  ? (_index + 1 == total ? '提交结果' : '下一题')
                  : '提交答案',
            ),
          ),
      ],
    );
  }

  Widget _quizHeader(QuizQuestion question, int total) {
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (question.chapterTitle?.isNotEmpty == true) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    question.chapterTitle!,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryDark),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Text(
                question.question,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _optionAnswerArea(QuizQuestion question) {
    return SingleChildScrollView(
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
    );
  }

  Widget _voiceAnswerArea(QuizQuestion question) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_speechSupported)
            Center(
              child: Column(
                children: [
                  Material(
                    color: _recording ? AppColors.gold : AppColors.primary,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        if (_recording) {
                          _speech.stop();
                        } else {
                          _startVoice();
                        }
                      },
                      child: SizedBox(
                        width: 96,
                        height: 96,
                        child: Icon(
                          _recording ? Icons.graphic_eq_rounded : Icons.mic_rounded,
                          color: Colors.white,
                          size: 42,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _recording ? '正在听，点击结束' : '点击麦克风，说出你的答案',
                    style: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.panel,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                '当前浏览器不支持语音识别，请直接在下方输入答案。',
                style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
              ),
            ),
          const SizedBox(height: 18),
          TextField(
            controller: _voiceAnswerController,
            minLines: 2,
            maxLines: 4,
            onChanged: (value) => setState(() => _voiceTranscript = value),
            decoration: const InputDecoration(
              labelText: '也可以在这里输入答案',
              hintText: '例如：Tom has a little dog.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          if (_voiceResult != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _voiceResult!.isCorrect
                    ? AppColors.primarySoft
                    : AppColors.gold.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _voiceResult!.isCorrect ? '✅ 答对了！' : '❌ 答错了',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _voiceResult!.isCorrect
                          ? AppColors.primaryDark
                          : AppColors.danger,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _voiceTranscript,
                    style: const TextStyle(fontSize: 15, color: AppColors.ink),
                  ),
                  if (_voiceResult!.correctOption != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      '标准答案：${_voiceResult!.correctOption}. ${_optionContent(question, _voiceResult!.correctOption!)}',
                      style: const TextStyle(fontSize: 15, color: AppColors.primaryDark),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _optionContent(QuizQuestion question, String key) {
    for (final option in question.options) {
      if (option.key == key) return option.content;
    }
    return key;
  }

  Widget _choiceFeedback(QuizQuestion question, QuizAttempt result) {
    final correct = result.isCorrect == true;
    final correctOption = result.correctOption;
    final correctText = correctOption == null
        ? '暂无标准答案'
        : '$correctOption. ${_optionContent(question, correctOption)}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: correct
            ? AppColors.primarySoft
            : AppColors.gold.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            correct ? '✅ 答对了！' : '❌ 答错了',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: correct ? AppColors.primaryDark : AppColors.danger,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '正确答案：$correctText',
            style: const TextStyle(fontSize: 15, color: AppColors.ink),
          ),
        ],
      ),
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