import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class ParentDashboardPage extends StatefulWidget {
  const ParentDashboardPage({super.key, required this.childId});

  final String childId;

  @override
  State<ParentDashboardPage> createState() => _ParentDashboardPageState();
}

class _ParentDashboardPageState extends State<ParentDashboardPage> {
  final _apiService = ApiService();
  HomeData? _home;
  bool _loading = true;
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
      final home = await _apiService.getHome(widget.childId);
      setState(() => _home = home);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('加载失败：$_error'));

    final home = _home!;
    final recommended = home.recommendedBook;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.family_restroom_rounded,
                size: 28,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    '家长中心',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '孩子的阅读成长概览',
                    style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.face_rounded, color: AppColors.gold),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      home.childName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  if (home.childLevel != null) LevelBadge(home.childLevel!, filled: true),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 28,
                runSpacing: 16,
                children: [
                  StatPill(
                    icon: Icons.schedule_rounded,
                    label: '阅读分钟',
                    value: '${home.readingMinutes}',
                  ),
                  StatPill(
                    icon: Icons.auto_stories_rounded,
                    label: '新学单词',
                    value: '${home.newWords}',
                    accent: true,
                  ),
                ],
              ),
            ],
          ),
        ),
        if (recommended != null) ...[
          const SizedBox(height: 26),
          const SectionTitle('推荐书目', subtitle: '根据当前阅读等级为你推荐'),
          const SizedBox(height: 14),
          SurfaceCard(
            color: AppColors.panel,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                BookCover(
                  title: recommended.title,
                  level: recommended.level,
                  height: 120,
                  width: 92,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recommended.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          LevelBadge(recommended.level),
                          if (recommended.estimatedMinutes != null) ...[
                            const SizedBox(width: 10),
                            Text(
                              '约 ${recommended.estimatedMinutes} 分钟',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.inkSoft,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}