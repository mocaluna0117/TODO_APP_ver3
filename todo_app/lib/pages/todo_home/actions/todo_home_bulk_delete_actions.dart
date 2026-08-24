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

  // 完了済みの一括削除もゴミ箱へ移す（誤操作から戻せるようにする）
  void _deleteCompletedItems(List<TodoItem> items) {
    if (items.isEmpty) return;

    final deletedAt = DateTime.now();
    _updateState(() {
      for (final item in items) {
        item.deletedAt = deletedAt;
      }
    });
    _saveData();

    for (final item in items) {
      NotificationService().cancelNotification(item.id);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${items.length}件をゴミ箱に移動しました'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: '元に戻す',
          onPressed: () {
            _updateState(() {
              for (final item in items) {
                item.deletedAt = null;
              }
            });
            _saveData();
          },
        ),
      ),
    );
  }
}
