part of '../../settings_page.dart';

extension _SettingsTagActions on _SettingsPageState {
  void _showDuplicateTagMessage(String tag) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('「$tag」はすでにあります')));
  }

  List<String> _tagListFor(bool isFuture) =>
      isFuture ? s.futureTaskTags : s.taskTags;

  // タグの並び順を入れ替える。この順番がタスク一覧の絞り込みチップや、
  // タスク編集時のタグ選択肢の並びにそのまま使われる。
  void _reorderTaskTags(
    int oldIndex,
    int newIndex, {
    required bool isFuture,
  }) {
    final tags = _tagListFor(isFuture);
    if (oldIndex < 0 || oldIndex >= tags.length) return;
    final moved = tags.removeAt(oldIndex);
    tags.insert(newIndex.clamp(0, tags.length), moved);
    _notify();
  }

  void _addTaskTag(String tag, {required bool isFuture}) {
    final tags = _tagListFor(isFuture);
    if (tags.contains(tag)) {
      _showDuplicateTagMessage(tag);
      return;
    }
    tags.add(tag);
    _notify();
  }

  void _renameTaskTag(String oldTag, String newTag, {required bool isFuture}) {
    if (oldTag == newTag) return;
    final tags = _tagListFor(isFuture);
    if (tags.contains(newTag)) {
      _showDuplicateTagMessage(newTag);
      return;
    }
    final index = tags.indexOf(oldTag);
    if (index == -1) return;
    tags[index] = newTag;
    widget.onTaskTagRenamed?.call(oldTag, newTag, isFuture: isFuture);
    _notify();
  }

  Future<void> _confirmDeleteTaskTag(String tag, {required bool isFuture}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'タグを削除',
          style: TextStyle(color: s.primaryColor, fontWeight: FontWeight.bold),
        ),
        content: Text('「$tag」を削除しますか？\nこのタグが付いたタスクはタグなしになります。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text(
              '削除',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (result != true) return;

    _tagListFor(isFuture).remove(tag);
    widget.onTaskTagDeleted?.call(tag, isFuture: isFuture);
    _notify();
  }
}
