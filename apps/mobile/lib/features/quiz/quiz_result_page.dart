import 'package:flutter/material.dart';

import '../home/home_page.dart';

class QuizResultPage extends StatelessWidget {
  const QuizResultPage({
    super.key,
    required this.total,
    required this.correct,
    required this.bookId,
    required this.childId,
  });

  final int total;
  final int correct;
  final String bookId;
  final String childId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('阅读结果')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('🎉 You did it!', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 24),
              Text('答对 $correct / $total', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const HomePage()),
                  (route) => false,
                ),
                child: const Text('回到首页'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
