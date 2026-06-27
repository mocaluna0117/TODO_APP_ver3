part of '../../../main.dart';

extension _TodoHomeTodoCardActions on _TodoHomePageState {
  Widget _buildTodoCardActions(TodoItem item) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (item.isDone)
          _compactTodoCardIconButton(
            icon: Icon(Icons.replay, color: s.accentColor),
            onPressed: () => _confirmRestoreTodo(item),
            tooltip: '未完了に戻す',
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
