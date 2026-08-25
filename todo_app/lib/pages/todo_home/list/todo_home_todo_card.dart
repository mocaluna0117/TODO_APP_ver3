part of '../../../main.dart';

// 繰り返しタスクをチェックしたときの選択肢
enum _RecurringCompleteAction { advance, finish }

extension _TodoHomeTodoCard on _TodoHomePageState {
  Widget _buildTodoCard(TodoItem item, String category) {
    // 2ペイン表示中は、選択中のタスクを枠線でハイライトする
    final isSelected =
        _isWideLayout && item.id == _effectiveSelectedDetailId(category);
    // 2ペイン時は位置を測れるようにキーを付ける
    // （選択カードへのスクロールと、スクロール追従の可視判定に使う）
    final cardKey = _isWideLayout
        ? (_cardKeys[category] ??= {}).putIfAbsent(item.id, () => GlobalKey())
        : null;

    return AnimatedOpacity(
      opacity: _fadingOutItems.contains(item.id) ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      child: Dismissible(
        key: ValueKey(item),
        direction: s.enableSwipeDelete
            ? DismissDirection.endToStart
            : DismissDirection.none,
        confirmDismiss: (_) => _handleDelete(item),
        background: _buildTodoCardDeleteBackground(),
        child: Card(
          key: cardKey,
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: isSelected
                ? BorderSide(color: s.accentOnSurface, width: 2)
                : BorderSide.none,
          ),
          color: s.surfaceColor,
          child: ListTile(
            contentPadding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
            // チェックボックスを左に寄せ、タイトルとの間隔も詰めて本文幅を広げる
            horizontalTitleGap: 6,
            minLeadingWidth: 0,
            onTap: category == 'done'
                ? null
                : () {
                    if (_isWideLayout) {
                      // 2ペイン時はモーダルではなく右の詳細ペインに表示
                      _updateState(() {
                        _selectedDetailItemIds[category] = item.id;
                        _detailDraft = null; // ドラフトを作り直す
                      });
                    } else {
                      _showEditDialog(item, tabKey: category);
                    }
                  },
            leading: category == 'done' ? null : _buildTodoCardCheckbox(item),
            title: _buildTodoCardTitle(item),
            subtitle: _buildTodoSubtitle(item),
            trailing: _buildTodoCardActions(item),
          ),
        ),
      ),
    );
  }

  Widget _buildTodoCardDeleteBackground() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.red.shade400,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(Icons.delete, color: Colors.white),
    );
  }

  Widget _buildTodoCardCheckbox(TodoItem item) {
    final checkbox = Checkbox(
      value: item.isDone,
      onChanged: (_) => _completeItemWithFade(item),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      activeColor: s.accentOnSurface,
      // 暗い配色では塗りを明るくするので、チェックマークは暗い色にする
      checkColor: s.onAccentColor,
      // タップ領域を縮めてカード左端に寄せる
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    // 未完了の繰り返しタスクは、押したときに「次回に進める」か
    // 「繰り返しを終了して完了」かを選べるようにする。
    if (item.isDone || !item.isRecurring || item.dueDate == null) {
      return checkbox;
    }
    return _buildRecurringCheckboxMenu(item, checkbox);
  }

  Widget _buildRecurringCheckboxMenu(TodoItem item, Widget checkbox) {
    final next = _nextRecurringDueDateOf(item);
    return PopupMenuButton<_RecurringCompleteAction>(
      tooltip: '完了のしかたを選ぶ',
      padding: EdgeInsets.zero,
      position: PopupMenuPosition.under,
      onSelected: (action) {
        switch (action) {
          case _RecurringCompleteAction.advance:
            _completeItemWithFade(item);
          case _RecurringCompleteAction.finish:
            _finishRecurringTask(item);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _RecurringCompleteAction.advance,
          child: _buildRecurringMenuRow(
            icon: Icons.event_repeat,
            label: '次回に進める',
            // 次が無い（繰り返しが終わる回）ときは日付を出さない
            detail: next == null
                ? null
                : DateFormat('M/d(E) HH:mm', 'ja').format(next),
          ),
        ),
        PopupMenuItem(
          value: _RecurringCompleteAction.finish,
          child: _buildRecurringMenuRow(
            icon: Icons.check_circle_outline,
            label: '繰り返しを終了して完了',
            detail: '以降は繰り返しません',
          ),
        ),
      ],
      // 見た目はチェックボックスのまま。タップはメニューに渡す。
      child: IgnorePointer(child: checkbox),
    );
  }

  Widget _buildRecurringMenuRow({
    required IconData icon,
    required String label,
    String? detail,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: s.accentOnSurface),
        const SizedBox(width: 10),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            if (detail != null)
              Text(
                detail,
                style: TextStyle(fontSize: 11, color: s.secondaryTextColor),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildTodoCardTitle(TodoItem item) {
    return Text(
      item.title,
      style: TextStyle(
        fontSize: 16,
        decoration: item.isDone
            ? TextDecoration.lineThrough
            : TextDecoration.none,
        color: item.isDone ? Colors.grey : s.primaryTextColor,
      ),
    );
  }
}
