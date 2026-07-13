import 'dart:typed_data';

// ネイティブ用スタブ。ネイティブでは flutter_image_compress で変換するため
// ここでは何もしない（null を返す）。
Future<Uint8List?> convertHeicToJpeg(Uint8List bytes) async => null;
