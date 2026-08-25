part of '../../settings_page.dart';

extension _SettingsInquirySection on _SettingsPageState {
  List<Widget> _buildInquirySection() {
    // 送信はAppBarのアイコンから行うので、ここには一覧だけを置く。
    // 閲覧できるアカウント以外にはセクションごと出さない。
    if (widget.onOpenInquiryList == null) return const [];

    return [
      _buildSectionHeader('問い合わせ'),
      _buildCard(
        children: [
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
      ),
    ];
  }
}
