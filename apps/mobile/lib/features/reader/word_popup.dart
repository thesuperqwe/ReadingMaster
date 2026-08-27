import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../models/models.dart';
import '../../theme/app_theme.dart';

Future<void> showWordPopup(
  BuildContext context,
  Word word, {
  required Future<Word> Function(String word) lookup,
  Future<Word> Function(String word, {String? context})? aiLookup,
  Future<void> Function()? onSpeak,
  String? contextText,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => WordDetailSheet(
      word: word,
      lookup: lookup,
      aiLookup: aiLookup,
      onSpeak: onSpeak,
      contextText: contextText,
    ),
  );
}

class WordDetailSheet extends StatefulWidget {
  const WordDetailSheet({
    super.key,
    required this.word,
    required this.lookup,
    this.aiLookup,
    this.onSpeak,
    this.contextText,
  });

  final Word word;
  final Future<Word> Function(String word) lookup;
  final Future<Word> Function(String word, {String? context})? aiLookup;
  final Future<void> Function()? onSpeak;
  final String? contextText;

  @override
  State<WordDetailSheet> createState() => _WordDetailSheetState();
}

class _WordDetailSheetState extends State<WordDetailSheet> {
  final _tts = FlutterTts();
  Word? _aiResult;
  bool _loadingAI = false;
  String? _aiError;

  bool get _hasDictionary =>
      (widget.word.meaningZh?.isNotEmpty ?? false) ||
      (widget.word.simpleDefinition?.isNotEmpty ?? false);

  @override
  void initState() {
    super.initState();
    _initTts();
    if (!_hasDictionary && widget.aiLookup != null) {
      _loadAI();
    }
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
  }

  Future<void> _loadAI() async {
    if (widget.aiLookup == null) return;
    setState(() {
      _loadingAI = true;
      _aiError = null;
    });
    try {
      final result = await widget.aiLookup!(
        widget.word.word,
        context: widget.contextText,
      );
      if (mounted) setState(() => _aiResult = result);
    } catch (error) {
      if (mounted) {
        setState(() => _aiError = error.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI 解释失败：$error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingAI = false);
    }
  }

  Future<void> _openNestedWord(String token) async {
    final normalized = token.replaceAll(RegExp(r"[^a-zA-Z']"), '').toLowerCase();
    if (normalized.isEmpty) return;

    Navigator.of(context).pop();
    final detail = await widget.lookup(normalized);
    if (!mounted) return;
    await showWordPopup(
      context,
      detail,
      lookup: widget.lookup,
      aiLookup: widget.aiLookup,
      onSpeak: widget.onSpeak,
      contextText: widget.contextText,
    );
  }

  Widget _tappableText(String text, TextStyle style) {
    final words = text.split(RegExp(r'\s+')).where((item) => item.isNotEmpty).toList();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: words
          .map(
            (item) => GestureDetector(
              onTap: () => _openNestedWord(item),
              child: Text(item, style: style),
            ),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayWord = _aiResult ?? widget.word;
    final showDictionary = _aiResult == null && _hasDictionary;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayWord.word,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                            height: 1.1,
                          ),
                        ),
                        if (displayWord.phonetic?.isNotEmpty ?? false) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              displayWord.phonetic!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Material(
                    color: AppColors.primary,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () async {
                        try {
                          await widget.onSpeak?.call();
                        } catch (_) {
                          // Event recording should not block speech playback.
                        }
                        await _tts.speak(displayWord.word);
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(Icons.volume_up_rounded, color: Colors.white, size: 24),
                      ),
                    ),
                  ),
                ],
              ),
              if (displayWord.meaningZh?.isNotEmpty ?? false) ...[
                const SizedBox(height: 18),
                Text(
                  displayWord.meaningZh!,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                    height: 1.3,
                  ),
                ),
              ],
              if (displayWord.simpleDefinition?.isNotEmpty ?? false) ...[
                const SizedBox(height: 12),
                _tappableText(
                  displayWord.simpleDefinition!,
                  const TextStyle(fontSize: 15, color: AppColors.inkSoft, height: 1.5),
                ),
              ],
              if (displayWord.exampleSentence?.isNotEmpty ?? false) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.panel,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _tappableText(
                        displayWord.exampleSentence!,
                        const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryDark,
                          height: 1.5,
                        ),
                      ),
                      if (displayWord.exampleTranslation?.isNotEmpty ?? false) ...[
                        const SizedBox(height: 6),
                        Text(
                          displayWord.exampleTranslation!,
                          style: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              if (_aiResult != null)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome_rounded, size: 14, color: AppColors.gold),
                            SizedBox(width: 5),
                            Text(
                              'AI 解释',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.gold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              if (showDictionary && widget.aiLookup != null) ...[
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: _loadingAI ? null : _loadAI,
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('用 AI 解释'),
                ),
              ],
              if (_loadingAI) ...[
                const SizedBox(height: 14),
                const LinearProgressIndicator(),
              ],
              if (_aiError != null) ...[
                const SizedBox(height: 14),
                Text(
                  _aiError!,
                  style: const TextStyle(color: AppColors.danger, fontSize: 13),
                ),
              ],
              if (!showDictionary && _aiResult == null && !_loadingAI && _aiError == null)
                const Padding(
                  padding: EdgeInsets.only(top: 14),
                  child: Text(
                    '这个词暂未收录，先标记为生词。',
                    style: TextStyle(color: AppColors.inkSoft),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
