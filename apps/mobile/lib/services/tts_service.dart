import 'tts_service_native.dart'
    if (dart.library.html) 'tts_service_web.dart' as platform;

/// Collapses runs of whitespace (including newlines imported from ebooks)
/// into single spaces so speech engines do not pause mid-sentence.
String normalizeForTts(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();

abstract class TtsService {
  Future<void> initialize();
  Future<void> speak(String text);
  Future<void> stop();
  void dispose();
}

TtsService createTtsService() => platform.createTtsService();