part of '../../../main.dart';

// 添付ファイル（画像・PDF）の置き場（Cloudflare Worker。attachment_store.dart）。
// アップロードと削除は、ログイン中の利用者の ID トークンで本人を確かめる。
// 読み出しの URL は毎回一意で中身が変わらないので、Worker が長期キャッシュを
// 指定して返す（2回目以降の表示でダウンロードが発生しない）。
final AttachmentStore _attachmentStore = AttachmentStore(
  baseUrl: attachmentApiBase,
  idToken: () async => FirebaseAuth.instance.currentUser?.getIdToken(),
);

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

  // 画像の先頭バイトから、アップロード時の Content-Type を判定する。
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
    const loadingWidget = Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );

    if (_isImageUrl(entry)) {
      // Web では cached_network_image を使わない。公式に「web は最小限の対応で
      // キャッシュは行わない」とされていてディスクキャッシュの利点が無く、
      // 一方で一度表示した画像を再表示すると黒く描画される不具合の報告がある
      // （スクロールで画面外に出て戻したときに再デコードが走るため）。
      // Web はブラウザのHTTPキャッシュが効くので Image.network で十分。
      if (kIsWeb) {
        return Image.network(
          entry,
          fit: fit,
          width: width,
          height: height,
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : loadingWidget,
          errorBuilder: (context, error, stackTrace) => errorWidget,
        );
      }
      return CachedNetworkImage(
        imageUrl: entry,
        fit: fit,
        width: width,
        height: height,
        placeholder: (context, url) => loadingWidget,
        errorWidget: (context, url, error) => errorWidget,
      );
    }

    final bytes = _decodeImage(entry);
    if (bytes == null) return errorWidget;
    return Image.memory(bytes, fit: fit, width: width, height: height);
  }

  // 保存していない画像・PDF が残っているか（残っていれば、そのタスクは
  // まだ Firestore へ書かない。base64 を Firestore に入れないため）。
  bool _hasPendingUploads(TodoItem item) =>
      item.pendingFiles.isNotEmpty ||
      item.imageBase64List.any((e) => e.isNotEmpty && !_isImageUrl(e));

  // 置き場に添付があるか（完全削除のときに、まとめて消す必要があるか）。
  bool _hasStoredAttachments(TodoItem item) =>
      item.imageBase64List.any(_attachmentStore.ownsUrl) ||
      item.attachments.any((file) => _attachmentStore.ownsUrl(file.url));

  // base64 の画像を置き場へアップロードし、1枚ずつ URL に置き換える。
  // 途中で失敗しても、送れた分は URL に置き換わっているので、次の保存では
  // 残りだけを送る（同じ画像を二重にアップロードしない）。
  Future<void> _uploadPendingImages(TodoItem item) async {
    final entries = [...item.imageBase64List];
    var i = 0;
    while (i < entries.length) {
      final entry = entries[i];
      if (_isImageUrl(entry)) {
        i++;
        continue;
      }
      final bytes = _decodeImage(entry);
      if (bytes == null) {
        // 空・不正なデータは捨てる
        entries.removeAt(i);
        item.imageBase64List = [...entries];
        continue;
      }
      final url = await _attachmentStore.upload(
        folder: 'todos/${item.id}',
        bytes: bytes,
        contentType: _detectImageContentType(bytes),
      );
      // アップロード直後にキャッシュへ先読みしておく。
      // これで表示切り替え時に読み込み待ちが起きず、「アップロード中」表示も
      // ネット読み込み完了まで出し続けられる。
      if (mounted) {
        await precacheImage(
          // 表示に使うのと同じプロバイダで先読みしないとキャッシュが効かない
          kIsWeb ? NetworkImage(url) : CachedNetworkImageProvider(url),
          context,
          onError: (error, stackTrace) {},
        );
      }
      entries[i] = url;
      item.imageBase64List = [...entries];
      i++;
    }
  }

  // 添付ファイル（PDF）を置き場へアップロードし、1件ずつ attachments へ移す。
  // 画像と同じくタスクのフォルダに置くので、タスク削除時にまとめて消える。
  Future<void> _uploadPendingFiles(TodoItem item) async {
    while (item.pendingFiles.isNotEmpty) {
      final pending = item.pendingFiles.first;
      final url = await _attachmentStore.upload(
        folder: 'todos/${item.id}',
        bytes: pending.bytes,
        contentType: 'application/pdf',
        // ブラウザで開いたときに元のファイル名で見えるようにする
        fileName: pending.name,
      );
      item.attachments = [
        ...item.attachments,
        TaskFile(url: url, name: pending.name),
      ];
      item.pendingFiles = item.pendingFiles.sublist(1);
    }
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

  // 置き場のファイルを読み込む（タスク複製で実体をコピーするために使う）。
  // 失敗しても致命的ではないので null を返して呼び出し側に任せる。
  Future<Uint8List?> _downloadStorageFile(String url) async {
    try {
      return await _attachmentStore.download(
        url,
        maxBytes: kMaxAttachmentBytes,
      );
    } catch (error) {
      debugPrint('Failed to read attachment for copy: $error');
      return null;
    }
  }

  // タスクの添付（画像・PDF）を置き場からすべて削除する（フォルダごと）。
  // 失敗しても致命的ではない（孤立ファイルが残るだけ）ので握りつぶす。
  Future<void> _deleteTaskImages(int itemId) async {
    if (FirebaseAuth.instance.currentUser == null) return;
    try {
      await _attachmentStore.deleteTaskFolder(itemId);
    } catch (_) {}
  }

  // 指定したURLのファイルを置き場から削除する（編集で外された添付用）。
  // 旧 Firebase Storage の URL など、この置き場のものでなければ何もしない。
  Future<void> _deleteStorageFilesByUrls(Iterable<String> urls) async {
    for (final url in urls) {
      try {
        await _attachmentStore.deleteUrl(url);
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
