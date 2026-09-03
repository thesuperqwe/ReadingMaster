// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;

import '../core/api_client.dart';
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

class WebTtsService implements TtsService {
  html.AudioElement? _audio;
  Completer<void>? _completer;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> speak(String text) async {
    text = normalizeForTts(text);
    if (text.trim().isEmpty) return;
    await stop();

    try {
      final data = await ApiClient.post(
        '/api/v1/tts/synthesize',
        body: {'text': text, 'language_code': 'en-US'},
      );
      final audioBase64 = data['audio_base64'] as String?;
      final mimeType = data['mime_type'] as String? ?? 'audio/mpeg';
      if (audioBase64 == null || audioBase64.isEmpty) {
        throw const ApiException('Google TTS returned no audio');
      }

      final audio = html.AudioElement('data:$mimeType;base64,$audioBase64');
      _audio = audio;
      final completer = Completer<void>();
      _completer = completer;
      var completed = false;
      void complete() {
        if (completed) return;
        completed = true;
        _audio = null;
        if (!completer.isCompleted) completer.complete();
      }

      audio.onEnded.listen((_) => complete());
      audio.onError.listen((_) {
        complete();
        _speakWithBrowser(text);
      });
      await audio.play();
      return completer.future;
    } catch (_) {
      await _speakWithBrowser(text);
    }
  }

  Future<void> _speakWithBrowser(String text) async {
    final speech = html.window.speechSynthesis;
    if (speech == null) return;
    speech.cancel();

    final utterance = html.SpeechSynthesisUtterance(text)
      ..lang = 'en-US'
      ..rate = 0.85
      ..pitch = 1.0;

    final voice = _preferEnglishVoice(speech.getVoices());
    if (voice != null) utterance.voice = voice;

    final completer = Completer<void>();
    _completer = completer;
    utterance.onEnd.listen((_) {
      if (!completer.isCompleted) completer.complete();
    });
    utterance.onError.listen((_) {
      if (!completer.isCompleted) completer.complete();
    });

    speech.speak(utterance);
    return completer.future;
  }

  html.SpeechSynthesisVoice? _preferEnglishVoice(List<html.SpeechSynthesisVoice> voices) {
    for (final pattern in _preferredVoiceNames) {
      for (final voice in voices) {
        if ((voice.name ?? '').toLowerCase().contains(pattern)) return voice;
      }
    }

    for (final voice in voices) {
      if ((voice.lang ?? '').toLowerCase().startsWith('en')) return voice;
    }
    return voices.isNotEmpty ? voices.first : null;
  }

  @override
  Future<void> stop() async {
    final completer = _completer;
    _completer = null;
    if (completer != null && !completer.isCompleted) completer.complete();

    final audio = _audio;
    _audio = null;
    if (audio != null) audio.pause();

    final speech = html.window.speechSynthesis;
    if (speech != null) speech.cancel();
  }

  @override
  void dispose() {
    stop();
  }
}

TtsService createTtsService() => WebTtsService();