part of '../../../../main.dart';

class _AddTodoDraft {
  _AddTodoDraft({
    required DateTime? fixedDay,
    required List<int> defaultNotificationOffsets,
  }) : selectedDate = fixedDay == null ? null : _endOfDay(fixedDay),
       selectedNotificationOffsets = [...defaultNotificationOffsets];

  final textController = TextEditingController();
  final descriptionController = TextEditingController();
  final List<TextEditingController> linkControllers = [];
  DateTime? selectedDate;
  List<String> selectedImageBase64List = <String>[];
  List<TaskFile> selectedFiles = <TaskFile>[];
  List<PendingTaskFile> pendingFiles = <PendingTaskFile>[];
  bool isProcessingImage = false;
  String? selectedTaskTag;
  Recurrence? selectedRecurrence;
  TaskPriority selectedTaskPriority = TaskPriority.none;
  List<int> selectedNotificationOffsets;

  // 日付が決まっているタブから追加する場合は、その日の終わり（23:59）を初期値にする
  static DateTime _endOfDay(DateTime day) =>
      DateTime(day.year, day.month, day.day, 23, 59);
}
