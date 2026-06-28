part of '../../../../main.dart';

class _AddTodoDraft {
  _AddTodoDraft({
    required bool isFromTodayTab,
    required List<int> defaultNotificationOffsets,
  }) : selectedDate = isFromTodayTab ? _endOfToday() : null,
       selectedNotificationOffsets = [...defaultNotificationOffsets];

  final textController = TextEditingController();
  final descriptionController = TextEditingController();
  final List<TextEditingController> linkControllers = [];
  DateTime? selectedDate;
  List<String> selectedImageBase64List = <String>[];
  String? selectedTaskTag;
  RecurrenceRule selectedRecurrenceRule = RecurrenceRule.none;
  TaskPriority selectedTaskPriority = TaskPriority.none;
  List<int> selectedNotificationOffsets;

  static DateTime _endOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 23, 59);
  }
}
