part of '../../settings_page.dart';

extension _SettingsInquirySection on _SettingsPageState {
  List<Widget> _buildInquirySection() {
    if (widget.onOpenInquiryForm == null) return const [];

    return [
      _buildSectionHeader('問い合わせ'),
      _buildCard(
        children: [
          ListTile(
            leading: Icon(Icons.mail_outline, color: s.accentOnSurface),
            title: const Text('問い合わせを送る'),
            subtitle: const Text(
              '不具合の報告や要望を送信できます\n（画像・PDFの添付に対応）',
              style: TextStyle(fontSize: 12),
            ),
            trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
            onTap: widget.onOpenInquiryForm,
          ),
          // 閲覧できるアカウントのときだけ一覧への導線を出す
          if (widget.onOpenInquiryList != null) ...[
            _divider(),
            ListTile(
              leading: Icon(Icons.inbox_outlined, color: s.accentOnSurface),
              title: const Text('届いた問い合わせ'),
              subtitle: const Text(
                '送信された問い合わせを確認できます',
                style: TextStyle(fontSize: 12),
              ),
              trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
              onTap: widget.onOpenInquiryList,
            ),
          ],
        ],
      ),
    ];
  }
}
