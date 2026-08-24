part of '../../settings_page.dart';

extension _SettingsTagSection on _SettingsPageState {
  List<Widget> _buildTaskTagSection() {
    return [
      _buildSectionHeader('タグ（やること・今日やること・明日やること用）'),
      _buildTagGroupCard(s.taskTags, isFuture: false),
      _buildSectionHeader('タグ（やりたいこと用）'),
      _buildTagGroupCard(s.futureTaskTags, isFuture: true),
    ];
  }

  // 並び替えの説明。タグが2つ以上あるときだけ出す。
  Widget _buildTagReorderHint() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Text(
        '右の ≡ をドラッグすると並び順を変えられます。'
        'この順番が絞り込みチップとタグの選択肢に反映されます。',
        style: TextStyle(fontSize: 12, color: Colors.grey),
      ),
    );
  }

  Widget _buildTagGroupCard(List<String> tags, {required bool isFuture}) {
    return _buildCard(
      children: [
        if (tags.isEmpty)
          ListTile(
            leading: Icon(Icons.label_outline, color: s.accentOnSurface),
            title: const Text('タグはまだありません'),
            subtitle: const Text(
              'タグを追加してタスクに付ける',
              overflow: TextOverflow.visible,
              softWrap: false,
              style: TextStyle(fontSize: 12),
            ),
          )
        else ...[
          if (tags.length > 1) ...[_buildTagReorderHint(), _divider()],
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            // 行に編集・削除ボタンがあるため、専用のつまみで並び替える
            buildDefaultDragHandles: false,
            onReorderItem: (oldIndex, newIndex) =>
                _reorderTaskTags(oldIndex, newIndex, isFuture: isFuture),
            children: [
              for (var i = 0; i < tags.length; i++)
                _buildTaskTagTile(tags[i], tags, i, isFuture: isFuture),
            ],
          ),
        ],
        if (tags.isNotEmpty) _divider(),
        ListTile(
          leading: Icon(Icons.add, color: s.accentOnSurface),
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
    List<String> tags,
    int index, {
    required bool isFuture,
  }) {
    return Column(
      key: ValueKey('${isFuture ? 'future' : 'main'}-$tag'),
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: Icon(Icons.label_outline, color: s.accentOnSurface),
          title: Text(tag, overflow: TextOverflow.ellipsis),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.edit, color: s.accentColor),
                visualDensity: VisualDensity.compact,
                tooltip: 'タグ名を変更',
                onPressed: () => _showTextEditDialog(
                  title: 'タグ名を変更',
                  currentValue: tag,
                  onSave: (v) => _renameTaskTag(tag, v, isFuture: isFuture),
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: Colors.red.shade300),
                visualDensity: VisualDensity.compact,
                tooltip: 'タグを削除',
                onPressed: () =>
                    _confirmDeleteTaskTag(tag, isFuture: isFuture),
              ),
              if (tags.length > 1)
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 12,
                    ),
                    child: Icon(
                      Icons.drag_handle,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (tag != tags.last) _divider(),
      ],
    );
  }
}
