part of '../../../../main.dart';

extension _TodoHomeAddTaskTagDialog on _TodoHomePageState {
  void _showAddTaskTagDialog(String category) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'タグを追加',
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
            if (_addTaskTagFromHome(controller.text, category)) {
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
              if (_addTaskTagFromHome(controller.text, category)) {
                Navigator.pop(context);
              }
            },
            child: Text(
              '追加',
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

  bool _addTaskTagFromHome(String value, String category) {
    final tag = normalizeTaskTag(value);
    if (tag == null) return false;
    final groupTags = s.tagsForCategory(category);
    if (groupTags.contains(tag)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('「$tag」はすでにあります')));
      return false;
    }
    _updateState(() {
      groupTags.add(tag);
      _setSelectedTagFilter(category, tag);
    });
    s.saveToPrefs();
    widget.onSettingsChanged();
    return true;
  }
}
