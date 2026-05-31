part of '../main.dart';

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

  // カテゴリ別フィルタ（設定された並び順でソート）
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

  // ─── カードから直接期限を変更 ───
  void _showDatePickerForItem(TodoItem item) async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: item.dueDate != null && item.dueDate!.isAfter(now)
          ? item.dueDate!
          : now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365 * 5)),
      locale: const Locale('ja'),
    );
    if (pickedDate != null) {
      if (!mounted) return;
      final isToday =
          pickedDate.year == now.year &&
          pickedDate.month == now.month &&
          pickedDate.day == now.day;
      final pickedTime = await _pickDueTime(
        item.dueDate != null
            ? TimeOfDay.fromDateTime(item.dueDate!)
            : const TimeOfDay(hour: 9, minute: 0),
        minimumDateTime: isToday ? now : null,
      );
      if (pickedTime != null) {
        _updateState(() {
          item.dueDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
        _saveData();
        NotificationService().scheduleNotification(item, s.notificationTiming);
      }
    }
  }

  void _showTimePickerForItem(TodoItem item) async {
    final now = DateTime.now();
    final pickedTime = await _pickDueTime(
      item.dueDate != null
          ? TimeOfDay.fromDateTime(item.dueDate!)
          : const TimeOfDay(hour: 9, minute: 0),
      minimumDateTime: now,
    );
    if (pickedTime != null) {
      _updateState(() {
        item.dueDate = DateTime(
          now.year,
          now.month,
          now.day,
          pickedTime.hour,
          pickedTime.minute,
        );
      });
      _saveData();
      NotificationService().scheduleNotification(item, s.notificationTiming);
    }
  }

  void _completeItemWithFade(TodoItem item) {
    // 繰り返しタスク・完了済み→未完了はアニメーション不要
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

  void _deleteItem(TodoItem item) {
    _updateState(() {
      _allItems.remove(item);
    });
    _saveData();
    NotificationService().cancelNotification(item.id);
  }

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

  Future<void> _exportCompletedTasks() async {
    final completedItems = _allItems.where((item) => item.isDone).toList();
    if (completedItems.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('完了済みタスクがありません')));
      return;
    }

    try {
      final exportedAt = DateTime.now();
      final payload = {
        'formatVersion': 1,
        'type': 'completed_tasks',
        'exportedAt': exportedAt.toIso8601String(),
        'taskCount': completedItems.length,
        'tasks': completedItems.map((item) => item.toJson()).toList(),
      };
      const encoder = JsonEncoder.withIndent('  ');
      final jsonText = encoder.convert(payload);
      final jsonBytes = Uint8List.fromList(utf8.encode(jsonText));
      final fileName =
          'todo_completed_${DateFormat('yyyyMMdd_HHmmss').format(exportedAt)}.json';
      final renderBox = context.findRenderObject() as RenderBox?;
      final shareOrigin = renderBox == null
          ? null
          : renderBox.localToGlobal(Offset.zero) & renderBox.size;

      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              jsonBytes,
              mimeType: 'application/json',
              name: fileName,
            ),
          ],
          fileNameOverrides: [fileName],
          subject: '完了済みタスクのバックアップ',
          text: '完了済みタスク ${completedItems.length}件のバックアップです。',
          sharePositionOrigin: shareOrigin,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to export completed tasks: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('エクスポートできませんでした')));
    }
  }

  String? _normalizeOptionalText(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
