part of '../../../main.dart';

// クリップボードにコピーした画像の貼り付け（貼り付けボタン / Ctrl・Cmd+V）
extension _TodoHomePasteImage on _TodoHomePageState {
  // クリップボードの画像を base64 にして返す。画像が無ければ null。
  Future<String?> _pasteImageBase64FromClipboard() async {
    final bytes = await Pasteboard.image;
    if (bytes == null || bytes.isEmpty) return null;
    var converted = bytes;
    if (!kIsWeb) {
      // スクリーンショット等の大きなPNGをそのまま保存しないようJPEGに圧縮する
      try {
        final jpeg = await FlutterImageCompress.compressWithList(
          bytes,
          quality: 85,
          format: CompressFormat.jpeg,
        );
        if (jpeg.isNotEmpty) converted = jpeg;
      } catch (_) {
        // 変換に失敗しても元データで続行する
      }
    }
    return base64Encode(converted);
  }

  // 画像貼り付けの共通処理。クリップボードに画像があれば末尾に追加する。
  Future<void> _handlePasteImage({
    required List<String> imageBase64List,
    required ValueChanged<List<String>> onImagesChanged,
    required bool isProcessing,
    required ValueChanged<bool> onProcessingChanged,
  }) async {
    if (isProcessing) return;
    onProcessingChanged(true);
    try {
      final pasted = await _pasteImageBase64FromClipboard();
      if (pasted != null) {
        onImagesChanged([...imageBase64List, pasted]);
      } else if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('クリップボードに画像がありません')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('画像を貼り付けできませんでした')));
      }
    } finally {
      onProcessingChanged(false);
    }
  }

  // Ctrl+V / Cmd+V で画像を貼り付けられるようにするラッパー。
  // イベントは常に素通し（ignored）にするので、テキスト欄への通常の
  // テキスト貼り付けは今まで通り動く。
  Widget _buildImagePasteShortcut({
    required Future<void> Function() onPasteImage,
    required Widget child,
  }) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        final isPasteKey =
            event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.keyV &&
            (HardwareKeyboard.instance.isControlPressed ||
                HardwareKeyboard.instance.isMetaPressed);
        if (isPasteKey) {
          unawaited(_pasteImageUnlessTextPaste(onPasteImage));
        }
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }

  // テキスト欄にフォーカスがあり、クリップボードにテキストがある場合は
  // 通常のテキスト貼り付けを優先して何もしない。それ以外は画像を貼り付ける。
  Future<void> _pasteImageUnlessTextPaste(
    Future<void> Function() pasteImage,
  ) async {
    final inTextField =
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorStateOfType<EditableTextState>() !=
        null;
    if (inTextField) {
      try {
        final data = await Clipboard.getData(Clipboard.kTextPlain);
        if ((data?.text ?? '').isNotEmpty) return;
      } catch (_) {
        // クリップボードを読めない環境では何もしない
        return;
      }
    }
    await pasteImage();
  }
}
