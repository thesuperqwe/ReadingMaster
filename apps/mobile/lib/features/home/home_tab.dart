import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../reader/reader_page.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key, required this.childId});

  final String childId;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
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

  void _openBook(String bookId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReaderPage(bookId: bookId, childId: widget.childId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('加载失败：$_error'));
    final home = _home!;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        children: [
          _greeting(home),
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 700;
              final hero = _recommendationCard(home);
              final stats = _todayStats(home);
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: hero),
                    const SizedBox(width: 20),
                    Expanded(flex: 6, child: stats),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  hero,
                  const SizedBox(height: 16),
                  stats,
                ],
              );
            },
          ),
          const SizedBox(height: 28),
          const SectionTitle('继续阅读', subtitle: '从上次读到的位置继续'),
          const SizedBox(height: 14),
          ..._continueReading(home),
          const SizedBox(height: 28),
          const SectionTitle('今日成就'),
          const SizedBox(height: 14),
          _achievements(home),
        ],
      ),
    );
  }

  Widget _greeting(HomeData home) {
    final level = home.childLevel;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      'Hi，${home.childName}！',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.wb_sunny_rounded, color: AppColors.gold, size: 24),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                '今天也是快乐阅读的一天！',
                style: TextStyle(fontSize: 14, color: AppColors.inkSoft),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        if (level != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_florist_rounded, size: 18, color: AppColors.primaryDark),
                const SizedBox(width: 6),
                Text(
                  levelLabel(level),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _recommendationCard(HomeData home) {
    final rec = home.recommendedBook;
    if (rec == null) {
      return const SurfaceCard(
        color: AppColors.panel,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '为你推荐',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink),
            ),
            SizedBox(height: 8),
            Text(
              '还没有推荐图书，去书架选择一本喜欢的开始阅读吧。',
              style: TextStyle(color: AppColors.inkSoft),
            ),
          ],
        ),
      );
    }

    return SurfaceCard(
      onTap: () => _openBook(rec.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BookCover(title: rec.title, level: rec.level, height: 132, width: 104),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        LevelBadge(rec.level, filled: true),
                        const Spacer(),
                        const StarRow(),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      rec.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '约 ${rec.estimatedMinutes ?? 5} 分钟 · 今日推荐',
                      style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _openBook(rec.id),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('开始阅读'),
          ),
        ],
      ),
    );
  }

  Widget _todayStats(HomeData home) {
    return SurfaceCard(
      color: AppColors.panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '今日阅读数据',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: StatPill(
                  icon: Icons.schedule_rounded,
                  label: '阅读时长',
                  value: '${home.readingMinutes} 分钟',
                ),
              ),
              Expanded(
                child: StatPill(
                  icon: Icons.style_rounded,
                  label: '今日生词',
                  value: '${home.newWords} 个',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StatPill(
            icon: Icons.auto_stories_rounded,
            label: '正在阅读',
            value: '${home.continueReading.length} 本',
            accent: true,
          ),
        ],
      ),
    );
  }

  List<Widget> _continueReading(HomeData home) {
    if (home.continueReading.isEmpty) {
      return const [
        SurfaceCard(
          color: AppColors.panel,
          child: Row(
            children: [
              Icon(Icons.local_library_rounded, color: AppColors.primaryDark),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '暂时没有进行中的阅读，选一本书开始吧。',
                  style: TextStyle(color: AppColors.inkSoft),
                ),
              ),
            ],
          ),
        ),
      ];
    }

    return home.continueReading.map((item) {
      final progress = item.progress.clamp(0.0, 1.0);
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SurfaceCard(
          padding: const EdgeInsets.all(12),
          onTap: () => _openBook(item.bookId),
          child: Row(
            children: [
              BookCover(title: item.title, height: 78, width: 60),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: AppColors.line,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '已读 ${(progress * 100).round()}%',
                      style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, color: AppColors.primaryDark),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _achievements(HomeData home) {
    return SurfaceCard(
      color: AppColors.panel,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.emoji_events_rounded, color: AppColors.gold, size: 28),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '坚持阅读',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink),
                ),
                SizedBox(height: 4),
                Text(
                  '今天还没有阅读记录，挑一本喜欢的书开始吧。',
                  style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
