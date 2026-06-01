part of '../../settings_page.dart';

extension _SettingsBackupSection on _SettingsPageState {
  List<Widget> _buildBackupSection() {
    return [
      _buildSectionHeader('バックアップ'),
      _buildCard(
        children: [
          ListTile(
            leading: Icon(Icons.ios_share, color: s.primaryColor),
            title: const Text('タスクを書き出す'),
            subtitle: const Text(
              'タスクの内容とバックアップ用のJSONファイルをZIPで保存',
              style: TextStyle(fontSize: 12),
            ),
            trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
            onTap: widget.onExportTasks == null ? null : _showExportOptions,
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.file_download_outlined, color: s.primaryColor),
            title: const Text('タスクを復元する'),
            subtitle: const Text(
              '書き出したJSONファイルからタスクを取り込む',
              style: TextStyle(fontSize: 12),
            ),
            trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
            onTap: widget.onImportTasks,
          ),
        ],
      ),
    ];
  }

  Future<void> _showExportOptions() async {
    final completedOnly = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '書き出す範囲を選択',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.list_alt, color: s.primaryColor),
              title: const Text('全てのタスク'),
              onTap: () => Navigator.pop(sheetContext, false),
            ),
            ListTile(
              leading: Icon(Icons.check_circle_outline, color: s.primaryColor),
              title: const Text('完了済みタスクのみ'),
              onTap: () => Navigator.pop(sheetContext, true),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (completedOnly == null) return;
    await widget.onExportTasks?.call(completedOnly: completedOnly);
  }
}
