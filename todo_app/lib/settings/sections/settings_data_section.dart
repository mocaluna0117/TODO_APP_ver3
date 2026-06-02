part of '../../settings_page.dart';

extension _SettingsDataSection on _SettingsPageState {
  List<Widget> _buildDataSection() {
    return [
      _buildSectionHeader('データ管理'),
      _buildCard(
        children: [
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text(
              '全てのタスクを削除',
              style: TextStyle(color: Colors.red),
            ),
            subtitle: const Text(
              'すべてのタスクを完全に削除\n（復元できません）',
              style: TextStyle(fontSize: 12),
            ),
            trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
            onTap: widget.onDeleteAllTasks == null
                ? null
                : _confirmDeleteAllTasks,
          ),
        ],
      ),
    ];
  }

  Future<void> _confirmDeleteAllTasks() async {
    // 1段階目の確認
    final firstConfirmed = await _showDeleteAllDialog(
      message: 'すべてのタスクを完全に削除します。\nこの操作は取り消せません。本当によろしいですか？',
      confirmLabel: '削除する',
    );
    if (firstConfirmed != true || !mounted) return;

    // 2段階目（最終）の確認
    final finalConfirmed = await _showDeleteAllDialog(
      message: '【最終確認】\n本当にすべてのタスクを削除します。\nこの操作は元に戻せません。',
      confirmLabel: '完全に削除',
    );
    if (finalConfirmed != true) return;

    widget.onDeleteAllTasks?.call();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('全てのタスクを削除しました')));
  }

  Future<bool?> _showDeleteAllDialog({
    required String message,
    required String confirmLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '全てのタスクを削除',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 15, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'キャンセル',
              style: TextStyle(color: Colors.grey, fontSize: 15),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(
              confirmLabel,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}
