part of '../../../main.dart';

extension _TodoHomeBulkDeleteActions on _TodoHomePageState {
  void _deleteAllTasks() {
    if (_allItems.isEmpty && s.taskTags.isEmpty && s.futureTaskTags.isEmpty) {
      return;
    }

    final itemIds = _allItems.map((item) => item.id).toList();
    // 画像を持つタスクのIDを控えておき、Storageの画像も削除する
    final imageItemIds = _allItems
        .where((item) => item.imageBase64List.any(_isImageUrl))
        .map((item) => item.id)
        .toList();
    _updateState(() {
      _allItems.clear();
      _fadingOutItems.clear();
      // 両グループのタグも全て削除し、フィルタを「すべて」に戻す
      s.taskTags.clear();
      s.futureTaskTags.clear();
      _selectedTaskTagFilter = allTaskCategoriesLabel;
      _selectedFutureTaskTagFilter = allTaskCategoriesLabel;
    });
    _saveData();
    s.saveToPrefs();
    widget.onSettingsChanged();

    for (final id in imageItemIds) {
      _deleteTaskImages(id);
    }
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

    for (final item in items.where(
      (item) => item.imageBase64List.any(_isImageUrl),
    )) {
      _deleteTaskImages(item.id);
    }
    for (final item in items.where((item) => !item.isDone)) {
      NotificationService().cancelNotification(item.id);
    }
  }
}
