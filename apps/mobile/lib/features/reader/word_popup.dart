import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../models/models.dart';

Future<void> showWordPopup(BuildContext context, Word word) async {
  final tts = FlutterTts();
  await tts.setLanguage('en-US');
  await tts.setSpeechRate(0.45);

  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      word.word,
                      style: Theme.of(context).textTheme.headlineMedium,
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
                const SizedBox(height: 8),
                Text(word.simpleDefinition!),
              ],
              if (word.exampleSentence != null && word.exampleSentence!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(word.exampleSentence!),
                if (word.exampleTranslation != null && word.exampleTranslation!.isNotEmpty)
                  Text(word.exampleTranslation!),
              ],
            ],
          ),
        ),
      );
    },
  );
}
