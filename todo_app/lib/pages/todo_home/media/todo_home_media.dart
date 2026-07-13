part of '../../../main.dart';

extension _TodoHomeMedia on _TodoHomePageState {
  Future<List<String>> _pickImageBase64List() async {
    final pickedImages = await _imagePicker.pickMultiImage(
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (pickedImages.isEmpty) return [];

    final encodedImages = <String>[];
    var rejectedHeic = false;
    for (final pickedImage in pickedImages) {
      var bytes = await pickedImage.readAsBytes();
      if (kIsWeb) {
        // WebブラウザはHEICを直接デコードできないため、heic2any(JS)でJPEGに変換
        final name = pickedImage.name.toLowerCase();
        final mime = (pickedImage.mimeType ?? '').toLowerCase();
        final isHeic =
            name.endsWith('.heic') ||
            name.endsWith('.heif') ||
            mime.contains('heic') ||
            mime.contains('heif');
        if (isHeic) {
          final converted = await convertHeicToJpeg(bytes);
          if (converted == null) {
            rejectedHeic = true;
            continue;
          }
          bytes = converted;
        }
      } else {
        // HEIC等をどこでも表示できるJPEGに変換する（iOS/Android）
        try {
          final jpeg = await FlutterImageCompress.compressWithList(
            bytes,
            quality: 85,
            format: CompressFormat.jpeg,
          );
          if (jpeg.isNotEmpty) bytes = jpeg;
        } catch (_) {
          // 変換に失敗しても元データで続行する
        }
      }
      encodedImages.add(base64Encode(bytes));
    }
    if (rejectedHeic && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('HEIC画像の変換に失敗したため除外しました（JPEG/PNG等をご利用ください）'),
        ),
      );
    }
    return encodedImages;
  }

  // 画像の先頭バイトから Storage 用の Content-Type を判定する。
  String _detectImageContentType(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 6 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46) {
      return 'image/gif';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }

  Uint8List? _decodeImage(String? imageBase64) {
    if (imageBase64 == null || imageBase64.isEmpty) return null;
    try {
      return base64Decode(imageBase64);
    } on FormatException {
      return null;
    }
  }

  // 画像エントリは base64 文字列 または https の画像URL のどちらか。
  bool _isImageUrl(String entry) => entry.startsWith('http');

  bool _isValidImageEntry(String entry) {
    if (entry.isEmpty) return false;
    if (_isImageUrl(entry)) return true;
    return _decodeImage(entry) != null;
  }

  // 表示可能な画像エントリ（base64 or URL）だけを返す。
  List<String> _validImageEntries(List<String> entries) =>
      entries.where(_isValidImageEntry).toList(growable: false);

  // 画像1枚の表示ウィジェット。
  // URLはディスクキャッシュ（cached_network_image）で表示し、一度読み込めば
  // オフラインでも表示できる。base64はそのままデコードして表示する。
  Widget _buildImage(
    String entry, {
    BoxFit fit = BoxFit.contain,
    double? width,
    double? height,
  }) {
    const errorWidget = Center(
      child: Icon(Icons.broken_image, color: Colors.grey),
    );

    if (_isImageUrl(entry)) {
      return CachedNetworkImage(
        imageUrl: entry,
        fit: fit,
        width: width,
        height: height,
        placeholder: (context, url) => const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        errorWidget: (context, url, error) => errorWidget,
      );
    }

    final bytes = _decodeImage(entry);
    if (bytes == null) return errorWidget;
    return Image.memory(bytes, fit: fit, width: width, height: height);
  }

  // base64 の画像を Firebase Storage にアップロードして URL に置き換えたリストを返す。
  // 既に URL のものはそのまま。変更が無ければ元のリストをそのまま返す。
  Future<List<String>> _uploadPendingImages(TodoItem item) async {
    final entries = item.imageBase64List;
    // すべて URL（または空）なら何もしない
    if (entries.every((e) => e.isEmpty || _isImageUrl(e))) return entries;

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final result = <String>[];
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      if (_isImageUrl(entry)) {
        result.add(entry);
        continue;
      }
      final bytes = _decodeImage(entry);
      if (bytes == null) continue; // 不正なデータはスキップ
      final ref = FirebaseStorage.instance.ref(
        'users/$uid/todos/${item.id}/'
        '${DateTime.now().microsecondsSinceEpoch}_$i.jpg',
      );
      await ref.putData(
        bytes,
        SettableMetadata(contentType: _detectImageContentType(bytes)),
      );
      final url = await ref.getDownloadURL();
      // アップロード直後にキャッシュへ先読みしておく。
      // これで表示切り替え時に読み込み待ちが起きず、「アップロード中」表示も
      // ネット読み込み完了まで出し続けられる。
      if (mounted) {
        await precacheImage(
          CachedNetworkImageProvider(url),
          context,
          onError: (error, stackTrace) {},
        );
      }
      result.add(url);
    }
    return result;
  }

  // 画像アップロード中に画像へ重ねる半透明オーバーレイ。
  Widget _buildImageUploadingOverlay() {
    return Container(
      color: Colors.black45,
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'アップロード中...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // タスクの画像ファイルを Storage からすべて削除する（フォルダごと）。
  // 失敗しても致命的ではない（孤立ファイルが残るだけ）ので握りつぶす。
  Future<void> _deleteTaskImages(int itemId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final folder = FirebaseStorage.instance.ref('users/$uid/todos/$itemId');
      final list = await folder.listAll();
      await Future.wait(list.items.map((ref) => ref.delete()));
    } catch (_) {}
  }

  // 指定した画像URLのファイルを Storage から削除する（編集で外された画像用）。
  Future<void> _deleteImagesByUrls(Iterable<String> urls) async {
    for (final url in urls) {
      if (!_isImageUrl(url)) continue;
      try {
        await FirebaseStorage.instance.refFromURL(url).delete();
      } catch (_) {}
    }
  }

  void _showImagePreview(
    List<String> entries, {
    int initialIndex = 0,
  }) {
    if (entries.isEmpty) return;
    final pageController = PageController(initialPage: initialIndex);
    var currentIndex = initialIndex;

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => StatefulBuilder(
        builder: (context, setPreviewState) {
          return Dialog.fullscreen(
            backgroundColor: Colors.black,
            child: SafeArea(
              child: Dismissible(
                key: const ValueKey('image-preview'),
                direction: DismissDirection.vertical,
                onDismissed: (_) => Navigator.pop(context),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.pop(context),
                        child: PageView.builder(
                          controller: pageController,
                          itemCount: entries.length,
                          onPageChanged: (index) {
                            currentIndex = index;
                            setPreviewState(() {});
                          },
                          itemBuilder: (context, index) {
                            return Center(
                              child: InteractiveViewer(
                                minScale: 0.8,
                                maxScale: 4,
                                child: GestureDetector(
                                  onTap: () {},
                                  child: _buildImage(
                                    entries[index],
                                    fit: BoxFit.contain,
                                    width: double.infinity,
                                    height: double.infinity,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    if (entries.length > 1)
                      Positioned(
                        top: 16,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Text(
                              '${currentIndex + 1}/${entries.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          tooltip: '閉じる',
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 20,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: s.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                            side: const BorderSide(color: Colors.white24),
                          ),
                          elevation: 4,
                        ),
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.keyboard_arrow_down),
                        label: const Text('閉じる'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
