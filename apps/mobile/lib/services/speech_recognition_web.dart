import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import '../core/api_client.dart';
import 'speech_recognition.dart';

class BrowserSpeechRecognition implements SpeechRecognitionService {
  JSObject? _recognition;
  JSObject? _mediaRecorder;
  bool _listening = false;
  bool _stopRequested = false;

  bool get _hasBrowserSpeech {
    final global = globalContext;
    return global.has('webkitSpeechRecognition') || global.has('SpeechRecognition');
  }

  bool get _canRecord {
    final global = globalContext;
    if (!global.has('MediaRecorder')) return false;
    final navigator = global.getProperty('navigator'.toJS);
    if (navigator == null || !navigator.isA<JSObject>()) return false;
    final mediaDevices = (navigator as JSObject).getProperty('mediaDevices'.toJS);
    if (mediaDevices == null || !mediaDevices.isA<JSObject>()) return false;
    return (mediaDevices as JSObject).has('getUserMedia');
  }

  @override
  bool get isSupported => _hasBrowserSpeech || _canRecord;

  @override
  Future<String> listen() async {
    if (_listening) {
      throw StateError('语音识别已经在进行中。');
    }

    _stopRequested = false;

    if (_hasBrowserSpeech) {
      return _listenWithBrowser();
    }

    if (_canRecord) {
      return _listenWithCloud();
    }

    throw UnsupportedError('当前浏览器不支持语音识别。');
  }

  Future<String> _listenWithBrowser() async {
    final global = globalContext;
    final constructor = global['webkitSpeechRecognition'] ?? global['SpeechRecognition'];
    if (constructor == null || !constructor.isA<JSFunction>()) {
      throw UnsupportedError('当前浏览器不支持语音识别。');
    }

    final recognitionConstructor = constructor as JSFunction;
    final recognition = recognitionConstructor.callAsConstructor<JSObject>();
    recognition['lang'] = 'en-US'.toJS;
    recognition['continuous'] = false.toJS;
    recognition['interimResults'] = false.toJS;
    recognition['maxAlternatives'] = 1.toJS;

    final completer = Completer<String>();
    _recognition = recognition;
    _listening = true;

    recognition['onresult'] = ((JSObject event) {
      final transcript = _transcriptFromEvent(event);
      if (!completer.isCompleted) {
        completer.complete(transcript.trim());
      }
    }).toJS;

    recognition['onerror'] = ((JSObject event) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('语音识别失败'));
      }
    }).toJS;

    recognition['onend'] = (() {
      _listening = false;
      if (!completer.isCompleted) {
        completer.complete('');
      }
    }).toJS;

    try {
      recognition.callMethod<JSAny?>('start'.toJS);
    } catch (_) {
      _listening = false;
      if (!completer.isCompleted) {
        completer.completeError(StateError('无法启动语音识别'));
      }
    }

    return completer.future;
  }

  Future<String> _listenWithCloud() async {
    final stream = await _getUserMedia();
    final recorder = _createRecorder(stream);
    final chunks = _newArray();
    _mediaRecorder = recorder;

    final stopped = Completer<void>();
    recorder['ondataavailable'] = ((JSObject event) {
      final blob = event.getProperty('data'.toJS);
      if (blob != null) {
        chunks.callMethod<JSAny?>('push'.toJS, blob);
      }
    }).toJS;

    recorder['onstop'] = (() {
      if (!stopped.isCompleted) stopped.complete();
    }).toJS;

    _listening = true;
    try {
      recorder.callMethod<JSAny?>('start'.toJS);
      if (_stopRequested) {
        recorder.callMethod<JSAny?>('stop'.toJS);
      }
    } catch (_) {
      _listening = false;
      _mediaRecorder = null;
      _stopTracks(stream);
      throw StateError('无法启动录音');
    }

    try {
      await stopped.future;
    } finally {
      _listening = false;
      _mediaRecorder = null;
      _stopTracks(stream);
    }

    final mimeType = _recorderMimeType(recorder);
    final blob = _buildBlob(chunks, mimeType);
    final dataUrl = await _readAsDataUrl(blob);
    final comma = dataUrl.indexOf(',');
    final semicolon = dataUrl.indexOf(';');
    final mime = dataUrl.substring(5, semicolon);
    final base64 = dataUrl.substring(comma + 1);

    final data = await ApiClient.post(
      '/api/v1/asr/transcribe',
      body: {'audio_base64': base64, 'mime_type': mime},
    );
    final transcript = (data as Map<String, dynamic>)['transcript'] as String?;
    return (transcript ?? '').trim();
  }

  Future<JSObject> _getUserMedia() async {
    final global = globalContext;
    final navigator = global.getProperty('navigator'.toJS) as JSObject;
    final mediaDevices = navigator.getProperty('mediaDevices'.toJS) as JSObject;
    final constraints = _newObject();
    constraints['audio'] = true.toJS;

    try {
      final promise = mediaDevices.callMethod<JSPromise<JSObject>>(
        'getUserMedia'.toJS,
        constraints,
      );
      return await promise.toDart;
    } catch (_) {
      throw StateError('无法访问麦克风，请检查浏览器权限');
    }
  }

  JSObject _newObject() {
    final ctor = globalContext.getProperty('Object'.toJS) as JSFunction;
    return ctor.callAsConstructor<JSObject>();
  }

  JSObject _newArray() {
    final ctor = globalContext.getProperty('Array'.toJS) as JSFunction;
    return ctor.callAsConstructor<JSObject>();
  }

  JSObject _createRecorder(JSObject stream) {
    final ctor = globalContext.getProperty('MediaRecorder'.toJS) as JSFunction;
    return ctor.callAsConstructor<JSObject>(stream);
  }

  String _recorderMimeType(JSObject recorder) {
    try {
      final value = recorder.getProperty('mimeType'.toJS);
      if (value != null && value.isA<JSString>()) {
        final mime = (value as JSString).toDart;
        if (mime.isNotEmpty) return mime;
      }
    } catch (_) {
      // Fall back to webm below.
    }
    return 'audio/webm';
  }

  JSObject _buildBlob(JSObject chunks, String mimeType) {
    final ctor = globalContext.getProperty('Blob'.toJS) as JSFunction;
    final options = _newObject();
    options['type'] = mimeType.toJS;
    return ctor.callAsConstructor<JSObject>(chunks, options);
  }

  Future<String> _readAsDataUrl(JSObject blob) async {
    final ctor = globalContext.getProperty('FileReader'.toJS) as JSFunction;
    final reader = ctor.callAsConstructor<JSObject>();
    final completer = Completer<String>();

    reader['onload'] = ((JSObject event) {
      final result = reader.getProperty('result'.toJS);
      if (result != null && result.isA<JSString>()) {
        if (!completer.isCompleted) completer.complete((result as JSString).toDart);
      } else if (!completer.isCompleted) {
        completer.completeError(StateError('读取录音失败'));
      }
    }).toJS;

    reader['onerror'] = ((JSObject event) {
      if (!completer.isCompleted) completer.completeError(StateError('读取录音失败'));
    }).toJS;

    reader.callMethod<JSAny?>('readAsDataURL'.toJS, blob);
    return completer.future;
  }

  void _stopTracks(JSObject stream) {
    try {
      final tracks = stream.callMethod<JSObject>('getTracks'.toJS);
      tracks.callMethod<JSAny?>('forEach'.toJS, ((JSObject track) {
        track.callMethod<JSAny?>('stop'.toJS);
      }).toJS);
    } catch (_) {
      // Track cleanup is best-effort.
    }
  }

  @override
  Future<void> stop() async {
    _stopRequested = true;
    try {
      _recognition?.callMethod<JSAny?>('stop'.toJS);
    } catch (_) {
      // Stop is best-effort.
    }
    try {
      _mediaRecorder?.callMethod<JSAny?>('stop'.toJS);
    } catch (_) {
      // Stop is best-effort.
    }
  }

  String _transcriptFromEvent(JSObject event) {
    try {
      final results = event.getProperty('results'.toJS);
      final firstResult = (results as JSObject).getProperty('0'.toJS);
      final firstAlternative = (firstResult as JSObject).getProperty('0'.toJS);
      final transcriptValue = (firstAlternative as JSObject).getProperty('transcript'.toJS);
      if (transcriptValue == null || !transcriptValue.isA<JSString>()) {
        return '';
      }
      return (transcriptValue as JSString).toDart;
    } catch (_) {
      return '';
    }
  }
}

SpeechRecognitionService createSpeechRecognition() => BrowserSpeechRecognition();
