part of '../../../main.dart';

extension _TodoHomeQueries on _TodoHomePageState {
  // カテゴリ（タブ）に対応するタグ絞り込みの選択値
  String _selectedTagFilterFor(String category) => category == 'future'
      ? _selectedFutureTaskTagFilter
      : _selectedTaskTagFilter;

  void _setSelectedTagFilter(String category, String tag) {
    if (category == 'future') {
      _selectedFutureTaskTagFilter = tag;
    } else {
      _selectedTaskTagFilter = tag;
    }
  }

  String _tabName(String key) {
    switch (key) {
      case 'todo':
        return 'やること';
      case 'today':
        return '今日やること';
      case 'tomorrow':
        return '明日やること';
      case 'done':
        return '完了済み';
      case 'future':
        return 'やりたいこと';
      default:
        return key;
    }
  }

  // 「今日やること」「明日やること」タブから追加・編集するときに、日付を固定する
  // 対象日。これらのタブは日付が決まっているので時刻だけ選ばせる。
  // それ以外のタブでは null（日付も自由に選べる）。
  DateTime? _fixedDayForTab(String tabKey) {
    final now = DateTime.now();
    switch (tabKey) {
      case 'today':
        return DateTime(now.year, now.month, now.day);
      case 'tomorrow':
        return DateTime(now.year, now.month, now.day + 1);
      default:
        return null;
    }
  }

  // ゴミ箱に入っていないタスク（通知やバックアップの対象）
  List<TodoItem> get _liveItems =>
      _allItems.where((item) => !item.isDeleted).toList();

  List<TodoItem> _itemsByCategory(String category) {
    // ゴミ箱に入っているタスクはどのタブにも出さない
    final live = _allItems.where((item) => !item.isDeleted);
    final items = switch (category) {
      'done' => live.where((item) => item.isDone).toList(),
      'today' =>
        live.where((item) => !item.isDone && _isDueTodayOrOverdue(item)).toList(),
      'tomorrow' =>
        live.where((item) => !item.isDone && _isDueTomorrow(item)).toList(),
      _ =>
        live
            .where((item) => item.category == category && !item.isDone)
            .toList(),
    };

    // 完了タブはタグ絞り込みを行わない（main/future 混在のため）
    final tagFilter = _selectedTagFilterFor(category);
    if (category != 'done' && tagFilter != allTaskCategoriesLabel) {
      items.removeWhere((item) => item.taskTag != tagFilter);
    }

    // 検索語での絞り込み（どのタブでも効く）
    if (_searchQuery.trim().isNotEmpty) {
      items.removeWhere((item) => !_matchesSearch(item));
    }

    items.sort((a, b) {
      // やりたいことタブは優先度の高い順を最優先（同優先度内は期限順）
      if (category == 'future') {
        final priorityCompare = priorityStarCount(
          b.priority,
        ).compareTo(priorityStarCount(a.priority));
        if (priorityCompare != 0) return priorityCompare;
      }
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

  // 明日が期限のタスク。今日ぶんと期限切れは「今日やること」側に出る。
  bool _isDueTomorrow(TodoItem item) {
    final dueDate = item.dueDate;
    if (dueDate == null) return false;
    final now = DateTime.now();
    final startOfTomorrow = DateTime(now.year, now.month, now.day + 1);
    final endOfTomorrow = DateTime(
      now.year,
      now.month,
      now.day + 1,
      23,
      59,
      59,
      999,
    );
    return !dueDate.isBefore(startOfTomorrow) &&
        !dueDate.isAfter(endOfTomorrow);
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

  // テキストをクリップボードにコピーし、確認のスナックバーを表示する
  void _copyToClipboard(String text, String label) {
    if (text.trim().isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$labelをコピーしました'),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}
