part of '../main.dart';

extension _TodoHomeDeleteTaskTagDialog on _TodoHomePageState {
  Future<void> _confirmDeleteTaskTagFromHome(String tag) async {
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

    s.taskTags.remove(tag);
    _deleteTaskTag(tag);
    s.saveToPrefs();
    widget.onSettingsChanged();
  }
}
