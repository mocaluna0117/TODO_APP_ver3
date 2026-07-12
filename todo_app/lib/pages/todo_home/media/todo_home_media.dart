part of '../../../main.dart';

extension _TodoHomeMedia on _TodoHomePageState {
  Future<List<String>> _pickImageBase64List() async {
    final pickedImages = await _imagePicker.pickMultiImage(
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (pickedImages.isEmpty) return [];

    final encodedImages = <String>[];
    for (final pickedImage in pickedImages) {
      final bytes = await pickedImage.readAsBytes();
      encodedImages.add(base64Encode(bytes));
    }
    return encodedImages;
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
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      result.add(await ref.getDownloadURL());
    }
    return result;
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
