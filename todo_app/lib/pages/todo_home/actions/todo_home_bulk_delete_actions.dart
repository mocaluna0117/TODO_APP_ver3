part of '../../../main.dart';

extension _TodoHomeBulkDeleteActions on _TodoHomePageState {
  void _deleteAllTasks() {
    if (_allItems.isEmpty && s.taskTags.isEmpty) return;

    final itemIds = _allItems.map((item) => item.id).toList();
    _updateState(() {
      _allItems.clear();
      _fadingOutItems.clear();
      // タグも全て削除し、フィルタを「すべて」に戻す
      s.taskTags.clear();
      _selectedTaskTagFilter = allTaskCategoriesLabel;
    });
    _saveData();
    s.saveToPrefs();
    widget.onSettingsChanged();

    for (final id in itemIds) {
      NotificationService().cancelNotification(id);
    }
  }

  void _deleteCompletedItems(List<TodoItem> items) {
    if (items.isEmpty) return;

    final itemIds = items.map((item) => item.id).toSet();
    _updateState(() {
      _allItems.removeWhere((item) => itemIds.contains(item.id));
    });
    _saveData();

    for (final item in items.where((item) => !item.isDone)) {
      NotificationService().cancelNotification(item.id);
    }
  }
}
