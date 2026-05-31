part of '../../../main.dart';

extension _TodoHomeTagActions on _TodoHomePageState {
  String? _normalizeKnownTaskTag(String? tag) {
    final normalized = normalizeTaskTag(tag);
    if (normalized == null || !s.taskTags.contains(normalized)) return null;
    return normalized;
  }

  void _renameTaskTag(String oldTag, String newTag) {
    _updateState(() {
      for (final item in _allItems) {
        if (item.taskTag == oldTag) {
          item.taskTag = newTag;
        }
      }
      if (_selectedTaskTagFilter == oldTag) {
        _selectedTaskTagFilter = newTag;
      }
    });
    _saveData();
  }

  void _deleteTaskTag(String tag) {
    _updateState(() {
      for (final item in _allItems) {
        if (item.taskTag == tag) {
          item.taskTag = null;
        }
      }
      if (_selectedTaskTagFilter == tag) {
        _selectedTaskTagFilter = allTaskCategoriesLabel;
      }
    });
    _saveData();
  }

  void _removeUnknownTaskTags() {
    var changed = false;
    for (final item in _allItems) {
      if (item.taskTag != null && !s.taskTags.contains(item.taskTag)) {
        item.taskTag = null;
        changed = true;
      }
    }
    if (_selectedTaskTagFilter != allTaskCategoriesLabel &&
        !s.taskTags.contains(_selectedTaskTagFilter)) {
      _selectedTaskTagFilter = allTaskCategoriesLabel;
    }
    if (changed) {
      _saveData();
    }
  }
}
