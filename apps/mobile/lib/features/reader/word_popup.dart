import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../models/models.dart';

Future<void> showWordPopup(
  BuildContext context,
  Word word, {
  required Future<Word> Function(String word) lookup,
}) async {
  final tts = FlutterTts();
  await tts.setLanguage('en-US');
  await tts.setSpeechRate(0.45);

  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      Future<void> openWord(String token) async {
        final normalized = token.replaceAll(RegExp(r"[^a-zA-Z']"), '').toLowerCase();
        if (normalized.isEmpty) return;

        Navigator.of(sheetContext).pop();
        final detail = await lookup(normalized);
        if (context.mounted) {
          await showWordPopup(context, detail, lookup: lookup);
        }
      }

      Widget tappableText(String text, TextStyle style) {
        final words = text.split(RegExp(r'\s+')).where((item) => item.isNotEmpty).toList();
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: words
              .map(
                (item) => GestureDetector(
                  onTap: () => openWord(item),
                  child: Text(item, style: style),
                ),
              )
              .toList(),
        );
      }

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
                        word.word,
                        style: Theme.of(sheetContext).textTheme.headlineMedium,
                      ),
                    ),
                    IconButton.filled(
                      onPressed: () => tts.speak(word.word),
                      icon: const Icon(Icons.volume_up),
                    ),
                  ],
                ),
                if (word.phonetic != null && word.phonetic!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(word.phonetic!),
                ],
                if (word.meaningZh != null && word.meaningZh!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(word.meaningZh!, style: const TextStyle(fontSize: 22)),
                ],
                if (word.simpleDefinition != null && word.simpleDefinition!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  tappableText(
                    word.simpleDefinition!,
                    Theme.of(sheetContext).textTheme.bodyLarge!,
                  ),
                ],
                if (word.exampleSentence != null && word.exampleSentence!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  tappableText(
                    word.exampleSentence!,
                    Theme.of(sheetContext).textTheme.bodyLarge!.copyWith(
                      color: Theme.of(sheetContext).colorScheme.primary,
                    ),
                  ),
                  if (word.exampleTranslation != null && word.exampleTranslation!.isNotEmpty)
                    Text(word.exampleTranslation!),
                ],
                if (word.meaningZh == null &&
                    word.simpleDefinition == null &&
                    word.exampleSentence == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text('这个词暂未收录，先标记为生词。'),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
