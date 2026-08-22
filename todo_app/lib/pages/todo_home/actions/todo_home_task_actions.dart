part of '../../../main.dart';

extension _TodoHomeTaskActions on _TodoHomePageState {
  void _addItem(
    String title,
    String category, {
    String? description,
    List<String> links = const [],
    String? taskTag,
    DateTime? dueDate,
    Recurrence? recurrence,
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
      recurrence: recurrence,
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
    Recurrence? recurrence,
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
      item.recurrence = recurrence;
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
    final recurrence = item.recurrence;
    final dueDate = item.dueDate;

    // 未完了の繰り返しタスクは、完了にする代わりに次回の期限へ進める
    if (!item.isDone && recurrence != null && dueDate != null) {
      final now = DateTime.now();
      // 期限が過去でも「今より後」の回に進める
      final after = now.isAfter(dueDate) ? now : dueDate;
      final nextDueDate = nextRecurrenceDate(recurrence, dueDate, after);
      // 回数指定は、今回の完了で上限に達したらそこで打ち切る
      final total = recurrence.count;
      final reachedCount =
          recurrence.end == RecurrenceEnd.count &&
          total != null &&
          recurrence.doneCount + 1 >= total;

      if (nextDueDate != null && !reachedCount) {
        _updateState(() {
          item.dueDate = nextDueDate;
          item.recurrence = recurrence.copyWith(
            doneCount: recurrence.doneCount + 1,
          );
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

      // 終了条件（終了日・回数）に達したので、繰り返しを終えて完了にする
      _updateState(() {
        if (total != null) {
          item.recurrence = recurrence.copyWith(doneCount: total);
        }
        item.isDone = true;
        item.completedAt = DateTime.now();
      });
      _saveData();
      NotificationService().cancelNotification(item.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('繰り返しが終了しました'),
          duration: Duration(seconds: 2),
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
}
