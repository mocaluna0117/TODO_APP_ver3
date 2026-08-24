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
        // やること⇔やりたいことの移動（完了済みはまず未完了に戻してもらう）
        if (!item.isDone &&
            (item.category == 'todo' || item.category == 'future'))
          _compactTodoCardIconButton(
            icon: Icon(
              Icons.drive_file_move_outlined,
              color: Colors.grey.shade500,
              size: 20,
            ),
            onPressed: () => _moveItemToOppositeCategory(item),
            tooltip: item.category == 'future'
                ? '「${_tabName('todo')}」へ移動'
                : '「${_tabName('future')}」へ移動',
          ),
        _compactTodoCardIconButton(
          icon: Icon(
            Icons.content_copy_outlined,
            color: Colors.grey.shade500,
            size: 18,
          ),
          onPressed: () => _duplicateItem(item),
          tooltip: '複製',
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
