part of '../../settings_page.dart';

extension _SettingsInquirySection on _SettingsPageState {
  List<Widget> _buildInquirySection() {
    final openForm = widget.onOpenInquiryForm;
    if (openForm == null) return const [];

    return [
      _buildSectionHeader('お問い合わせ'),
      _buildCard(
        children: [
          ListTile(
            leading: Icon(Icons.mail_outline, color: s.accentOnSurface),
            title: const Text('問い合わせを送る'),
            subtitle: const Text(
              '不具合の報告や要望を送れます（png / jpg / pdf を添付可）',
              style: TextStyle(fontSize: 12),
            ),
            trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
            onTap: openForm,
          ),
          // 受信一覧は閲覧できるアカウントにだけ出す
          if (widget.onOpenInquiryList != null) ...[
            _divider(),
            ListTile(
              leading: Icon(Icons.inbox_outlined, color: s.accentOnSurface),
              title: const Text('受信した問い合わせ'),
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
