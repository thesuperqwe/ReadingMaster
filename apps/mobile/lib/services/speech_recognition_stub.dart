import 'speech_recognition.dart';

class UnsupportedSpeechRecognition implements SpeechRecognitionService {
  @override
  bool get isSupported => false;

  @override
  Future<String> listen() async {
    throw UnsupportedError('当前平台不支持浏览器语音识别，请使用文字输入。');
  }

  @override
  Future<void> stop() async {}
}

SpeechRecognitionService createSpeechRecognition() =>
    UnsupportedSpeechRecognition();