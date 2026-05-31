part of '../../../main.dart';

extension _TodoHomePriorityPicker on _TodoHomePageState {
  Widget _buildTaskPriorityPicker({
    required TaskPriority selectedTaskPriority,
    required ValueChanged<TaskPriority> onChanged,
  }) {
    final selectedStars = priorityStarCount(selectedTaskPriority);

    return Container(
      padding: const EdgeInsets.only(left: 16, right: 8, top: 8, bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.star_outline_rounded, color: s.primaryColor),
          const SizedBox(width: 10),
          const Text(
            '優先度',
            style: TextStyle(fontSize: 15, color: Colors.black87),
          ),
          const Spacer(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (index) {
              final starNumber = index + 1;
              final isSelected = selectedStars >= starNumber;

              return IconButton(
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(
                  width: 36,
                  height: 36,
                ),
                padding: EdgeInsets.zero,
                tooltip: '$starNumberつ星',
                icon: Icon(
                  isSelected ? Icons.star_rounded : Icons.star_border_rounded,
                  color: isSelected
                      ? priorityColor(selectedTaskPriority)
                      : Colors.grey.shade400,
                  size: 26,
                ),
                onPressed: () => onChanged(priorityFromStarCount(starNumber)),
              );
            }),
          ),
          if (selectedTaskPriority != TaskPriority.none)
            IconButton(
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 32, height: 36),
              padding: EdgeInsets.zero,
              tooltip: '優先度を解除',
              icon: Icon(Icons.close, size: 18, color: Colors.grey.shade500),
              onPressed: () => onChanged(TaskPriority.none),
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildPriorityStars(
    TaskPriority priority, {
    double size = 14,
    Color? color,
  }) {
    final selectedStars = priorityStarCount(priority);
    final activeColor = color ?? priorityColor(priority);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        final isSelected = index < selectedStars;
        return Icon(
          isSelected ? Icons.star_rounded : Icons.star_border_rounded,
          size: size,
          color: isSelected ? activeColor : Colors.grey.shade400,
        );
      }),
    );
  }
}
