part of '../../../../main.dart';

class _EditTodoDraft {
  _EditTodoDraft(TodoItem item)
    : textController = TextEditingController(text: item.title),
      descriptionController = TextEditingController(
        text: item.description ?? '',
      ),
      selectedDate = item.dueDate,
      selectedImageBase64List = [...item.imageBase64List],
      selectedTaskTag = item.taskTag,
      selectedRecurrenceRule = item.recurrenceRule,
      selectedTaskPriority = item.priority;

  final TextEditingController textController;
  final TextEditingController descriptionController;
  DateTime? selectedDate;
  List<String> selectedImageBase64List;
  String? selectedTaskTag;
  RecurrenceRule selectedRecurrenceRule;
  TaskPriority selectedTaskPriority;
}
