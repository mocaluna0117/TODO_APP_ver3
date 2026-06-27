part of '../../settings_page.dart';

extension _SettingsTagSection on _SettingsPageState {
  List<Widget> _buildTaskTagSection() {
    return [
      _buildSectionHeader('タグ（やること・今日やること用）'),
      _buildTagGroupCard(s.taskTags, isFuture: false),
      _buildSectionHeader('タグ（やりたいこと用）'),
      _buildTagGroupCard(s.futureTaskTags, isFuture: true),
    ];
  }

  Widget _buildTagGroupCard(List<String> tags, {required bool isFuture}) {
    return _buildCard(
      children: [
        if (tags.isEmpty)
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
          ...tags.map((tag) => _buildTaskTagTile(tag, tags, isFuture: isFuture)),
        if (tags.isNotEmpty) _divider(),
        ListTile(
          leading: Icon(Icons.add, color: s.primaryColor),
          title: const Text('タグを追加'),
          trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
          onTap: () => _showTextEditDialog(
            title: 'タグを追加',
            currentValue: '',
            onSave: (v) => _addTaskTag(v, isFuture: isFuture),
          ),
        ),
      ],
    );
  }

  Widget _buildTaskTagTile(
    String tag,
    List<String> tags, {
    required bool isFuture,
  }) {
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
                  onSave: (v) => _renameTaskTag(tag, v, isFuture: isFuture),
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: Colors.red.shade300),
                tooltip: 'タグを削除',
                onPressed: () =>
                    _confirmDeleteTaskTag(tag, isFuture: isFuture),
              ),
            ],
          ),
        ),
        if (tag != tags.last) _divider(),
      ],
    );
  }
}
