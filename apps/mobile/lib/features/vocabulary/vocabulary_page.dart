import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../services/offline_dictionary.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../reader/word_popup.dart';

class VocabularyPage extends StatefulWidget {
  const VocabularyPage({super.key, required this.childId});

  final String childId;

  @override
  State<VocabularyPage> createState() => _VocabularyPageState();
}

class _VocabularyPageState extends State<VocabularyPage> {
  final _apiService = ApiService();
  final _tts = FlutterTts();
  List<UserWord> _words = [];
  bool _loading = true;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _initTts();
    _load();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
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

  Future<Word> _lookupWord(String text) async {
    final offline = OfflineDictionary.lookup(text);
    if (offline != null) return offline;
    return _apiService.getWord(text);
  }

  List<UserWord> get _filtered {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _words;
    return _words
        .where((item) => item.word.word.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('加载失败：$_error'));
    final words = _filtered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '生词本',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.ink),
              ),
              const SizedBox(height: 6),
              const Text(
                '点击单词查看释义和发音，还可以用 AI 深入解释。',
                style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
              ),
              const SizedBox(height: 16),
              TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  hintText: '搜索生词',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: words.isEmpty
              ? const Center(
                  child: Text(
                    '还没有收藏生词，阅读时点击单词即可加入。',
                    style: TextStyle(color: AppColors.inkSoft),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                    itemCount: words.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _wordCard(words[index]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _wordCard(UserWord item) {
    final word = item.word;
    return SurfaceCard(
      onTap: () => showWordPopup(
        context,
        word,
        lookup: _lookupWord,
        aiLookup: (value, {context}) =>
            _apiService.explainWordAI(value, context: context),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        word.word,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    if (word.phonetic != null && word.phonetic!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          word.phonetic!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  word.meaningZh?.isNotEmpty == true ? word.meaningZh! : '暂无释义',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () async {
              try {
                await _tts.speak(word.word);
              } catch (_) {
                // Speech is best-effort on web.
              }
            },
            tooltip: '发音',
            icon: const Icon(Icons.volume_up_rounded, color: AppColors.primaryDark),
          ),
          const SizedBox(width: 4),
          Text(
            '${item.clickCount} 次',
            style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}
