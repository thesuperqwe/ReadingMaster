import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../models/models.dart';

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
      if (mounted) setState(() => _aiError = error.toString());
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
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      displayWord.word,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  IconButton.filled(
                    onPressed: () async {
                      await widget.onSpeak?.call();
                      await _tts.speak(displayWord.word);
                    },
                    icon: const Icon(Icons.volume_up),
                  ),
                ],
              ),
              if (displayWord.phonetic?.isNotEmpty ?? false) ...[
                const SizedBox(height: 8),
                Text(displayWord.phonetic!),
              ],
              if (displayWord.meaningZh?.isNotEmpty ?? false) ...[
                const SizedBox(height: 12),
                Text(displayWord.meaningZh!, style: const TextStyle(fontSize: 22)),
              ],
              if (displayWord.simpleDefinition?.isNotEmpty ?? false) ...[
                const SizedBox(height: 12),
                _tappableText(
                  displayWord.simpleDefinition!,
                  Theme.of(context).textTheme.bodyLarge!,
                ),
              ],
              if (displayWord.exampleSentence?.isNotEmpty ?? false) ...[
                const SizedBox(height: 12),
                _tappableText(
                  displayWord.exampleSentence!,
                  Theme.of(context).textTheme.bodyLarge!.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                if (displayWord.exampleTranslation?.isNotEmpty ?? false)
                  Text(displayWord.exampleTranslation!),
              ],
              if (_aiResult != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Chip(label: const Text('AI 解释')),
                ),
              if (showDictionary && widget.aiLookup != null) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _loadingAI ? null : _loadAI,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('用 AI 解释'),
                ),
              ],
              if (_loadingAI) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              if (_aiError != null) ...[
                const SizedBox(height: 12),
                Text(
                  _aiError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (!showDictionary && _aiResult == null && !_loadingAI && _aiError == null)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text('这个词暂未收录，先标记为生词。'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
