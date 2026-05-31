part of '../../../main.dart';

extension _TodoHomeTaskLabels on _TodoHomePageState {
  Widget _buildTaskLabels(TodoItem item, {bool hasTaskPriority = false}) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (hasTaskPriority) _buildTaskPriorityLabel(item),
        if (item.taskTag != null) _buildTaskTagLabel(item),
        if (item.isRecurring) _buildRecurrenceLabel(item),
      ],
    );
  }

  Widget _buildTaskPriorityLabel(TodoItem item) {
    final color = priorityColor(item.priority);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: item.isDone ? 0.08 : 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPriorityStars(
            item.priority,
            size: 12,
            color: item.isDone ? Colors.grey.shade500 : color,
          ),
        ],
      ),
    );
  }

  Widget _buildTaskTagLabel(TodoItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: s.primaryColor.withValues(alpha: item.isDone ? 0.08 : 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        item.taskTag!,
        style: TextStyle(
          color: item.isDone ? Colors.grey.shade500 : s.primaryColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildRecurrenceLabel(TodoItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: s.accentColor.withValues(alpha: item.isDone ? 0.08 : 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.repeat,
            size: 11,
            color: item.isDone ? Colors.grey.shade500 : s.primaryColor,
          ),
          const SizedBox(width: 3),
          Text(
            item.recurrenceRule.label,
            style: TextStyle(
              color: item.isDone ? Colors.grey.shade500 : s.primaryColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
