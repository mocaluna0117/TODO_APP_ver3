part of '../../../../main.dart';

class _EditTodoDraft {
  _EditTodoDraft(
    TodoItem item, {
    required List<int> defaultNotificationOffsets,
  }) : textController = TextEditingController(text: item.title),
       descriptionController = TextEditingController(
         text: item.description ?? '',
       ),
       linkControllers = item.links
           .map((l) => TextEditingController(text: l))
           .toList(),
       selectedDate = item.dueDate,
       selectedImageBase64List = [...item.imageBase64List],
       selectedFiles = [...item.attachments],
       pendingFiles = [...item.pendingFiles],
       selectedTaskTag = item.taskTag,
       selectedRecurrence = item.recurrence,
       selectedTaskPriority = item.priority,
       // タスク固有の設定があればそれを、無ければ既定の通知タイミングを初期値にする
       selectedNotificationOffsets = item.notificationOffsets != null
           ? [...item.notificationOffsets!]
           : [...defaultNotificationOffsets];

  final TextEditingController textController;
  final TextEditingController descriptionController;
  final List<TextEditingController> linkControllers;
  DateTime? selectedDate;
  List<String> selectedImageBase64List;
  List<TaskFile> selectedFiles;
  List<PendingTaskFile> pendingFiles;
  bool isProcessingImage = false;
  String? selectedTaskTag;
  Recurrence? selectedRecurrence;
  TaskPriority selectedTaskPriority;
  List<int> selectedNotificationOffsets;
}
