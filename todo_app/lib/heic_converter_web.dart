import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

// heic2any(JS) に渡す options オブジェクト
extension type _Heic2AnyOptions._(JSObject _) implements JSObject {
  external factory _Heic2AnyOptions({
    web.Blob blob,
    String toType,
    double quality,
  });
}

// web/index.html で読み込んだ heic2any グローバル関数
@JS('heic2any')
external JSPromise<JSAny?> _heic2any(_Heic2AnyOptions options);

// HEIC の bytes をブラウザ内で JPEG に変換する。失敗時は null。
Future<Uint8List?> convertHeicToJpeg(Uint8List bytes) async {
  try {
    final blob = web.Blob(
      <JSAny>[bytes.toJS].toJS,
      web.BlobPropertyBag(type: 'image/heic'),
    );
    final resultJs = await _heic2any(
      _Heic2AnyOptions(blob: blob, toType: 'image/jpeg', quality: 0.85),
    ).toDart;
    if (resultJs == null) return null;

    // heic2any は Blob または Blob[] を返す
    final web.Blob resultBlob;
    if (resultJs.isA<web.Blob>()) {
      resultBlob = resultJs as web.Blob;
    } else {
      final list = (resultJs as JSArray<JSAny?>).toDart;
      if (list.isEmpty || list.first == null) return null;
      resultBlob = list.first as web.Blob;
    }

    final buffer = await resultBlob.arrayBuffer().toDart;
    return buffer.toDart.asUint8List();
  } catch (_) {
    return null;
  }
}
