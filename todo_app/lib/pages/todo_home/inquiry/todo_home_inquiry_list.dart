part of '../../../main.dart';

extension _TodoHomeInquiryList on _TodoHomePageState {
  // 問い合わせを閲覧できるアカウントか。
  // 実際の権限は Firestore のルール側で決まる（ここは表示の判定だけ）。
  bool get _canViewInquiries {
    final email = FirebaseAuth.instance.currentUser?.email?.toLowerCase();
    if (email == null) return false;
    return kInquiryAdminEmails.contains(email);
  }

  // 届いた問い合わせの一覧を開く
  Future<void> _openInquiryList() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => _buildInquiryListPage()),
    );
  }

  Widget _buildInquiryListPage() {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '届いた問い合わせ',
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
              stream: FirebaseFirestore.instance
                  .collection('inquiries')
                  .orderBy('createdAt', descending: true)
                  .limit(100)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _buildInquiryMessage(
                    Icons.error_outline,
                    '読み込めませんでした\n（閲覧権限がない可能性があります）',
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return _buildInquiryMessage(
                    Icons.inbox_outlined,
                    '問い合わせはありません',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    return _buildInquiryCard(
                      Inquiry.fromDoc(doc.id, doc.data()),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInquiryMessage(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: s.outlineColor),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildInquiryCard(Inquiry inquiry) {
    final createdAt = inquiry.createdAt;
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
                    inquiry.email.isEmpty ? '(不明)' : inquiry.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: s.accentOnSurface,
                    ),
                  ),
                ),
                Text(
                  createdAt == null
                      // サーバー側の時刻が入る前に届いた分
                      ? '送信中'
                      : DateFormat('yyyy/M/d HH:mm').format(createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: s.secondaryTextColor,
                  ),
                ),
              ],
            ),
            if (inquiry.message.isNotEmpty) ...[
              const SizedBox(height: 8),
              SelectableText(
                inquiry.message,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: s.primaryTextColor,
                ),
              ),
            ],
            for (final file in inquiry.files) ...[
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
