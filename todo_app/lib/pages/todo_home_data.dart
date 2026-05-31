part of '../main.dart';

extension _TodoHomeData on _TodoHomePageState {
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? itemsJson = prefs.getString('todo_items');
    if (itemsJson != null) {
      final List<dynamic> decodedList = jsonDecode(itemsJson);
      _updateState(() {
        _allItems.clear();
        _allItems.addAll(decodedList.map((e) => TodoItem.fromJson(e)).toList());
        _removeUnknownTaskTags();
      });
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
