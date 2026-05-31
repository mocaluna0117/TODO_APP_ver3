part of '../../settings_page.dart';

extension _SettingsAppTitleSection on _SettingsPageState {
  List<Widget> _buildAppTitleSection() {
    return [
      _buildSectionHeader('アプリ名'),
      _buildCard(
        children: [
          ListTile(
            leading: Icon(Icons.title, color: s.primaryColor),
            title: const Text('アプリタイトル'),
            subtitle: Text(s.appTitle),
            trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
            onTap: () => _showTextEditDialog(
              title: 'アプリタイトルを変更',
              currentValue: s.appTitle,
              onSave: (v) {
                s.appTitle = v;
                _notify();
              },
            ),
          ),
        ],
      ),
    ];
  }
}
