part of '../../../main.dart';

extension _TodoHomeTagActions on _TodoHomePageState {
  // アイテムが future グループ（やりたいこと）かどうか
  bool _isFutureItem(TodoItem item) => item.category == 'future';

  String? _normalizeKnownTaskTag(String? tag, String category) {
    final normalized = normalizeTaskTag(tag);
    if (normalized == null ||
        !s.tagsForCategory(category).contains(normalized)) {
      return null;
    }
    return normalized;
  }

  void _renameTaskTag(String oldTag, String newTag, {required bool isFuture}) {
    _updateState(() {
      for (final item in _allItems) {
        if (_isFutureItem(item) == isFuture && item.taskTag == oldTag) {
          item.taskTag = newTag;
        }
      }
      if (isFuture) {
        if (_selectedFutureTaskTagFilter == oldTag) {
          _selectedFutureTaskTagFilter = newTag;
        }
      } else if (_selectedTaskTagFilter == oldTag) {
        _selectedTaskTagFilter = newTag;
      }
    });
    _saveData();
  }

  void _deleteTaskTag(String tag, {required bool isFuture}) {
    _updateState(() {
      for (final item in _allItems) {
        if (_isFutureItem(item) == isFuture && item.taskTag == tag) {
          item.taskTag = null;
        }
      }
      if (isFuture) {
        if (_selectedFutureTaskTagFilter == tag) {
          _selectedFutureTaskTagFilter = allTaskCategoriesLabel;
        }
      } else if (_selectedTaskTagFilter == tag) {
        _selectedTaskTagFilter = allTaskCategoriesLabel;
      }
    });
    _saveData();
  }

  void _removeUnknownTaskTags() {
    var changed = false;
    for (final item in _allItems) {
      final groupTags = _isFutureItem(item) ? s.futureTaskTags : s.taskTags;
      if (item.taskTag != null && !groupTags.contains(item.taskTag)) {
        item.taskTag = null;
        changed = true;
      }
    }
    if (_selectedTaskTagFilter != allTaskCategoriesLabel &&
        !s.taskTags.contains(_selectedTaskTagFilter)) {
      _selectedTaskTagFilter = allTaskCategoriesLabel;
    }
    if (_selectedFutureTaskTagFilter != allTaskCategoriesLabel &&
        !s.futureTaskTags.contains(_selectedFutureTaskTagFilter)) {
      _selectedFutureTaskTagFilter = allTaskCategoriesLabel;
    }
    if (changed) {
      _saveData();
    }
  }
}
