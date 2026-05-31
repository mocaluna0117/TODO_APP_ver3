part of '../../../main.dart';

extension _TodoHomeTaskActions on _TodoHomePageState {
  void _addItem(
    String title,
    String category, {
    String? description,
    String? taskTag,
    DateTime? dueDate,
    RecurrenceRule recurrenceRule = RecurrenceRule.none,
    List<String> imageBase64List = const [],
    TaskPriority priority = TaskPriority.none,
  }) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    final newItem = TodoItem(
      title: trimmed,
      description: _normalizeOptionalText(description),
      category: category,
      taskTag: _normalizeKnownTaskTag(taskTag),
      dueDate: dueDate,
      recurrenceRule: recurrenceRule,
      imageBase64List: imageBase64List,
      priority: priority,
    );
    _updateState(() {
      _allItems.add(newItem);
    });
    _saveData();
    NotificationService().scheduleNotification(newItem, s.notificationTiming);
  }

  void _editItem(
    TodoItem item,
    String newTitle, {
    String? description,
    String? taskTag,
    DateTime? dueDate,
    RecurrenceRule recurrenceRule = RecurrenceRule.none,
    List<String> imageBase64List = const [],
    TaskPriority priority = TaskPriority.none,
  }) {
    final trimmed = newTitle.trim();
    if (trimmed.isEmpty) return;
    final hadDueDate = item.dueDate != null;
    _updateState(() {
      item.title = trimmed;
      item.description = _normalizeOptionalText(description);
      item.taskTag = _normalizeKnownTaskTag(taskTag);
      item.dueDate = dueDate;
      item.recurrenceRule = recurrenceRule;
      item.imageBase64List = imageBase64List;
      item.priority = priority;
    });
    _saveData();
    if (item.dueDate == null && hadDueDate) {
      NotificationService().cancelNotification(item.id);
    } else {
      NotificationService().scheduleNotification(item, s.notificationTiming);
    }
  }

  void _deleteItem(TodoItem item) {
    _updateState(() {
      _allItems.remove(item);
    });
    _saveData();
    NotificationService().cancelNotification(item.id);
  }

  void _completeItemWithFade(TodoItem item) {
    if (item.isDone || (item.isRecurring && item.dueDate != null)) {
      _toggleItem(item);
      return;
    }
    _updateState(() => _fadingOutItems.add(item.id));
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _updateState(() => _fadingOutItems.remove(item.id));
      _toggleItem(item);
    });
  }

  void _toggleItem(TodoItem item) {
    if (!item.isDone && item.isRecurring && item.dueDate != null) {
      late final DateTime nextDueDate;
      _updateState(() {
        nextDueDate = _nextRecurringDueDate(item.dueDate!, item.recurrenceRule);
        item.dueDate = nextDueDate;
      });
      _saveData();
      NotificationService().scheduleNotification(item, s.notificationTiming);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '次回: ${DateFormat('yyyy/MM/dd (E) HH:mm', 'ja').format(nextDueDate)} に更新しました',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    _updateState(() {
      item.isDone = !item.isDone;
      item.completedAt = item.isDone ? DateTime.now() : null;
    });
    _saveData();
    if (item.isDone) {
      NotificationService().cancelNotification(item.id);
    } else {
      NotificationService().scheduleNotification(item, s.notificationTiming);
    }
  }

  DateTime _nextRecurringDueDate(DateTime dueDate, RecurrenceRule rule) {
    var nextDate = dueDate;
    final now = DateTime.now();
    do {
      nextDate = _addRecurrenceInterval(nextDate, rule);
    } while (!nextDate.isAfter(now));
    return nextDate;
  }

  DateTime _addRecurrenceInterval(DateTime date, RecurrenceRule rule) {
    switch (rule) {
      case RecurrenceRule.daily:
        return date.add(const Duration(days: 1));
      case RecurrenceRule.weekly:
        return date.add(const Duration(days: 7));
      case RecurrenceRule.monthly:
        return _addMonthsClamped(date, 1);
      case RecurrenceRule.none:
        return date;
    }
  }

  DateTime _addMonthsClamped(DateTime date, int months) {
    final targetMonthIndex = date.month - 1 + months;
    final targetYear = date.year + targetMonthIndex ~/ 12;
    final targetMonth = targetMonthIndex % 12 + 1;
    final targetDay = date.day.clamp(
      1,
      DateUtils.getDaysInMonth(targetYear, targetMonth),
    );
    return DateTime(
      targetYear,
      targetMonth,
      targetDay,
      date.hour,
      date.minute,
      date.second,
      date.millisecond,
      date.microsecond,
    );
  }
}
