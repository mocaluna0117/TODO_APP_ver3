part of '../main.dart';

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

TaskPriority normalizeTaskPriority(Object? value) {
  final rawValue = value?.toString();
  if (rawValue == null || rawValue.isEmpty) return TaskPriority.none;
  for (final p in TaskPriority.values) {
    if (rawValue == p.name || rawValue == p.index.toString()) return p;
  }
  return TaskPriority.none;
}

// 全体設定の NotificationTiming を「期限までの分数」に変換する。
int notificationTimingToMinutes(NotificationTiming timing) {
  switch (timing) {
    case NotificationTiming.atTime:
    case NotificationTiming.none:
      return 0;
    case NotificationTiming.minutes10:
      return 10;
    case NotificationTiming.hour1:
      return 60;
    case NotificationTiming.day1:
      return 1440;
  }
}

// タスク固有の通知タイミング（期限までの分数のリスト）を正規化する。
// キーが存在しない（旧データ）場合は null を返し、全体のデフォルト通知に従わせる。
// 旧形式（NotificationTiming の name 配列）からの移行にも対応する。
List<int>? normalizeNotificationOffsets(Map<String, dynamic> json) {
  final raw = json['notificationOffsets'];
  if (raw is List) {
    final result = <int>[];
    for (final value in raw) {
      final minutes = value is int
          ? value
          : int.tryParse(value?.toString() ?? '');
      if (minutes != null && minutes >= 0 && !result.contains(minutes)) {
        result.add(minutes);
      }
    }
    result.sort();
    return result;
  }

  // 旧形式（notificationTimings: NotificationTiming の name 配列）からの移行
  final legacy = json['notificationTimings'];
  if (legacy is List) {
    final result = <int>[];
    for (final value in legacy) {
      final rawValue = value?.toString();
      if (rawValue == null || rawValue.isEmpty) continue;
      for (final timing in NotificationTiming.values) {
        if (timing == NotificationTiming.none) continue;
        if (rawValue == timing.name || rawValue == timing.index.toString()) {
          final minutes = notificationTimingToMinutes(timing);
          if (!result.contains(minutes)) result.add(minutes);
          break;
        }
      }
    }
    result.sort();
    return result;
  }

  return null;
}

// リンク一覧を正規化する（前後空白除去・空文字除外・重複除外、順序は保持）。
List<String> normalizeLinkList(Iterable<Object?> values) {
  final result = <String>[];
  for (final value in values) {
    final link = value?.toString().trim();
    if (link != null && link.isNotEmpty && !result.contains(link)) {
      result.add(link);
    }
  }
  return result;
}

// JSON からリンク一覧を取り出す。旧形式（単一 'link'）からの移行にも対応。
List<String> _linksFromJson(Map<String, dynamic> json) {
  final raw = json['links'];
  if (raw is List) return normalizeLinkList(raw);
  final legacy = json['link'];
  if (legacy != null) return normalizeLinkList([legacy]);
  return const [];
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
// タスクに添付したファイル（PDF）
//
// 実体は Firebase Storage に置き、タスクには URL と表示名だけを持たせる。
// 画像のように base64 で持つと Firestore の1ドキュメント1MB制限に掛かるため。
// ─────────────────────────────────────────────
class TaskFile {
  const TaskFile({required this.url, required this.name});

  final String url;
  final String name;

  Map<String, dynamic> toJson() => {'url': url, 'name': name};

  static TaskFile? fromJson(Object? value) {
    if (value is! Map) return null;
    final url = value['url']?.toString();
    if (url == null || url.isEmpty) return null;
    final name = value['name']?.toString();
    return TaskFile(
      url: url,
      name: (name == null || name.isEmpty) ? 'ファイル' : name,
    );
  }
}

// まだアップロードしていない添付ファイル。保存時に Storage へ送るまで
// メモリ上だけで持ち、JSON には出さない（Firestore に実体を入れないため）。
class PendingTaskFile {
  const PendingTaskFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

List<TaskFile> taskFilesFromJson(Object? value) {
  if (value is! List) return [];
  final files = <TaskFile>[];
  for (final raw in value) {
    final file = TaskFile.fromJson(raw);
    if (file != null) files.add(file);
  }
  return files;
}

// ─────────────────────────────────────────────
// TODOアイテムのデータモデル
// ─────────────────────────────────────────────
class TodoItem {
  final int id;
  String title;
  String? description;
  List<String> links;
  bool isDone;
  // category: 'todo' = やること, 'done' = 完了済み, 'future' = 今後やりたいこと
  String category;
  String? taskTag;
  DateTime? dueDate;
  // 繰り返し設定。null は繰り返しなし。
  Recurrence? recurrence;
  List<String> imageBase64List;
  // 添付ファイル（PDF）。attachments は保存済み、pendingFiles は
  // まだアップロードしていないもの（保存時に Storage へ送る）。
  List<TaskFile> attachments;
  List<PendingTaskFile> pendingFiles;
  TaskPriority priority;
  DateTime? completedAt;
  // ゴミ箱に入れた日時。null は通常のタスク。
  // 一定期間（kTrashRetention）を過ぎたものは自動で完全削除される。
  DateTime? deletedAt;
  // タスクごとの通知タイミング（期限までの分数のリスト）。
  // null は未設定（全体のデフォルトに従う）、空リストは「通知しない」、
  // 複数要素は複数件の通知を表す。0 = 期限の時間、任意の値でカスタム設定可。
  List<int>? notificationOffsets;

  TodoItem({
    int? id,
    required this.title,
    this.description,
    List<String>? links,
    this.isDone = false,
    this.category = 'todo',
    this.taskTag,
    this.dueDate,
    this.recurrence,
    List<String>? imageBase64List,
    List<TaskFile>? attachments,
    List<PendingTaskFile>? pendingFiles,
    this.priority = TaskPriority.none,
    this.completedAt,
    this.deletedAt,
    this.notificationOffsets,
  }) : imageBase64List = imageBase64List ?? [],
       attachments = attachments ?? [],
       pendingFiles = pendingFiles ?? [],
       links = normalizeLinkList(links ?? const []),
       id = id ?? (DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF);

  bool get isRecurring => recurrence != null;

  // ゴミ箱に入っているか
  bool get isDeleted => deletedAt != null;

  bool get isOverdue =>
      dueDate != null &&
      !isDone &&
      dueDate!.isBefore(DateTime.now().copyWith(hour: 0, minute: 0, second: 0));

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'links': links,
    'isDone': isDone,
    'category': category,
    'taskTag': taskTag,
    'dueDate': dueDate?.toIso8601String(),
    'recurrence': recurrence?.toJson(),
    'imageBase64List': imageBase64List,
    'attachments': attachments.map((file) => file.toJson()).toList(),
    'priority': priority.name,
    'completedAt': completedAt?.toIso8601String(),
    'deletedAt': deletedAt?.toIso8601String(),
    'notificationOffsets': notificationOffsets,
  };

  factory TodoItem.fromJson(Map<String, dynamic> json) => TodoItem(
    id: (json['id'] as int) & 0x7FFFFFFF,
    title: json['title'],
    description: json['description'],
    links: _linksFromJson(json),
    isDone: json['isDone'] ?? false,
    category: json['category'] ?? 'todo',
    taskTag: normalizeTaskTag(json['taskTag'] ?? json['taskCategory']),
    dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
    // 旧形式（recurrenceRule）で保存されたタスクはここで新形式へ移行する
    recurrence:
        Recurrence.fromJson(json['recurrence']) ??
        recurrenceFromLegacyRule(json['recurrenceRule']),
    imageBase64List: normalizeImageBase64List(json),
    attachments: taskFilesFromJson(json['attachments']),
    priority: normalizeTaskPriority(json['priority']),
    completedAt: json['completedAt'] != null
        ? DateTime.parse(json['completedAt'])
        : null,
    deletedAt: json['deletedAt'] != null
        ? DateTime.parse(json['deletedAt'])
        : null,
    notificationOffsets: normalizeNotificationOffsets(json),
  );
}
