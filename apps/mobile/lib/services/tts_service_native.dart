import 'package:flutter_tts/flutter_tts.dart';

import 'tts_service.dart';

const _preferredVoiceNames = [
  'microsoft aria',
  'microsoft jenny',
  'google uk english female',
  'google us english',
  'samantha',
  'karen',
  'daniel',
  'google uk english male',
];

class NativeTtsService implements TtsService {
  final FlutterTts _tts = FlutterTts();

  @override
  Future<void> initialize() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.42);
    await _tts.setPitch(1.0);
    await _preferEnglishVoice();
  }

  Future<void> _preferEnglishVoice() async {
    try {
      final rawVoices = await _tts.getVoices;
      if (rawVoices is! List) return;

      final voices = rawVoices
          .whereType<Map>()
          .map((voice) => Map<String, String>.from(voice))
          .where((voice) {
            final locale = (voice['locale'] ?? '').toLowerCase();
            return locale.startsWith('en') || locale.isEmpty;
          })
          .toList();

      for (final pattern in _preferredVoiceNames) {
        for (final voice in voices) {
          final name = (voice['name'] ?? '').toLowerCase();
          if (name.contains(pattern)) {
            await _tts.setVoice({
              'name': voice['name'] ?? '',
              'locale': voice['locale'] ?? '',
            });
            return;
          }
        }
      }
    } catch (_) {
      // Voice selection is best-effort; system default remains usable.
    }
  }

  @override
  Future<void> speak(String text) => _tts.speak(normalizeForTts(text));

  @override
  Future<void> stop() => _tts.stop();

  @override
  void dispose() {
    _tts.stop();
  }
}

TtsService createTtsService() => NativeTtsService();