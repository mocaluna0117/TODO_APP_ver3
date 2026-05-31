part of '../main.dart';

extension _TodoHomeTodoCard on _TodoHomePageState {
  Widget _buildTodoCard(TodoItem item, String category) {
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
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: Colors.white,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            onTap: category == 'done'
                ? null
                : () => _showEditDialog(item, tabKey: category),
            leading: category == 'done' ? null : _buildTodoCardCheckbox(item),
            title: _buildTodoCardTitle(item),
            subtitle: _buildTodoSubtitle(item),
            trailing: _buildTodoCardActions(item, category),
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
    return Checkbox(
      value: item.isDone,
      onChanged: (_) => _completeItemWithFade(item),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      activeColor: s.primaryColor,
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
        color: item.isDone ? Colors.grey : Colors.black87,
      ),
    );
  }
}
