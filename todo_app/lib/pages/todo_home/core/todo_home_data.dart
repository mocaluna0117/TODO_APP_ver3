part of '../../../main.dart';

extension _TodoHomeData on _TodoHomePageState {
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? itemsJson = prefs.getString('todo_items');
    if (itemsJson != null) {
      final List<dynamic> decodedList = jsonDecode(itemsJson);
      // タグをグループ分離した初回のみ、既存の「やりたいこと」タスクが持つタグを
      // futureTaskTags に取り込む（_removeUnknownTaskTags より前に行う）。
      final needsFutureTagMigration = !prefs.containsKey('futureTaskTags');
      _updateState(() {
        _allItems.clear();
        _allItems.addAll(decodedList.map((e) => TodoItem.fromJson(e)).toList());
        if (needsFutureTagMigration) {
          for (final item in _allItems) {
            final tag = item.taskTag;
            if (item.category == 'future' &&
                tag != null &&
                !s.futureTaskTags.contains(tag)) {
              s.futureTaskTags.add(tag);
            }
          }
        }
        _removeUnknownTaskTags();
      });
      if (needsFutureTagMigration) {
        await s.saveToPrefs();
      }
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final String itemsJson = jsonEncode(
      _allItems.map((e) => e.toJson()).toList(),
    );
    await prefs.setString('todo_items', itemsJson);
  }
}
