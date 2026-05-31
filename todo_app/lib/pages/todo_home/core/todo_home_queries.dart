part of '../../../main.dart';

extension _TodoHomeQueries on _TodoHomePageState {
  String _tabName(String key) {
    switch (key) {
      case 'todo':
        return s.todoTabName;
      case 'today':
        return s.todayTabName;
      case 'done':
        return s.doneTabName;
      case 'future':
        return s.futureTabName;
      default:
        return key;
    }
  }

  List<TodoItem> _itemsByCategory(String category) {
    final items = switch (category) {
      'done' => _allItems.where((item) => item.isDone).toList(),
      'today' =>
        _allItems
            .where((item) => !item.isDone && _isDueTodayOrOverdue(item))
            .toList(),
      _ =>
        _allItems
            .where((item) => item.category == category && !item.isDone)
            .toList(),
    };

    if (_selectedTaskTagFilter != allTaskCategoriesLabel) {
      items.removeWhere((item) => item.taskTag != _selectedTaskTagFilter);
    }

    items.sort((a, b) {
      if (a.dueDate == null && b.dueDate == null) return 0;
      if (a.dueDate == null) return 1;
      if (b.dueDate == null) return -1;
      return s.sortOrder == SortOrder.dueDateAsc
          ? a.dueDate!.compareTo(b.dueDate!)
          : b.dueDate!.compareTo(a.dueDate!);
    });
    return items;
  }

  bool _isDueTodayOrOverdue(TodoItem item) {
    final dueDate = item.dueDate;
    if (dueDate == null) return false;
    final now = DateTime.now();
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    return !dueDate.isAfter(endOfToday);
  }

  String _formatTodoCardDueDate(DateTime dueDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final timeText = DateFormat('HH:mm').format(dueDate);

    if (dueDate.isBefore(now)) {
      return DateFormat('M/d(E) HH:mm', 'ja').format(dueDate);
    }
    if (dueDay == today) {
      return '今日 $timeText';
    }
    if (dueDay == tomorrow) {
      return '明日 $timeText';
    }
    return DateFormat('M/d(E) HH:mm', 'ja').format(dueDate);
  }

  String? _normalizeOptionalText(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
