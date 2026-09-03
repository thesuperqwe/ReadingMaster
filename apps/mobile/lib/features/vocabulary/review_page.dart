import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../services/tts_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key, required this.childId});

  final String childId;

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  final _apiService = ApiService();
  final _tts = createTtsService();
  List<ReviewWord> _words = [];
  int _index = 0;
  int _correctCount = 0;
  int _wrongCount = 0;
  bool _loading = true;
  bool _revealed = false;
  bool _submitting = false;
  bool _finished = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initTts();
    _load();
  }

  Future<void> _initTts() async {
    await _tts.initialize();
  }

  @override
  void dispose() {
    _tts.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final words = await _apiService.getReviewWords(widget.childId);
      setState(() => _words = words);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _answer(bool correct) async {
    if (_submitting) return;
    final current = _words[_index];
    setState(() => _submitting = true);
    try {
      await _apiService.submitReview(
        childId: widget.childId,
        wordId: current.wordId,
        correct: correct,
      );
      if (correct) {
        _correctCount += 1;
      } else {
        _wrongCount += 1;
      }

      if (!mounted) return;
      if (_index + 1 >= _words.length) {
        setState(() => _finished = true);
      } else {
        setState(() {
          _index += 1;
          _revealed = false;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('提交失败：$error')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _prompt(ReviewWord word) {
    if (word.cloze?.isNotEmpty == true) return word.cloze!;
    if (word.meaningZh?.isNotEmpty == true) return '意思是：${word.meaningZh}';
    return '回忆一下这个单词的意思。';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('复习单词')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('加载失败：$_error'));

    if (_words.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.celebration_rounded, size: 56, color: AppColors.gold),
              const SizedBox(height: 16),
              const Text(
                '太棒了，暂时没有需要复习的单词。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: AppColors.inkSoft),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('返回'),
              ),
            ],
          ),
        ),
      );
    }

    if (_finished) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎉', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 12),
              const Text(
                '复习完成',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.ink),
              ),
              const SizedBox(height: 12),
              Text(
                '认识 $_correctCount 个 · 还不熟 $_wrongCount 个',
                style: const TextStyle(fontSize: 15, color: AppColors.inkSoft),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('回到生词本'),
              ),
            ],
          ),
        ),
      );
    }

    final word = _words[_index];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '第 ${_index + 1} / ${_words.length} 个',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
              ),
              const SizedBox(height: 12),
              SurfaceCard(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _revealed ? _answerView(word) : _questionView(word),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _questionView(ReviewWord word) {
    return [
      const Icon(Icons.lightbulb_outline_rounded, size: 36, color: AppColors.gold),
      const SizedBox(height: 18),
      Text(
        _prompt(word),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.ink, height: 1.4),
      ),
      const SizedBox(height: 28),
      FilledButton.icon(
        onPressed: () => setState(() => _revealed = true),
        icon: const Icon(Icons.visibility_rounded),
        label: const Text('显示答案'),
      ),
    ];
  }

  List<Widget> _answerView(ReviewWord word) {
    return [
      Row(
        children: [
          Expanded(
            child: Text(
              word.word,
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.ink),
            ),
          ),
          Material(
            color: AppColors.primary,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => _tts.speak(word.word),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(Icons.volume_up_rounded, color: Colors.white, size: 24),
              ),
            ),
          ),
        ],
      ),
      if (word.phonetic?.isNotEmpty == true) ...[
        const SizedBox(height: 8),
        Text(
          word.phonetic!,
          style: const TextStyle(fontSize: 14, color: AppColors.inkSoft),
        ),
      ],
      if (word.meaningZh?.isNotEmpty == true) ...[
        const SizedBox(height: 18),
        Text(
          word.meaningZh!,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.primaryDark),
        ),
      ],
      if (word.simpleDefinition?.isNotEmpty == true) ...[
        const SizedBox(height: 10),
        Text(
          word.simpleDefinition!,
          style: const TextStyle(fontSize: 14, color: AppColors.inkSoft, height: 1.5),
        ),
      ],
      if (word.exampleSentence?.isNotEmpty == true) ...[
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.panel,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                word.exampleSentence!,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.primaryDark),
              ),
              if (word.exampleTranslation?.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text(
                  word.exampleTranslation!,
                  style: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
                ),
              ],
            ],
          ),
        ),
      ],
      const SizedBox(height: 24),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _submitting ? null : () => _answer(false),
              child: const Text('还不熟'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: _submitting ? null : () => _answer(true),
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('我认识'),
            ),
          ),
        ],
      ),
    ];
  }
}