part of '../main.dart';

enum RecurrenceRule {
  none('なし'),
  daily('毎日'),
  weekly('毎週'),
  monthly('毎月');

  final String label;
  const RecurrenceRule(this.label);
}

enum TaskPriority {
  none('なし'),
  low('低'),
  medium('中'),
  high('高');

  final String label;
  const TaskPriority(this.label);
}

Color priorityColor(TaskPriority priority) {
  switch (priority) {
    case TaskPriority.high:
      return Colors.amber.shade700;
    case TaskPriority.medium:
      return Colors.amber.shade600;
    case TaskPriority.low:
      return Colors.amber.shade500;
    case TaskPriority.none:
      return Colors.grey;
  }
}

int priorityStarCount(TaskPriority priority) {
  switch (priority) {
    case TaskPriority.high:
      return 3;
    case TaskPriority.medium:
      return 2;
    case TaskPriority.low:
      return 1;
    case TaskPriority.none:
      return 0;
  }
}

TaskPriority priorityFromStarCount(int count) {
  switch (count) {
    case 3:
      return TaskPriority.high;
    case 2:
      return TaskPriority.medium;
    case 1:
      return TaskPriority.low;
    default:
      return TaskPriority.none;
  }
}

String? normalizeTaskTag(Object? value) {
  final tag = value?.toString().trim();
  if (tag == null || tag.isEmpty) return null;
  return tag;
}

RecurrenceRule normalizeRecurrenceRule(Object? value) {
  final rawValue = value?.toString();
  if (rawValue == null || rawValue.isEmpty) return RecurrenceRule.none;
  for (final rule in RecurrenceRule.values) {
    if (rawValue == rule.name || rawValue == rule.index.toString()) {
      return rule;
    }
  }
  return RecurrenceRule.none;
}

TaskPriority normalizeTaskPriority(Object? value) {
  final rawValue = value?.toString();
  if (rawValue == null || rawValue.isEmpty) return TaskPriority.none;
  for (final p in TaskPriority.values) {
    if (rawValue == p.name || rawValue == p.index.toString()) return p;
  }
  return TaskPriority.none;
}

List<String> normalizeImageBase64List(Map<String, dynamic> json) {
  final images = <String>[];
  final imageList = json['imageBase64List'];
  if (imageList is List) {
    for (final image in imageList) {
      final value = image?.toString();
      if (value != null && value.isNotEmpty) {
        images.add(value);
      }
    }
  }

  final legacyImage = json['imageBase64'] ?? json['picture'];
  if (legacyImage != null) {
    final value = legacyImage.toString();
    if (value.isNotEmpty && !images.contains(value)) {
      images.add(value);
    }
  }

  return images;
}

// ─────────────────────────────────────────────
// TODOアイテムのデータモデル
// ─────────────────────────────────────────────
class TodoItem {
  final int id;
  String title;
  String? description;
  bool isDone;
  // category: 'todo' = やること, 'done' = 完了済み, 'future' = 今後やりたいこと
  String category;
  String? taskTag;
  DateTime? dueDate;
  RecurrenceRule recurrenceRule;
  List<String> imageBase64List;
  TaskPriority priority;

  TodoItem({
    int? id,
    required this.title,
    this.description,
    this.isDone = false,
    this.category = 'todo',
    this.taskTag,
    this.dueDate,
    this.recurrenceRule = RecurrenceRule.none,
    List<String>? imageBase64List,
    this.priority = TaskPriority.none,
  }) : imageBase64List = imageBase64List ?? [],
       id = id ?? (DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF);

  bool get isRecurring => recurrenceRule != RecurrenceRule.none;

  bool get isOverdue =>
      dueDate != null &&
      !isDone &&
      dueDate!.isBefore(DateTime.now().copyWith(hour: 0, minute: 0, second: 0));

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'isDone': isDone,
    'category': category,
    'taskTag': taskTag,
    'dueDate': dueDate?.toIso8601String(),
    'recurrenceRule': recurrenceRule.name,
    'imageBase64List': imageBase64List,
    'priority': priority.name,
  };

  factory TodoItem.fromJson(Map<String, dynamic> json) => TodoItem(
    id: (json['id'] as int) & 0x7FFFFFFF,
    title: json['title'],
    description: json['description'],
    isDone: json['isDone'] ?? false,
    category: json['category'] ?? 'todo',
    taskTag: normalizeTaskTag(json['taskTag'] ?? json['taskCategory']),
    dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
    recurrenceRule: normalizeRecurrenceRule(json['recurrenceRule']),
    imageBase64List: normalizeImageBase64List(json),
    priority: normalizeTaskPriority(json['priority']),
  );
}
