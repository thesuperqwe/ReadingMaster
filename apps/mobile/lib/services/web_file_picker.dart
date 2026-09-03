import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

class PickedWebFile {
  const PickedWebFile({
    required this.name,
    required this.mimeType,
    required this.bytes,
  });

  final String name;
  final String mimeType;
  final Uint8List bytes;
}

/// Selects files/photos through a native HTML file input.
///
/// Unlike file_picker, the input stays attached to the DOM until a file is
/// chosen or the picker is dismissed. Keeping it attached is required for
/// iOS/iPadOS Safari to reliably show the file dialog.
Future<List<PickedWebFile>> pickWebFiles({
  String accept = '',
  bool multiple = false,
}) async {
  final global = globalContext;
  final document = global.getProperty('document'.toJS) as JSObject;
  final body = document.getProperty('body'.toJS) as JSObject;
  final window = global.getProperty('window'.toJS) as JSObject;

  final input = document.callMethod<JSObject>('createElement'.toJS, 'input'.toJS);
  input.setProperty('type'.toJS, 'file'.toJS);
  input.setProperty('accept'.toJS, accept.toJS);
  input.setProperty('multiple'.toJS, multiple.toJS);

  final style = input.getProperty('style'.toJS) as JSObject;
  style.setProperty('position'.toJS, 'fixed'.toJS);
  style.setProperty('left'.toJS, '-9999px'.toJS);
  style.setProperty('top'.toJS, '0'.toJS);

  body.callMethod<JSAny?>('appendChild'.toJS, input);

  final completer = Completer<List<PickedWebFile>>();
  var changed = false;
  var cleaned = false;

  late final JSFunction onFocus;

  void cleanup() {
    if (cleaned) return;
    cleaned = true;
    window.callMethod<JSAny?>('removeEventListener'.toJS, 'focus'.toJS, onFocus);
    try {
      body.callMethod<JSAny?>('removeChild'.toJS, input);
    } catch (_) {
      // Best-effort cleanup.
    }
  }

  onFocus = ((JSObject event) {
    if (changed) return;
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!changed && !completer.isCompleted) {
        cleanup();
        completer.complete(const []);
      }
    });
  }).toJS;
  window.callMethod<JSAny?>('addEventListener'.toJS, 'focus'.toJS, onFocus);

  input.setProperty('onchange'.toJS, ((JSObject event) {
    changed = true;
    final files = input.getProperty('files'.toJS) as JSObject;
    _readFileList(files).then((result) {
      cleanup();
      if (!completer.isCompleted) completer.complete(result);
    }).catchError((Object error, StackTrace stackTrace) {
      cleanup();
      if (!completer.isCompleted) completer.completeError(error, stackTrace);
    });
  }).toJS);

  input.callMethod<JSAny?>('click'.toJS);
  return completer.future;
}

Future<List<PickedWebFile>> _readFileList(JSObject files) async {
  final lengthValue = files.getProperty('length'.toJS);
  final length = lengthValue == null ? 0 : (lengthValue as JSNumber).toDartInt;
  final result = <PickedWebFile>[];

  for (var i = 0; i < length; i++) {
    final file = files.callMethod<JSObject>('item'.toJS, i.toJS);

    final name = (file.getProperty('name'.toJS) as JSString).toDart;
    final mimeValue = file.getProperty('type'.toJS);
    final mimeType = mimeValue == null ? '' : (mimeValue as JSString).toDart;
    final bytes = await _readFileBytes(file);
    result.add(PickedWebFile(name: name, mimeType: mimeType, bytes: bytes));
  }

  return result;
}

Future<Uint8List> _readFileBytes(JSObject file) async {
  final readerCtor = globalContext.getProperty('FileReader'.toJS) as JSFunction;
  final reader = readerCtor.callAsConstructor<JSObject>();
  final completer = Completer<Uint8List>();

  reader.setProperty('onload'.toJS, ((JSObject event) {
    final result = reader.getProperty('result'.toJS);
    if (result != null && result.isA<JSArrayBuffer>()) {
      final buffer = (result as JSArrayBuffer).toDart;
      if (!completer.isCompleted) completer.complete(buffer.asUint8List());
    } else if (!completer.isCompleted) {
      completer.completeError(StateError('读取文件失败'));
    }
  }).toJS);

  reader.setProperty('onerror'.toJS, ((JSObject event) {
    if (!completer.isCompleted) {
      completer.completeError(StateError('读取文件失败'));
    }
  }).toJS);

  reader.callMethod<JSAny?>('readAsArrayBuffer'.toJS, file);
  return completer.future;
}
