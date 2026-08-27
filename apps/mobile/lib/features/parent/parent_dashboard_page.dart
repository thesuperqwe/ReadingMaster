import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/api_service.dart';

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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(home.childName, style: Theme.of(context).textTheme.headlineSmall),
        if (home.childLevel != null) Text('阅读等级：${home.childLevel}'),
        const SizedBox(height: 16),
        Text('本周阅读', style: Theme.of(context).textTheme.titleMedium),
        Text('阅读 ${home.readingMinutes} 分钟'),
        Text('新词 ${home.newWords} 个'),
      ],
    );
  }
}
