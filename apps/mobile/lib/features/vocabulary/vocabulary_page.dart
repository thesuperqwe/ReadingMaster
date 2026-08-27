import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/api_service.dart';

class VocabularyPage extends StatefulWidget {
  const VocabularyPage({super.key, required this.childId});

  final String childId;

  @override
  State<VocabularyPage> createState() => _VocabularyPageState();
}

class _VocabularyPageState extends State<VocabularyPage> {
  final _apiService = ApiService();
  List<UserWord> _words = [];
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
      final words = await _apiService.getVocabulary(widget.childId);
      setState(() => _words = words);
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

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _words.length,
        itemBuilder: (context, index) {
          final item = _words[index];
          return Card(
            child: ListTile(
              title: Text(item.word.word),
              subtitle: Text(item.word.meaningZh ?? ''),
              trailing: Text('点击 ${item.clickCount}'),
            ),
          );
        },
      ),
    );
  }
}
