import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class _PlacementQuestion {
  const _PlacementQuestion({
    required this.sentence,
    required this.question,
    required this.options,
    required this.correctIndex,
  });

  final String sentence;
  final String question;
  final List<String> options;
  final int correctIndex;
}

class PlacementTest extends StatefulWidget {
  const PlacementTest({super.key});

  @override
  State<PlacementTest> createState() => _PlacementTestState();
}

class _PlacementTestState extends State<PlacementTest> {
  static const _questions = [
    _PlacementQuestion(
      sentence: 'Tom has a little dog.',
      question: 'Tom 有什么？',
      options: ['一只小狗', '一只小猫', '一辆自行车'],
      correctIndex: 0,
    ),
    _PlacementQuestion(
      sentence: 'The dog is very cute.',
      question: '这只狗怎么样？',
      options: ['很凶', '很可爱', '很大'],
      correctIndex: 1,
    ),
    _PlacementQuestion(
      sentence: 'Tom likes to play with his dog in the park.',
      question: '他们喜欢在哪里玩？',
      options: ['公园', '学校', '家里'],
      correctIndex: 0,
    ),
    _PlacementQuestion(
      sentence: 'One day, the dog runs away.',
      question: '发生了什么事？',
      options: ['狗睡着了', '狗跑走了', '狗在吃饭'],
      correctIndex: 1,
    ),
    _PlacementQuestion(
      sentence: 'Tom looks for his dog under the trees.',
      question: 'Tom 在做什么？',
      options: ['找他的狗', '吃午饭', '去上学'],
      correctIndex: 0,
    ),
    _PlacementQuestion(
      sentence: 'He finds the dog under a tall tree.',
      question: '狗在哪里？',
      options: ['一辆车里', '一条船上', '一棵大树下'],
      correctIndex: 2,
    ),
  ];

  int _index = 0;
  int _correct = 0;
  bool _finished = false;

  String get _resultLevel {
    if (_correct <= 2) return 'LEVEL_1';
    if (_correct <= 4) return 'LEVEL_2';
    if (_correct == 5) return 'LEVEL_3';
    return 'LEVEL_4';
  }

  void _answer(int selected) {
    final question = _questions[_index];
    final nextCorrect = _correct + (selected == question.correctIndex ? 1 : 0);
    setState(() {
      _correct = nextCorrect;
      if (_index + 1 >= _questions.length) {
        _finished = true;
      } else {
        _index += 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('水平测试')),
      body: _finished ? _resultView() : _questionView(),
    );
  }

  Widget _questionView() {
    final question = _questions[_index];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '第 ${_index + 1} / ${_questions.length} 题',
                  style: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (_index + 1) / _questions.length,
                    minHeight: 8,
                    backgroundColor: AppColors.line,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 28),
                SurfaceCard(
                  color: AppColors.panel,
                  child: Text(
                    question.sentence,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  question.question,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink),
                ),
                const SizedBox(height: 16),
                ...question.options.map(
                  (option) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: OutlinedButton(
                      onPressed: () => _answer(question.options.indexOf(option)),
                      child: Text(option),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _resultView() {
    final level = _resultLevel;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SurfaceCard(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.emoji_events_rounded, color: AppColors.gold, size: 44),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '测评完成',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.ink),
                ),
                const SizedBox(height: 8),
                Text(
                  '答对 $_correct / ${_questions.length} 题',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: AppColors.inkSoft),
                ),
                const SizedBox(height: 20),
                Center(child: LevelBadge(level, filled: true)),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    '推荐阅读等级：${levelLabel(level)}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink),
                  ),
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(level),
                  child: const Text('使用推荐等级'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}