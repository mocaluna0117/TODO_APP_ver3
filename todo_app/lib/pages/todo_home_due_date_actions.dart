part of '../main.dart';

extension _TodoHomeDueDateActions on _TodoHomePageState {
  void _showDatePickerForItem(TodoItem item) async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: item.dueDate != null && item.dueDate!.isAfter(now)
          ? item.dueDate!
          : now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365 * 5)),
      locale: const Locale('ja'),
    );
    if (pickedDate != null) {
      if (!mounted) return;
      final isToday =
          pickedDate.year == now.year &&
          pickedDate.month == now.month &&
          pickedDate.day == now.day;
      final pickedTime = await _pickDueTime(
        item.dueDate != null
            ? TimeOfDay.fromDateTime(item.dueDate!)
            : const TimeOfDay(hour: 9, minute: 0),
        minimumDateTime: isToday ? now : null,
      );
      if (pickedTime != null) {
        _updateState(() {
          item.dueDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
        _saveData();
        NotificationService().scheduleNotification(item, s.notificationTiming);
      }
    }
  }

  void _showTimePickerForItem(TodoItem item) async {
    final now = DateTime.now();
    final pickedTime = await _pickDueTime(
      item.dueDate != null
          ? TimeOfDay.fromDateTime(item.dueDate!)
          : const TimeOfDay(hour: 9, minute: 0),
      minimumDateTime: now,
    );
    if (pickedTime != null) {
      _updateState(() {
        item.dueDate = DateTime(
          now.year,
          now.month,
          now.day,
          pickedTime.hour,
          pickedTime.minute,
        );
      });
      _saveData();
      NotificationService().scheduleNotification(item, s.notificationTiming);
    }
  }
}
