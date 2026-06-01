part of '../../settings_page.dart';

extension _SettingsTagSection on _SettingsPageState {
  List<Widget> _buildTaskTagSection() {
    return [
      _buildSectionHeader('タグ'),
      _buildCard(
        children: [
          if (s.taskTags.isEmpty)
            ListTile(
              leading: Icon(Icons.label_outline, color: s.primaryColor),
              title: const Text('タグはまだありません'),
              subtitle: const Text(
                'タグを追加してタスクに付ける',
                overflow: TextOverflow.visible,
                softWrap: false,
                style: TextStyle(fontSize: 12),
              ),
            )
          else
            ...s.taskTags.map(_buildTaskTagTile),
          if (s.taskTags.isNotEmpty) _divider(),
          ListTile(
            leading: Icon(Icons.add, color: s.primaryColor),
            title: const Text('タグを追加'),
            trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
            onTap: () => _showTextEditDialog(
              title: 'タグを追加',
              currentValue: '',
              onSave: _addTaskTag,
            ),
          ),
        ],
      ),
    ];
  }

  Widget _buildTaskTagTile(String tag) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: Icon(Icons.label_outline, color: s.primaryColor),
          title: Text(tag),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.edit, color: s.accentColor),
                tooltip: 'タグ名を変更',
                onPressed: () => _showTextEditDialog(
                  title: 'タグ名を変更',
                  currentValue: tag,
                  onSave: (v) => _renameTaskTag(tag, v),
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: Colors.red.shade300),
                tooltip: 'タグを削除',
                onPressed: () => _confirmDeleteTaskTag(tag),
              ),
            ],
          ),
        ),
        if (tag != s.taskTags.last) _divider(),
      ],
    );
  }
}
