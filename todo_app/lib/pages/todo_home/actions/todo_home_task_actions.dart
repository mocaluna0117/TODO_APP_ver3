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
    List<TaskFile> attachments = const [],
    List<PendingTaskFile> pendingFiles = const [],
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
      attachments: [...attachments],
      pendingFiles: [...pendingFiles],
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
    List<TaskFile> attachments = const [],
    List<PendingTaskFile> pendingFiles = const [],
    TaskPriority priority = TaskPriority.none,
    List<int>? notificationOffsets,
  }) {
    final trimmed = newTitle.trim();
    if (trimmed.isEmpty) return;
    final hadDueDate = item.dueDate != null;
    // 編集で外された画像・添付ファイルは、あとで Storage からも削除する
    final keptFileUrls = attachments.map((file) => file.url).toSet();
    final removedUrls = [
      ...item.imageBase64List.where(
        (e) => _isImageUrl(e) && !imageBase64List.contains(e),
      ),
      ...item.attachments
          .map((file) => file.url)
          .where((url) => !keptFileUrls.contains(url)),
    ];
    _updateState(() {
      item.title = trimmed;
      item.description = _normalizeOptionalText(description);
      item.links = normalizeLinkList(links);
      item.taskTag = _normalizeKnownTaskTag(taskTag, item.category);
      item.dueDate = dueDate;
      item.recurrence = recurrence;
      item.imageBase64List = imageBase64List;
      item.attachments = [...attachments];
      item.pendingFiles = [...pendingFiles];
      item.priority = priority;
      item.notificationOffsets = notificationOffsets;
    });
    _saveData();
    _deleteStorageFilesByUrls(removedUrls);
    if (item.dueDate == null && hadDueDate) {
      NotificationService().cancelNotification(item.id);
    } else {
      NotificationService().scheduleNotification(item, s.notificationTiming);
    }
  }

  // タスクを複製する。
  // 完了状態と繰り返しの進捗はリセットし、すぐ取り組める状態で作る。
  // 画像とPDFは、実体を読み込み直して複製側のフォルダへ入れ直す（後述）。
  void _duplicateItem(TodoItem item) {
    final recurrence = item.recurrence;
    final offsets = item.notificationOffsets;
    final duplicate = TodoItem(
      title: '${item.title}のコピー',
      description: item.description,
      links: [...item.links],
      category: item.category,
      taskTag: _normalizeKnownTaskTag(item.taskTag, item.category),
      dueDate: item.dueDate,
      // 繰り返し回数の進捗は引き継がない（複製は1回目から数える）
      recurrence: recurrence?.copyWith(doneCount: 0),
      priority: item.priority,
      notificationOffsets: offsets == null ? null : [...offsets],
    );
    _updateState(() => _allItems.add(duplicate));
    _saveData();
    NotificationService().scheduleNotification(duplicate, s.notificationTiming);

    final hasAttachments =
        item.imageBase64List.isNotEmpty || item.attachments.isNotEmpty;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(hasAttachments ? '複製しました（画像とPDFを引き継ぎ中）' : '複製しました'),
        duration: const Duration(seconds: 3),
      ),
    );
    if (hasAttachments) {
      _copyAttachmentsToDuplicate(item, duplicate);
    }
  }

  // 複製先へ画像・PDFを引き継ぐ。
  //
  // URLをそのままコピーすると Storage 上の実体を2つのタスクで共有してしまい、
  // 片方を削除・編集したときにもう片方の画像まで消える。そのため実体を
  // 読み込んで「未アップロードの添付」として渡し、複製側のフォルダへ
  // アップロードし直す（アップロード自体は保存処理が行う）。
  Future<void> _copyAttachmentsToDuplicate(
    TodoItem source,
    TodoItem duplicate,
  ) async {
    if (!mounted) return;
    // 引き継ぎ中はカードに「アップロード中」を出す
    _updateState(() => _uploadingImageItemIds.add(duplicate.id));
    var failed = 0;
    try {
      final images = <String>[];
      for (final entry in source.imageBase64List) {
        if (!_isImageUrl(entry)) {
          images.add(entry); // まだアップロードされていない画像はそのまま
          continue;
        }
        final bytes = await _downloadStorageFile(entry);
        if (bytes == null) {
          failed++;
        } else {
          images.add(base64Encode(bytes));
        }
      }

      final files = <PendingTaskFile>[];
      for (final file in source.attachments) {
        final bytes = await _downloadStorageFile(file.url);
        if (bytes == null) {
          failed++;
        } else {
          files.add(PendingTaskFile(name: file.name, bytes: bytes));
        }
      }

      if (!mounted) return;
      _updateState(() {
        duplicate.imageBase64List = images;
        duplicate.pendingFiles = files;
      });
      await _saveData();
    } finally {
      if (mounted) {
        _updateState(() => _uploadingImageItemIds.remove(duplicate.id));
      }
    }

    if (!mounted || failed == 0) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$failed件のファイルを引き継げませんでした')));
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

  // 削除はゴミ箱への移動にする。実体（画像・PDF）も復元できるよう残しておき、
  // 完全削除のときにまとめて消す。
  void _deleteItem(TodoItem item) {
    _updateState(() {
      item.deletedAt = DateTime.now();
    });
    _saveData();
    NotificationService().cancelNotification(item.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('「${item.title}」をゴミ箱に移動しました'),
        duration: const Duration(seconds: 5),
        // Flutter 3.38 以降、アクション付きの SnackBar は既定で自動的に
        // 消えなくなった（persist が action != null で真になる）。
        // 時間で消えてほしいので明示的に打ち消す。
        persist: false,
        action: SnackBarAction(
          label: '元に戻す',
          onPressed: () => _restoreFromTrash(item),
        ),
      ),
    );
  }

  // ゴミ箱に入っているタスク（新しく捨てたものが先）
  List<TodoItem> get _trashedItems {
    final items = _allItems.where((item) => item.isDeleted).toList();
    items.sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));
    return items;
  }

  // ゴミ箱から元に戻す
  void _restoreFromTrash(TodoItem item) {
    _updateState(() {
      item.deletedAt = null;
    });
    _saveData();
    NotificationService().scheduleNotification(item, s.notificationTiming);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('「${item.title}」を元に戻しました'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ゴミ箱から完全に削除する（添付ファイルも消す）
  void _deleteItemPermanently(TodoItem item) {
    _updateState(() {
      _allItems.remove(item);
    });
    _saveData();
    _deleteTaskImages(item.id);
    NotificationService().cancelNotification(item.id);
  }

  // ゴミ箱を空にする
  void _emptyTrash() {
    final items = _trashedItems;
    if (items.isEmpty) return;
    final ids = items.map((item) => item.id).toList();
    _updateState(() {
      _allItems.removeWhere((item) => item.isDeleted);
    });
    _saveData();
    for (final id in ids) {
      _deleteTaskImages(id);
      NotificationService().cancelNotification(id);
    }
  }

  // 保持期間を過ぎたゴミ箱のタスクを完全に削除する。
  // アプリを開いたときに実行するので、開かない間は残ったままになる。
  void _purgeExpiredTrash() {
    final limit = DateTime.now().subtract(kTrashRetention);
    final expired = _allItems
        .where(
          (item) => item.deletedAt != null && item.deletedAt!.isBefore(limit),
        )
        .toList();
    if (expired.isEmpty) return;
    final ids = expired.map((item) => item.id).toSet();
    _updateState(() {
      _allItems.removeWhere((item) => ids.contains(item.id));
    });
    _saveData();
    for (final id in ids) {
      _deleteTaskImages(id);
    }
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

  // 2ペイン表示で同じタスクを開いている場合、アプリ側で書き換えた内容を
  // ドラフトへ反映する。ドラフトは選択中タスクのIDが変わるまで作り直されない
  // ため、これをしないと保存時に古い内容へ巻き戻ってしまう。
  void _syncOpenDetailDraft(TodoItem item) {
    if (_detailDraftItemId != item.id) return;
    final draft = _detailDraft;
    if (draft == null) return;
    draft.selectedDate = item.dueDate;
    draft.selectedRecurrence = item.recurrence;
  }

  // 添付のアップロード完了（base64→URL、PDFのアップロード）をドラフトへ反映する
  void _syncOpenDetailDraftAttachments(TodoItem item) {
    if (_detailDraftItemId != item.id) return;
    final draft = _detailDraft;
    if (draft == null) return;
    draft.selectedImageBase64List = [...item.imageBase64List];
    draft.selectedFiles = [...item.attachments];
    draft.pendingFiles = [...item.pendingFiles];
  }

  // 次に進む期限。繰り返しが終わる回なら null。
  // チェック時のメニューに「次回」を出すために使う。
  DateTime? _nextRecurringDueDateOf(TodoItem item) {
    final recurrence = item.recurrence;
    final dueDate = item.dueDate;
    if (recurrence == null || dueDate == null) return null;
    final now = DateTime.now();
    final after = now.isAfter(dueDate) ? now : dueDate;
    return nextRecurrenceDate(recurrence.resolvedFor(dueDate), dueDate, after);
  }

  // 繰り返しをやめて、このタスクを完了にする。
  // 以降くり返さないよう設定自体を外すので、未完了に戻しても再開しない。
  void _finishRecurringTask(TodoItem item) {
    _updateState(() {
      item.recurrence = null;
      item.isDone = true;
      item.completedAt = DateTime.now();
      _syncOpenDetailDraft(item);
    });
    _saveData();
    NotificationService().cancelNotification(item.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('「${item.title}」の繰り返しを終了して完了にしました'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _toggleItem(TodoItem item) {
    final recurrence = item.recurrence;
    final dueDate = item.dueDate;

    // 未完了の繰り返しタスクは、完了にする代わりに次回の期限へ進める
    if (!item.isDone && recurrence != null && dueDate != null) {
      final now = DateTime.now();
      // 期限が過去でも「今より後」の回に進める
      final after = now.isAfter(dueDate) ? now : dueDate;
      // 曜日・日を省略している設定は、ここで今の期限を基準に確定させる。
      // 毎回導出し直すと、月末などで丸めが起きた月以降ずっとずれてしまう。
      final resolved = recurrence.resolvedFor(dueDate);
      final nextDueDate = nextRecurrenceDate(resolved, dueDate, after);
      // 回数指定は、今回の完了で上限に達したらそこで打ち切る
      final total = resolved.count;
      final isCountLimited =
          resolved.end == RecurrenceEnd.count && total != null;
      final reachedCount = isCountLimited && resolved.doneCount + 1 >= total;

      if (nextDueDate != null && !reachedCount) {
        _updateState(() {
          item.dueDate = nextDueDate;
          // doneCount は回数指定の進捗にしか使わないので、そのときだけ数える
          item.recurrence = isCountLimited
              ? resolved.copyWith(doneCount: resolved.doneCount + 1)
              : resolved;
          _syncOpenDetailDraft(item);
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
        item.recurrence = isCountLimited
            ? resolved.copyWith(doneCount: total)
            : resolved;
        item.isDone = true;
        item.completedAt = DateTime.now();
        _syncOpenDetailDraft(item);
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
