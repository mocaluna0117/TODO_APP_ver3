part of '../../../main.dart';

extension _TodoHomeBulkDeleteActions on _TodoHomePageState {
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
