part of '../main.dart';

extension _TodoHomeTodoCardActions on _TodoHomePageState {
  Widget _buildTodoCardActions(TodoItem item, String category) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (item.isDone)
          _compactTodoCardIconButton(
            icon: Icon(Icons.replay, color: s.accentColor),
            onPressed: () => _confirmRestoreTodo(item),
            tooltip: '未完了に戻す',
          ),
        if (!item.isDone && item.category == 'future')
          _compactTodoCardIconButton(
            icon: Icon(
              Icons.arrow_circle_left_outlined,
              color: s.primaryColor,
              size: 22,
            ),
            onPressed: () => _showMoveToTodoDialog(item),
            tooltip: 'やることに移動',
          ),
        if (!item.isDone && item.category == 'todo')
          _compactTodoCardIconButton(
            icon: Icon(
              Icons.arrow_circle_right_outlined,
              color: Colors.orange.shade400,
              size: 22,
            ),
            onPressed: () => _showMoveToFutureDialog(item),
            tooltip: 'やりたいことに戻す',
          ),
        if (category == 'today')
          _compactTodoCardIconButton(
            icon: Icon(
              Icons.access_time,
              color: item.dueDate != null
                  ? s.primaryColor
                  : const Color(0xFFAAAAAA),
              size: 20,
            ),
            onPressed: () => _showTimePickerForItem(item),
            tooltip: '時間を設定',
          )
        else if (category != 'done')
          _compactTodoCardIconButton(
            icon: Icon(
              Icons.calendar_today,
              color: item.dueDate != null
                  ? s.primaryColor
                  : const Color(0xFFAAAAAA),
              size: 20,
            ),
            onPressed: () => _showDatePickerForItem(item),
            tooltip: '期限を設定',
          ),
        _compactTodoCardIconButton(
          icon: Icon(
            Icons.delete_outline,
            color: Colors.red.shade300,
            size: 20,
          ),
          onPressed: () => _handleDelete(item),
          tooltip: '削除',
        ),
      ],
    );
  }

  Widget _compactTodoCardIconButton({
    required Widget icon,
    required VoidCallback? onPressed,
    required String tooltip,
  }) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 34, height: 34),
      padding: EdgeInsets.zero,
      icon: icon,
      onPressed: onPressed,
      tooltip: tooltip,
    );
  }
}
