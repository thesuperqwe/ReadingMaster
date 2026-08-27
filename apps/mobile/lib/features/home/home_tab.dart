import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/api_service.dart';
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Text('加载失败：$_error'));
    }
    final home = _home!;
    final recommended = home.recommendedBook;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Hi, ${home.childName} 👋', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('今天读一本英文故事吧！'),
          const SizedBox(height: 16),
          if (recommended != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(recommended.title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text('Level: ${recommended.level}'),
                    if (recommended.estimatedMinutes != null)
                      Text('约 ${recommended.estimatedMinutes} 分钟'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ReaderPage(
                            bookId: recommended.id,
                            childId: widget.childId,
                          ),
                        ),
                      ),
                      child: const Text('开始阅读'),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text('继续阅读', style: Theme.of(context).textTheme.titleMedium),
          if (home.continueReading.isEmpty)
            const Text('暂无进行中的阅读')
          else
            ...home.continueReading.map(
              (item) => ListTile(
                title: Text(item.title),
                subtitle: Text('进度 ${(item.progress * 100).round()}%'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ReaderPage(bookId: item.bookId, childId: widget.childId),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text('今日', style: Theme.of(context).textTheme.titleMedium),
          Text('阅读 ${home.readingMinutes} 分钟 · 新词 ${home.newWords} 个'),
        ],
      ),
    );
  }
}
