part of '../settings_page.dart';

extension _SettingsActions on _SettingsPageState {
  void _showDuplicateTagMessage(String tag) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('「$tag」はすでにあります')));
  }

  void _addTaskTag(String tag) {
    if (s.taskTags.contains(tag)) {
      _showDuplicateTagMessage(tag);
      return;
    }
    s.taskTags.add(tag);
    _notify();
  }

  void _renameTaskTag(String oldTag, String newTag) {
    if (oldTag == newTag) return;
    if (s.taskTags.contains(newTag)) {
      _showDuplicateTagMessage(newTag);
      return;
    }
    final index = s.taskTags.indexOf(oldTag);
    if (index == -1) return;
    s.taskTags[index] = newTag;
    widget.onTaskTagRenamed?.call(oldTag, newTag);
    _notify();
  }

  Future<void> _confirmDeleteTaskTag(String tag) async {
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
    widget.onTaskTagDeleted?.call(tag);
    _notify();
  }

  // ─── テキスト編集用ダイアログ ───
  void _showTextEditDialog({
    required String title,
    required String currentValue,
    required ValueChanged<String> onSave,
  }) {
    final controller = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: TextStyle(color: s.primaryColor, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF5F5FA),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) {
              onSave(v.trim());
            }
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              final v = controller.text.trim();
              if (v.isNotEmpty) {
                onSave(v);
              }
              Navigator.pop(context);
            },
            child: Text(
              '保存',
              style: TextStyle(
                color: s.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
