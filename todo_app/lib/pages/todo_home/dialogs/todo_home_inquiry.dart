part of '../../../main.dart';

// 問い合わせを閲覧できるアカウント（運営用）
const List<String> kInquiryAdminEmails = [
  'daibon20020117@gmail.com',
  'daibon0117.bin@gmail.com',
];

// 問い合わせに添付できる拡張子
const List<String> kInquiryFileExtensions = ['png', 'jpg', 'jpeg', 'pdf'];

extension _TodoHomeInquiry on _TodoHomePageState {
  bool get _isInquiryAdmin {
    final email = FirebaseAuth.instance.currentUser?.email?.toLowerCase();
    return email != null && kInquiryAdminEmails.contains(email);
  }

  CollectionReference<Map<String, dynamic>> get _inquiriesCollection =>
      FirebaseFirestore.instance.collection('inquiries');

  // ─────────────────────────────────────────────
  // 送信フォーム
  // ─────────────────────────────────────────────
  Future<void> _openInquiryForm() async {
    final controller = TextEditingController();
    final pending = <PendingTaskFile>[];
    var isSending = false;

    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => StatefulBuilder(
          builder: (context, refresh) {
            final canSend =
                !isSending &&
                (controller.text.trim().isNotEmpty || pending.isNotEmpty);

            Future<void> send() async {
              refresh(() => isSending = true);
              final sent = await _submitInquiry(
                message: controller.text.trim(),
                files: pending,
              );
              if (!mounted) return;
              if (sent) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('問い合わせを送信しました')),
                );
                return;
              }
              refresh(() => isSending = false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('送信できませんでした。通信状況を確認してください')),
              );
            }

            return Scaffold(
              appBar: AppBar(
                title: const Text(
                  'お問い合わせ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                centerTitle: true,
                backgroundColor: s.primaryColor,
                foregroundColor: Colors.white,
              ),
              body: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(
                          '不具合の報告や要望をお送りください。'
                          'スクリーンショット（png / jpg）やPDFを添付できます。',
                          style: TextStyle(
                            fontSize: 13,
                            color: s.secondaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: controller,
                          minLines: 5,
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          onChanged: (_) => refresh(() {}),
                          decoration: InputDecoration(
                            hintText: '内容を入力（添付だけでも送信できます）',
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
                        _buildInquiryAttachmentRow(pending, refresh),
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
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
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

  Widget _buildInquiryAttachmentRow(
    List<PendingTaskFile> pending,
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
          for (var i = 0; i < pending.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    _isPdfName(pending[i].name)
                        ? Icons.picture_as_pdf
                        : Icons.image_outlined,
                    size: 18,
                    color: s.accentOnSurface,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      pending[i].name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: s.primaryTextColor,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => refresh(() => pending.removeAt(i)),
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
            onTap: () => _pickInquiryFiles(pending, refresh),
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
                  Text(
                    pending.isEmpty
                        ? 'ファイルを添付（png / jpg / pdf）'
                        : 'ファイルを追加（${pending.length}件）',
                    style: TextStyle(
                      fontSize: 15,
                      color: pending.isEmpty ? Colors.grey : s.primaryTextColor,
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
    List<PendingTaskFile> pending,
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
    } catch (error, stackTrace) {
      debugPrint('Failed to pick inquiry file: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ファイルを選択できませんでした')));
      return;
    } finally {
      _isPickingBackup = false;
    }
    if (picked == null || picked.files.isEmpty) return;

    var hasTooLarge = false;
    final added = <PendingTaskFile>[];
    for (final file in picked.files) {
      final bytes = file.bytes;
      if (bytes == null) continue;
      if (bytes.length > kMaxAttachmentBytes) {
        hasTooLarge = true;
        continue;
      }
      added.add(PendingTaskFile(name: file.name, bytes: bytes));
    }
    if (added.isNotEmpty) refresh(() => pending.addAll(added));
    if (!mounted || !hasTooLarge) return;
    final limitMb = kMaxAttachmentBytes ~/ (1024 * 1024);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${limitMb}MBを超えるファイルは添付できません')),
    );
  }

  // 添付を Storage へ上げてから、問い合わせを1件作る。
  // 添付は本人のフォルダに置くので、既存のルールのままで書き込める。
  Future<bool> _submitInquiry({
    required String message,
    required List<PendingTaskFile> files,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    try {
      final uploaded = <Map<String, String>>[];
      for (var i = 0; i < files.length; i++) {
        final file = files[i];
        final ref = FirebaseStorage.instance.ref(
          'users/${user.uid}/inquiries/'
          '${DateTime.now().microsecondsSinceEpoch}_$i${_inquiryExtension(file.name)}',
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
        uploaded.add({'url': await ref.getDownloadURL(), 'name': file.name});
      }

      await _inquiriesCollection.add({
        'uid': user.uid,
        'email': user.email,
        'message': message,
        'files': uploaded,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (error, stackTrace) {
      debugPrint('Failed to send inquiry: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  String _inquiryExtension(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return '';
    return name.substring(dot).toLowerCase();
  }

  String _inquiryContentType(String name) {
    switch (_inquiryExtension(name)) {
      case '.pdf':
        return 'application/pdf';
      case '.png':
        return 'image/png';
      default:
        return 'image/jpeg';
    }
  }

  // ─────────────────────────────────────────────
  // 受信一覧（運営アカウントのみ）
  // ─────────────────────────────────────────────
  Future<void> _openInquiryList() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text(
              '受信した問い合わせ',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
            backgroundColor: s.primaryColor,
            foregroundColor: Colors.white,
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _inquiriesCollection
                      .orderBy('createdAt', descending: true)
                      .limit(200)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _buildInquiryListMessage(
                        Icons.error_outline,
                        '読み込めませんでした\n（閲覧できるアカウントか確認してください）',
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }
                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) {
                      return _buildInquiryListMessage(
                        Icons.inbox_outlined,
                        '問い合わせはまだありません',
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: docs.length,
                      itemBuilder: (context, index) =>
                          _buildInquiryCard(docs[index]),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInquiryListMessage(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: s.outlineColor),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildInquiryCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final message = (data['message'] ?? '').toString();
    final email = (data['email'] ?? '(不明)').toString();
    final createdAt = data['createdAt'];
    final sentAt = createdAt is Timestamp
        ? DateFormat('yyyy/M/d(E) HH:mm', 'ja').format(createdAt.toDate())
        : '送信日時なし';
    final files = taskFilesFromJson(data['files']);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: s.surfaceColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: s.primaryTextColor,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints.tightFor(
                    width: 34,
                    height: 34,
                  ),
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: Colors.red.shade300,
                  ),
                  tooltip: 'この問い合わせを削除',
                  onPressed: () => doc.reference.delete(),
                ),
              ],
            ),
            Text(
              sentAt,
              style: TextStyle(fontSize: 12, color: s.secondaryTextColor),
            ),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 10),
              SelectableText(
                message,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: s.primaryTextColor,
                ),
              ),
            ],
            for (final file in files) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _openLink(file.url),
                borderRadius: BorderRadius.circular(4),
                child: Row(
                  children: [
                    Icon(
                      _isPdfName(file.name)
                          ? Icons.picture_as_pdf
                          : Icons.image_outlined,
                      size: 16,
                      color: s.accentOnSurface,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        file.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: s.accentOnSurface,
                          decoration: TextDecoration.underline,
                          decorationColor: s.accentOnSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
