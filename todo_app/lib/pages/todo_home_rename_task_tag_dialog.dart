part of '../main.dart';

extension _TodoHomeRenameTaskTagDialog on _TodoHomePageState {
  void _showRenameTaskTagDialog(String oldTag) {
    final controller = TextEditingController(text: oldTag);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'タグ名を変更',
          style: TextStyle(color: s.primaryColor, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          hintLocales: const [Locale('ja', 'JP')],
          decoration: InputDecoration(
            hintText: 'タグ名',
            filled: true,
            fillColor: const Color(0xFFF5F5FA),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (_) {
            if (_renameTaskTagFromHome(oldTag, controller.text)) {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              if (_renameTaskTagFromHome(oldTag, controller.text)) {
                Navigator.pop(context);
              }
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

  bool _renameTaskTagFromHome(String oldTag, String value) {
    final newTag = normalizeTaskTag(value);
    if (newTag == null) return false;
    if (newTag == oldTag) return true;
    if (s.taskTags.contains(newTag)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('「$newTag」はすでにあります')));
      return false;
    }

    final index = s.taskTags.indexOf(oldTag);
    if (index == -1) return false;
    s.taskTags[index] = newTag;
    _renameTaskTag(oldTag, newTag);
    s.saveToPrefs();
    widget.onSettingsChanged();
    return true;
  }
}
