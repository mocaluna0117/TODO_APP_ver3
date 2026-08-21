part of '../../../main.dart';

extension _TodoHomeTaskActions on _TodoHomePageState {
  void _addItem(
    String title,
    String category, {
    String? description,
    List<String> links = const [],
    String? taskTag,
    DateTime? dueDate,
    RecurrenceRule recurrenceRule = RecurrenceRule.none,
    List<String> imageBase64List = const [],
    TaskPriority priority = TaskPriority.none,
    List<int>? notificationOffsets,
  }) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    final newItem = TodoItem(
      title: trimmed,
      description: _normalizeOptionalText(description),
      links: normalizeLinkList(links),
      category: category,
      taskTag: _normalizeKnownTaskTag(taskTag, category),
      dueDate: dueDate,
      recurrenceRule: recurrenceRule,
      imageBase64List: imageBase64List,
      priority: priority,
      notificationOffsets: notificationOffsets,
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
    List<String> links = const [],
    String? taskTag,
    DateTime? dueDate,
    RecurrenceRule recurrenceRule = RecurrenceRule.none,
    List<String> imageBase64List = const [],
    TaskPriority priority = TaskPriority.none,
    List<int>? notificationOffsets,
  }) {
    final trimmed = newTitle.trim();
    if (trimmed.isEmpty) return;
    final hadDueDate = item.dueDate != null;
    // 編集で外された画像URLは、あとで Storage からも削除する
    final removedImageUrls = item.imageBase64List
        .where((e) => _isImageUrl(e) && !imageBase64List.contains(e))
        .toList();
    _updateState(() {
      item.title = trimmed;
      item.description = _normalizeOptionalText(description);
      item.links = normalizeLinkList(links);
      item.taskTag = _normalizeKnownTaskTag(taskTag, item.category);
      item.dueDate = dueDate;
      item.recurrenceRule = recurrenceRule;
      item.imageBase64List = imageBase64List;
      item.priority = priority;
      item.notificationOffsets = notificationOffsets;
    });
    _saveData();
    _deleteImagesByUrls(removedImageUrls);
    if (item.dueDate == null && hadDueDate) {
      NotificationService().cancelNotification(item.id);
    } else {
      NotificationService().scheduleNotification(item, s.notificationTiming);
    }
  }

  // やること⇔やりたいことの間でタスクを移動する
  void _moveItemToOppositeCategory(TodoItem item) {
    final toCategory = item.category == 'future' ? 'todo' : 'future';
    _updateState(() {
      item.category = toCategory;
      // タグはカテゴリごとに別管理なので、移動先に存在しないタグは外す
      item.taskTag = _normalizeKnownTaskTag(item.taskTag, toCategory);
    });
    _saveData();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('「${_tabName(toCategory)}」へ移動しました'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _deleteItem(TodoItem item) {
    _updateState(() {
      _allItems.remove(item);
    });
    _saveData();
    _deleteTaskImages(item.id);
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
    final now = DateTime.now();
    // 1回ずつ足し込むのではなく、毎回「元の期限から n 回ぶん」を計算する。
    // 月末や第5週のように丸めが起きる場合、丸めた日付を次の基準にすると
    // 繰り返すたびに日付がずれていってしまうため。
    var steps = 1;
    var nextDate = _shiftedDueDate(dueDate, rule, steps);
    while (!nextDate.isAfter(now)) {
      final shifted = _shiftedDueDate(dueDate, rule, ++steps);
      // 日付が進まないルール（none）で無限ループにならないようにする
      if (!shifted.isAfter(nextDate)) break;
      nextDate = shifted;
    }
    return nextDate;
  }

  // 元の期限から [steps] 回ぶん繰り返しを進めた日付を返す。
  DateTime _shiftedDueDate(DateTime dueDate, RecurrenceRule rule, int steps) {
    // 毎週・2〜4週ごとはいずれも「同じ曜日の n 週後」
    final weekInterval = recurrenceWeekInterval(rule);
    if (weekInterval != null) {
      return dueDate.add(Duration(days: 7 * weekInterval * steps));
    }
    switch (rule) {
      case RecurrenceRule.daily:
        return dueDate.add(Duration(days: steps));
      case RecurrenceRule.monthly:
        return _addMonthsClamped(dueDate, steps);
      case RecurrenceRule.monthlyNthWeekday:
        return _weekdayOfMonthAhead(
          dueDate,
          steps,
          ordinal: recurrenceWeekdayOrdinal(dueDate),
        );
      case RecurrenceRule.monthlyLastWeekday:
        return _weekdayOfMonthAhead(dueDate, steps, ordinal: null);
      default:
        return dueDate;
    }
  }

  // 期限の [monthsAhead] か月後の月について、期限と同じ曜日の [ordinal] 番目
  // （null なら最後）に当たる日付を返す。時刻は期限のものを引き継ぐ。
  DateTime _weekdayOfMonthAhead(
    DateTime dueDate,
    int monthsAhead, {
    required int? ordinal,
  }) {
    final monthIndex = dueDate.month - 1 + monthsAhead;
    final year = dueDate.year + monthIndex ~/ 12;
    final month = monthIndex % 12 + 1;
    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    final weekday = dueDate.weekday;
    int day;
    if (ordinal == null) {
      // その月で最後に来る同曜日
      final lastWeekday = DateTime(year, month, daysInMonth).weekday;
      day = daysInMonth - (lastWeekday - weekday + 7) % 7;
    } else {
      final firstWeekday = DateTime(year, month, 1).weekday;
      day = 1 + (weekday - firstWeekday + 7) % 7 + (ordinal - 1) * 7;
      // 第5○曜日が存在しない月は、その月で最後に来る同曜日に丸める
      while (day > daysInMonth) {
        day -= 7;
      }
    }
    return DateTime(
      year,
      month,
      day,
      dueDate.hour,
      dueDate.minute,
      dueDate.second,
      dueDate.millisecond,
      dueDate.microsecond,
    );
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
