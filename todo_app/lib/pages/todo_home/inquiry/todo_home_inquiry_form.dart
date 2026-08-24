part of '../../../main.dart';

extension _TodoHomeInquiryForm on _TodoHomePageState {
  // 問い合わせの送信画面を開く
  Future<void> _openInquiryForm() async {
    final controller = TextEditingController();
    final files = <PendingTaskFile>[];
    var isSending = false;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StatefulBuilder(
          builder: (context, refresh) {
            // 文章が空でも、添付が1つでもあれば送れる
            final canSend =
                !isSending &&
                (controller.text.trim().isNotEmpty || files.isNotEmpty);

            Future<void> send() async {
              refresh(() => isSending = true);
              // 送信の待ち時間をまたぐので、必要なものは先に取っておく
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              final sent = await _sendInquiry(
                message: controller.text.trim(),
                files: files,
              );
              if (!context.mounted) return;
              if (sent) {
                navigator.pop();
                messenger.showSnackBar(
                  const SnackBar(content: Text('問い合わせを送信しました')),
                );
                return;
              }
              refresh(() => isSending = false);
              messenger.showSnackBar(
                const SnackBar(content: Text('送信できませんでした。通信状況を確認してください')),
              );
            }

            return Scaffold(
              appBar: AppBar(
                title: const Text(
                  '問い合わせ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                centerTitle: true,
                backgroundColor: s.primaryColor,
                foregroundColor: Colors.white,
              ),
              body: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(
                          '不具合の報告や要望をお送りください。\n'
                          '画像（png / jpg）と PDF を添付できます。'
                          '文章が空でも、添付が1つあれば送信できます。',
                          style: TextStyle(
                            fontSize: 13,
                            color: s.secondaryTextColor,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: controller,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          minLines: 5,
                          maxLines: null,
                          onChanged: (_) => refresh(() {}),
                          decoration: InputDecoration(
                            hintText: '内容を入力（任意）',
                            filled: true,
                            fillColor: s.fieldColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.all(16),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildInquiryFileRow(files, refresh),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: canSend ? send : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: s.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: isSending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  '送信',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    controller.dispose();
  }

  Widget _buildInquiryFileRow(
    List<PendingTaskFile> files,
    StateSetter refresh,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: s.fieldColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < files.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    _isPdfName(files[i].name)
                        ? Icons.picture_as_pdf
                        : Icons.image_outlined,
                    size: 18,
                    color: s.accentOnSurface,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      files[i].name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: s.primaryTextColor,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => refresh(() => files.removeAt(i)),
                    child: Icon(
                      Icons.close,
                      size: 18,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
          InkWell(
            onTap: () => _pickInquiryFiles(files, refresh),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.attach_file,
                    size: 20,
                    color: s.accentOnSurface,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      files.isEmpty
                          ? 'ファイルを添付（png / jpg / pdf）'
                          : 'ファイルを追加（${files.length}件）',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        color: files.isEmpty ? Colors.grey : s.primaryTextColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isPdfName(String name) => name.toLowerCase().endsWith('.pdf');

  Future<void> _pickInquiryFiles(
    List<PendingTaskFile> files,
    StateSetter refresh,
  ) async {
    // 他のファイル選択と同時に開くと PlatformException(multiple_request) になる
    if (_isPickingBackup) return;
    _isPickingBackup = true;
    final FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: kInquiryFileExtensions,
        allowMultiple: true,
        withData: true,
      );
    } catch (error) {
      debugPrint('Failed to pick inquiry file: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ファイルを選択できませんでした')));
      return;
    } finally {
      _isPickingBackup = false;
    }
    if (picked == null || picked.files.isEmpty) return;

    final added = <PendingTaskFile>[];
    var hasTooLarge = false;
    for (final file in picked.files) {
      final bytes = file.bytes;
      if (bytes == null) continue;
      if (bytes.length > kMaxAttachmentBytes) {
        hasTooLarge = true;
        continue;
      }
      added.add(PendingTaskFile(name: file.name, bytes: bytes));
    }
    refresh(() => files.addAll(added));
    if (!mounted || !hasTooLarge) return;
    final limitMb = kMaxAttachmentBytes ~/ (1024 * 1024);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${limitMb}MBを超えるファイルは添付できません')),
    );
  }

  // 添付を Storage へ上げてから、問い合わせを Firestore に登録する。
  // 添付は自分のフォルダ配下に置くので、既存のルールのままで書き込める
  // （閲覧側はダウンロードURLで開く）。
  Future<bool> _sendInquiry({
    required String message,
    required List<PendingTaskFile> files,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    try {
      final uploaded = <TaskFile>[];
      for (var i = 0; i < files.length; i++) {
        final file = files[i];
        final ref = FirebaseStorage.instance.ref(
          'users/${user.uid}/inquiries/'
          '${DateTime.now().microsecondsSinceEpoch}_$i${_extensionOf(file.name)}',
        );
        await ref.putData(
          file.bytes,
          SettableMetadata(
            contentType: _inquiryContentType(file.name),
            cacheControl: kAttachmentCacheControl,
            contentDisposition:
                'inline; filename="${file.name.replaceAll('"', '')}"',
          ),
        );
        uploaded.add(
          TaskFile(url: await ref.getDownloadURL(), name: file.name),
        );
      }

      await FirebaseFirestore.instance.collection('inquiries').add({
        'uid': user.uid,
        'email': user.email ?? '',
        'message': message,
        'files': uploaded.map((file) => file.toJson()).toList(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (error, stackTrace) {
      debugPrint('Failed to send inquiry: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  String _extensionOf(String name) {
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot).toLowerCase();
  }

  String _inquiryContentType(String name) {
    final extension = _extensionOf(name);
    switch (extension) {
      case '.pdf':
        return 'application/pdf';
      case '.png':
        return 'image/png';
      default:
        return 'image/jpeg';
    }
  }
}
