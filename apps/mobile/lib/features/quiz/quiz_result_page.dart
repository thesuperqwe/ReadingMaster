import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../home/home_page.dart';

class QuizResultPage extends StatefulWidget {
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
  State<QuizResultPage> createState() => _QuizResultPageState();
}

class _QuizResultPageState extends State<QuizResultPage> {
  final _apiService = ApiService();
  String? _level;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final home = await _apiService.getHome(widget.childId);
      if (mounted) setState(() => _level = home.childLevel);
    } catch (_) {
      // Level is optional; the result screen still renders without it.
    }
  }

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('阅读结果')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SurfaceCard(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.emoji_events_rounded, color: AppColors.gold, size: 48),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '阅读完成！',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.ink),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '答对 ${widget.correct} / ${widget.total}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, color: AppColors.inkSoft),
                  ),
                  if (_level != null) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.panel,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          LevelBadge(_level!, filled: true),
                          const SizedBox(width: 10),
                          Text(
                            '适合阅读 ${levelLabel(_level!)} 的故事',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: _goHome,
                    child: const Text('开始阅读之旅'),
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
