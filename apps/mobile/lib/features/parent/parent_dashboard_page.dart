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
  ParentStats? _stats;
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
      final stats = await _apiService.getParentStats(widget.childId);
      setState(() => _stats = stats);
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

    final stats = _stats!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        _header(),
        const SizedBox(height: 22),
        _childCard(stats),
        const SizedBox(height: 26),
        const SectionTitle('本周阅读'),
        const SizedBox(height: 14),
        SurfaceCard(
          child: Wrap(
            spacing: 28,
            runSpacing: 16,
            children: [
              StatPill(
                icon: Icons.auto_stories_rounded,
                label: '阅读本数',
                value: '${stats.booksRead}',
              ),
              StatPill(
                icon: Icons.schedule_rounded,
                label: '阅读分钟',
                value: '${stats.readingMinutes}',
              ),
              StatPill(
                icon: Icons.spellcheck_rounded,
                label: '新学单词',
                value: '${stats.newWords}',
                accent: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        const SectionTitle('最近表现'),
        const SizedBox(height: 14),
        SurfaceCard(
          child: Column(
            children: [
              _metricBar('阅读理解正确率', stats.quizAccuracy),
              const SizedBox(height: 20),
              _metricBar('单词掌握度', stats.wordMastery),
            ],
          ),
        ),
        const SizedBox(height: 26),
        const SectionTitle('需要关注', subtitle: '掌握度偏低的单词，建议重点复习'),
        const SizedBox(height: 14),
        SurfaceCard(child: _attentionWords(stats.attentionWords)),
      ],
    );
  }

  Widget _header() {
    return Row(
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
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
    );
  }

  Widget _childCard(ParentStats stats) {
    return SurfaceCard(
      child: Row(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stats.childName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                if (stats.grade != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${stats.grade} 年级',
                    style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
                  ),
                ],
              ],
            ),
          ),
          if (stats.childLevel != null) LevelBadge(stats.childLevel!, filled: true),
        ],
      ),
    );
  }

  Widget _metricBar(String label, double value) {
    final percent = (value.clamp(0.0, 1.0) * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink),
              ),
            ),
            Text(
              '$percent%',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            minHeight: 10,
            backgroundColor: AppColors.panel,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _attentionWords(List<AttentionWord> words) {
    if (words.isEmpty) {
      return const Text(
        '暂无需要重点关注的单词。',
        style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: words.map((item) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.word,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              if (item.meaningZh?.isNotEmpty == true) ...[
                const SizedBox(width: 6),
                Text(
                  item.meaningZh!,
                  style: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }
}