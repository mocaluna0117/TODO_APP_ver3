part of '../../settings_page.dart';

extension _SettingsBackupSection on _SettingsPageState {
  List<Widget> _buildBackupSection() {
    return [
      _buildSectionHeader('バックアップ'),
      _buildCard(
        children: [
          ListTile(
            leading: Icon(Icons.ios_share, color: s.primaryColor),
            title: const Text('完了済みタスクを書き出す'),
            subtitle: const Text('テキストファイルと復元用JSONをZIPで保存'),
            trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
            onTap: widget.onExportCompletedTasks,
          ),
        ],
      ),
    ];
  }
}
