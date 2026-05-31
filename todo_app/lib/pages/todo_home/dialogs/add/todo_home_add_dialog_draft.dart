part of '../../../../main.dart';

class _AddTodoDraft {
  _AddTodoDraft({required bool isFromTodayTab})
    : selectedDate = isFromTodayTab ? _endOfToday() : null;

  final textController = TextEditingController();
  final descriptionController = TextEditingController();
  DateTime? selectedDate;
  List<String> selectedImageBase64List = <String>[];
  String? selectedTaskTag;
  RecurrenceRule selectedRecurrenceRule = RecurrenceRule.none;
  TaskPriority selectedTaskPriority = TaskPriority.none;

  static DateTime _endOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 23, 59);
  }
}
