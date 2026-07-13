// プラットフォームに応じて HEIC 変換の実装を切り替える。
// ネイティブ（iOS/Android）はスタブ（flutter_image_compress で別途変換するため未使用）、
// Web は heic2any(JS) を使った実装を用いる。
export 'heic_converter_stub.dart'
    if (dart.library.js_interop) 'heic_converter_web.dart';
