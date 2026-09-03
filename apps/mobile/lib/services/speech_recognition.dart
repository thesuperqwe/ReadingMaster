import 'speech_recognition_stub.dart'
    if (dart.library.js) 'speech_recognition_web.dart' as impl;

abstract class SpeechRecognitionService {
  bool get isSupported;
  Future<String> listen();
  Future<void> stop();
}

SpeechRecognitionService createSpeechRecognition() => impl.createSpeechRecognition();