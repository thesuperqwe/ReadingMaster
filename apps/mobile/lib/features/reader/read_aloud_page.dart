import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../services/speech_recognition.dart';
import '../../services/tts_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class ReadAloudPage extends StatefulWidget {
  const ReadAloudPage({
    super.key,
    required this.childId,
    required this.sentences,
    this.bookTitle,
  });

  final String childId;
  final List<String> sentences;
  final String? bookTitle;

  @override
  State<ReadAloudPage> createState() => _ReadAloudPageState();
}

class _ReadAloudPageState extends State<ReadAloudPage> {
  final _apiService = ApiService();
  final _tts = createTtsService();
  final _speech = createSpeechRecognition();
  final _answerController = TextEditingController();

  int _index = 0;
  bool _recording = false;
  bool _submitting = false;
  bool _speaking = false;
  String _transcript = '';
  ReadAloudResult? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  @override
  void dispose() {
    _tts.dispose();
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _initTts() async {
    await _tts.initialize();
  }

  String get _sentence => widget.sentences[_index];

  Future<void> _playSentence() async {
    if (_speaking) return;
    setState(() => _speaking = true);
    try {
      await _tts.speak(_sentence);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('暂时无法播放语音')),
        );
      }
    } finally {
      if (mounted) setState(() => _speaking = false);
    }
  }

  Future<void> _startRecording() async {
    if (_recording || _submitting) return;
    setState(() {
      _recording = true;
      _transcript = '';
      _result = null;
      _error = null;
    });
    try {
      final transcript = await _speech.listen();
      if (mounted) {
        setState(() => _transcript = transcript.trim());
        _answerController.text = transcript.trim();
        if (_transcript.isNotEmpty) {
          await _judge();
        }
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

  Future<void> _judge() async {
    final transcript = _transcript.trim();
    if (transcript.isEmpty) return;
    setState(() => _submitting = true);
    try {
      final result = await _apiService.judgeReadAloud(
        targetSentence: _sentence,
        studentTranscript: transcript,
      );
      if (mounted) setState(() => _result = result);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _nextSentence() {
    if (_index + 1 >= widget.sentences.length) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _index += 1;
      _transcript = '';
      _result = null;
      _error = null;
      _answerController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.bookTitle == null ? '跟读练习' : '${widget.bookTitle} · 跟读练习')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '第 ${_index + 1} / ${widget.sentences.length} 句',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
                  ),
                  const SizedBox(height: 16),
                  SurfaceCard(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _sentence,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            height: 1.45,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 20),
                        OutlinedButton.icon(
                          onPressed: _speaking ? null : _playSentence,
                          icon: const Icon(Icons.volume_up_rounded),
                          label: Text(_speaking ? '正在朗读……' : '再听一遍'),
                        ),
                        const SizedBox(height: 24),
                        if (_speech.isSupported) ...[
                          Center(
                            child: Material(
                              color: _recording ? AppColors.gold : AppColors.primary,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () {
                                  if (_recording) {
                                    _speech.stop();
                                  } else {
                                    _startRecording();
                                  }
                                },
                                child: SizedBox(
                                  width: 92,
                                  height: 92,
                                  child: Icon(
                                    _recording ? Icons.graphic_eq_rounded : Icons.mic_rounded,
                                    color: Colors.white,
                                    size: 40,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _recording ? '正在听，点击结束' : '点击麦克风，跟着读一遍',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
                          ),
                        ] else
                          const Text(
                            '当前浏览器不支持语音识别，可以直接在下方输入跟读内容。',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
                          ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: _answerController,
                          minLines: 2,
                          maxLines: 4,
                          onChanged: (value) => setState(() => _transcript = value),
                          decoration: const InputDecoration(
                            labelText: '或输入你跟读的内容',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        if (_submitting) ...[
                          const SizedBox(height: 16),
                          const LinearProgressIndicator(),
                        ],
                        if (_result != null) ...[
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _result!.correct
                                  ? AppColors.primarySoft
                                  : AppColors.gold.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _result!.correct ? '✅ 读对了！' : '🤏 还差一点',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: _result!.correct
                                        ? AppColors.primaryDark
                                        : AppColors.gold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _result!.feedback,
                                  style: const TextStyle(fontSize: 14, color: AppColors.ink),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: const TextStyle(color: AppColors.danger, fontSize: 13),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _submitting ? null : _nextSentence,
                          child: Text(_index + 1 >= widget.sentences.length ? '完成' : '下一句'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}