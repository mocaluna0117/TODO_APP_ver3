import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'app_settings.dart';
import 'settings_page.dart';
import 'notification_service.dart';

const String allTaskCategoriesLabel = 'すべて';
const String noTaskTagLabel = 'タグなし';

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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
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

// ─────────────────────────────────────────────
// アプリ本体（StatefulWidget でテーマ変更対応）
// ─────────────────────────────────────────────
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AppSettings _settings = AppSettings();
  bool _isSettingsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _settings.loadFromPrefs();
    setState(() {
      _isSettingsLoaded = true;
    });
  }

  void _onSettingsChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    if (!_isSettingsLoaded) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      title: _settings.appTitle,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ja')],
      locale: const Locale('ja'),
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF5F5FA),
        appBarTheme: AppBarTheme(
          backgroundColor: _settings.primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        tabBarTheme: const TabBarThemeData(
          labelColor: Colors.white,
          unselectedLabelColor: Color(0xAAFFFFFF),
          indicatorColor: Colors.white,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: _settings.accentColor,
          foregroundColor: Colors.white,
        ),
      ),
      home: TodoHomePage(
        settings: _settings,
        onSettingsChanged: _onSettingsChanged,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ホームページ（タブ管理）
// ─────────────────────────────────────────────
class TodoHomePage extends StatefulWidget {
  final AppSettings settings;
  final VoidCallback onSettingsChanged;

  const TodoHomePage({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
  });

  @override
  State<TodoHomePage> createState() => _TodoHomePageState();
}

class _TodoHomePageState extends State<TodoHomePage>
    with TickerProviderStateMixin {
  TabController? _tabController;
  final List<TodoItem> _allItems = [];
  final ImagePicker _imagePicker = ImagePicker();
  String _selectedTaskTagFilter = allTaskCategoriesLabel;
  final Set<int> _fadingOutItems = {};

  AppSettings get s => widget.settings;

  // 有効なタブのカテゴリキーリスト
  List<String> get _activeTabKeys {
    final keys = <String>['todo'];
    if (s.showTodayTab) keys.add('today');
    if (s.showDoneTab) keys.add('done');
    if (s.showFutureTab) keys.add('future');
    return keys;
  }

  @override
  void initState() {
    super.initState();
    _rebuildTabController();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? itemsJson = prefs.getString('todo_items');
    if (itemsJson != null) {
      final List<dynamic> decodedList = jsonDecode(itemsJson);
      setState(() {
        _allItems.clear();
        _allItems.addAll(decodedList.map((e) => TodoItem.fromJson(e)).toList());
        _removeUnknownTaskTags();
      });
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final String itemsJson = jsonEncode(
      _allItems.map((e) => e.toJson()).toList(),
    );
    await prefs.setString('todo_items', itemsJson);
  }

  @override
  void didUpdateWidget(covariant TodoHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // タブ数が変わったらコントローラを再生成
    if (_tabController == null ||
        _tabController!.length != _activeTabKeys.length) {
      _rebuildTabController();
    }
  }

  void _rebuildTabController() {
    _tabController?.dispose();
    _tabController = TabController(length: _activeTabKeys.length, vsync: this);
    _tabController!.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  // タブキーからタブ名を取得
  String _tabName(String key) {
    switch (key) {
      case 'todo':
        return s.todoTabName;
      case 'today':
        return s.todayTabName;
      case 'done':
        return s.doneTabName;
      case 'future':
        return s.futureTabName;
      default:
        return key;
    }
  }

  // カテゴリ別フィルタ（設定された並び順でソート）
  List<TodoItem> _itemsByCategory(String category) {
    final items = switch (category) {
      'done' => _allItems.where((item) => item.isDone).toList(),
      'today' =>
        _allItems
            .where((item) => !item.isDone && _isDueTodayOrOverdue(item))
            .toList(),
      _ =>
        _allItems
            .where((item) => item.category == category && !item.isDone)
            .toList(),
    };

    if (_selectedTaskTagFilter != allTaskCategoriesLabel) {
      items.removeWhere((item) => item.taskTag != _selectedTaskTagFilter);
    }

    items.sort((a, b) {
      if (a.dueDate == null && b.dueDate == null) return 0;
      if (a.dueDate == null) return 1;
      if (b.dueDate == null) return -1;
      return s.sortOrder == SortOrder.dueDateAsc
          ? a.dueDate!.compareTo(b.dueDate!)
          : b.dueDate!.compareTo(a.dueDate!);
    });
    return items;
  }

  bool _isDueTodayOrOverdue(TodoItem item) {
    final dueDate = item.dueDate;
    if (dueDate == null) return false;
    final now = DateTime.now();
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    return !dueDate.isAfter(endOfToday);
  }

  // 現在のタブのカテゴリキー
  String get _currentTabKey => _activeTabKeys[_tabController!.index];

  // ─── アイテム追加ダイアログ ───
  void _showAddDialog() {
    final textController = TextEditingController();
    final descriptionController = TextEditingController();
    final isFromTodayTab = _currentTabKey == 'today';
    final category = _currentTabKey == 'done' || isFromTodayTab
        ? 'todo'
        : _currentTabKey;
    DateTime? selectedDate;
    var selectedImageBase64List = <String>[];
    String? selectedTaskTag;
    var selectedRecurrenceRule = RecurrenceRule.none;
    var selectedTaskPriority = TaskPriority.none;

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final mediaQuery = MediaQuery.of(context);
            final topInset = mediaQuery.padding.top;
            final keyboardInset = mediaQuery.viewInsets.bottom;
            final topOffset = topInset + 4;
            final bottomGap = keyboardInset > 0 ? 20.0 : 16.0;
            final maxModalHeight =
                (mediaQuery.size.height - topOffset - keyboardInset - bottomGap)
                    .clamp(240.0, mediaQuery.size.height * 0.8);
            void submit() {
              _addItem(
                textController.text,
                category,
                description: descriptionController.text,
                taskTag: selectedTaskTag,
                dueDate: selectedDate,
                recurrenceRule: selectedRecurrenceRule,
                imageBase64List: selectedImageBase64List,
                priority: selectedTaskPriority,
              );
              Navigator.pop(context);
            }

            return Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(
                  top: topOffset,
                  left: 16,
                  right: 16,
                  bottom: keyboardInset + bottomGap,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxModalHeight),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Flexible(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    '${_tabName(category)}を追加',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: s.primaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: textController,
                                    autofocus: true,
                                    keyboardType: TextInputType.text,
                                    textInputAction: TextInputAction.next,
                                    hintLocales: const [Locale('ja', 'JP')],
                                    decoration: InputDecoration(
                                      hintText: 'タスクを入力...',
                                      filled: true,
                                      fillColor: const Color(0xFFF5F5FA),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 14,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: descriptionController,
                                    keyboardType: TextInputType.multiline,
                                    textInputAction: TextInputAction.done,
                                    hintLocales: const [Locale('ja', 'JP')],
                                    minLines: 1,
                                    maxLines: 4,
                                    onSubmitted: (_) => submit(),
                                    decoration: InputDecoration(
                                      hintText: '概要を入力（任意）',
                                      filled: true,
                                      fillColor: const Color(0xFFF5F5FA),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding: const EdgeInsets.all(16),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildTaskTagPicker(
                                    selectedTaskTag: selectedTaskTag,
                                    onChanged: (tag) => setSheetState(
                                      () => selectedTaskTag = tag,
                                    ),
                                  ),
                                  if (category == 'future') ...[
                                    const SizedBox(height: 12),
                                    _buildTaskPriorityPicker(
                                      selectedTaskPriority:
                                          selectedTaskPriority,
                                      onChanged: (p) => setSheetState(
                                        () => selectedTaskPriority = p,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  if (isFromTodayTab)
                                    _buildTimeOnlyPickerRow(
                                      selectedDate: selectedDate,
                                      onTimeSelected: (date) => setSheetState(
                                        () => selectedDate = date,
                                      ),
                                      onTimeCleared: () => setSheetState(
                                        () => selectedDate = null,
                                      ),
                                    )
                                  else
                                    _buildDatePickerRow(
                                      selectedDate: selectedDate,
                                      onDateSelected: (date) => setSheetState(
                                        () => selectedDate = date,
                                      ),
                                      onDateCleared: () => setSheetState(
                                        () => selectedDate = null,
                                      ),
                                    ),
                                  if (!isFromTodayTab) ...[
                                    const SizedBox(height: 12),
                                    _buildRecurrencePicker(
                                      selectedRecurrenceRule:
                                          selectedRecurrenceRule,
                                      onChanged: (rule) => setSheetState(
                                        () => selectedRecurrenceRule = rule,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  _buildImagePickerRow(
                                    imageBase64List: selectedImageBase64List,
                                    onImagesChanged: (imageBase64List) =>
                                        setSheetState(
                                          () => selectedImageBase64List =
                                              imageBase64List,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: s.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              '追加',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<List<String>> _pickImageBase64List() async {
    final pickedImages = await _imagePicker.pickMultiImage(
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (pickedImages.isEmpty) return [];

    final encodedImages = <String>[];
    for (final pickedImage in pickedImages) {
      final bytes = await pickedImage.readAsBytes();
      encodedImages.add(base64Encode(bytes));
    }
    return encodedImages;
  }

  Uint8List? _decodeImage(String? imageBase64) {
    if (imageBase64 == null || imageBase64.isEmpty) return null;
    try {
      return base64Decode(imageBase64);
    } on FormatException {
      return null;
    }
  }

  List<Uint8List> _decodeImages(List<String> imageBase64List) {
    return imageBase64List
        .map(_decodeImage)
        .whereType<Uint8List>()
        .toList(growable: false);
  }

  void _showImagePreview(Uint8List imageBytes) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: SafeArea(
          child: Dismissible(
            key: const ValueKey('image-preview'),
            direction: DismissDirection.vertical,
            onDismissed: (_) => Navigator.pop(context),
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.pop(context),
                    child: Center(
                      child: InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 4,
                        child: GestureDetector(
                          onTap: () {},
                          child: Image.memory(
                            imageBytes,
                            fit: BoxFit.contain,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      tooltip: '閉じる',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 20,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: s.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                        side: const BorderSide(color: Colors.white24),
                      ),
                      elevation: 4,
                    ),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.keyboard_arrow_down),
                    label: const Text('閉じる'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── 期限選択行ウィジェット ───
  Widget _buildDatePickerRow({
    required DateTime? selectedDate,
    required ValueChanged<DateTime> onDateSelected,
    required VoidCallback onDateCleared,
  }) {
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final pickedDate = await showDatePicker(
          context: context,
          initialDate: selectedDate != null && selectedDate.isAfter(now)
              ? selectedDate
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
            selectedDate != null
                ? TimeOfDay.fromDateTime(selectedDate)
                : const TimeOfDay(hour: 9, minute: 0),
            minimumDateTime: isToday ? now : null,
          );
          if (pickedTime != null) {
            onDateSelected(
              DateTime(
                pickedDate.year,
                pickedDate.month,
                pickedDate.day,
                pickedTime.hour,
                pickedTime.minute,
              ),
            );
          }
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5FA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 18, color: s.primaryColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                selectedDate != null
                    ? DateFormat(
                        'yyyy/MM/dd (E) HH:mm',
                        'ja',
                      ).format(selectedDate)
                    : '期限を設定（任意）',
                style: TextStyle(
                  fontSize: 15,
                  color: selectedDate != null ? Colors.black87 : Colors.grey,
                ),
              ),
            ),
            if (selectedDate != null)
              GestureDetector(
                onTap: onDateCleared,
                child: Icon(Icons.close, size: 18, color: Colors.grey.shade400),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeOnlyPickerRow({
    required DateTime? selectedDate,
    required ValueChanged<DateTime> onTimeSelected,
    required VoidCallback onTimeCleared,
  }) {
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final pickedTime = await _pickDueTime(
          selectedDate != null
              ? TimeOfDay.fromDateTime(selectedDate)
              : const TimeOfDay(hour: 9, minute: 0),
          minimumDateTime: now,
        );
        if (pickedTime != null) {
          final today = now;
          onTimeSelected(
            DateTime(
              today.year,
              today.month,
              today.day,
              pickedTime.hour,
              pickedTime.minute,
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5FA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time, size: 18, color: s.primaryColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                selectedDate != null
                    ? DateFormat('HH:mm').format(selectedDate)
                    : '時間を設定（任意）',
                style: TextStyle(
                  fontSize: 15,
                  color: selectedDate != null ? Colors.black87 : Colors.grey,
                ),
              ),
            ),
            if (selectedDate != null)
              GestureDetector(
                onTap: onTimeCleared,
                child: Icon(Icons.close, size: 18, color: Colors.grey.shade400),
              ),
          ],
        ),
      ),
    );
  }

  Future<TimeOfDay?> _pickDueTime(
    TimeOfDay initialTime, {
    DateTime? minimumDateTime,
  }) {
    // When a minimum exists, snap the initial time forward if it's already past
    TimeOfDay effectiveInitial = initialTime;
    if (minimumDateTime != null) {
      final minMins = minimumDateTime.hour * 60 + minimumDateTime.minute + 1;
      final initMins = initialTime.hour * 60 + initialTime.minute;
      if (initMins < minMins) {
        effectiveInitial = TimeOfDay(
          hour: (minMins ~/ 60) % 24,
          minute: minMins % 60,
        );
      }
    }

    final initialDateTime = DateTime(
      2000,
      1,
      1,
      effectiveInitial.hour,
      effectiveInitial.minute,
    );
    var selectedDateTime = initialDateTime;

    bool isValidTime(DateTime dt) {
      if (minimumDateTime == null) return true;
      final selMins = dt.hour * 60 + dt.minute;
      final minMins = minimumDateTime.hour * 60 + minimumDateTime.minute + 1;
      return selMins >= minMins;
    }

    return showModalBottomSheet<TimeOfDay>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setPickerState) {
            final isValid = isValidTime(selectedDateTime);
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 56,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
                          '時刻を選択',
                          style: TextStyle(
                            color: s.primaryColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            CupertinoButton(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              onPressed: () => Navigator.pop(context),
                              child: const Text(
                                'キャンセル',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                            CupertinoButton(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              onPressed: isValid
                                  ? () => Navigator.pop(
                                      context,
                                      TimeOfDay.fromDateTime(selectedDateTime),
                                    )
                                  : null,
                              child: Text(
                                '決定',
                                style: TextStyle(
                                  color: isValid ? s.primaryColor : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!isValid)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '現在時刻より前の時刻は設定できません',
                        style: TextStyle(
                          color: Colors.red.shade400,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  Divider(height: 1, color: Colors.grey.shade200),
                  SizedBox(
                    height: 216,
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.time,
                      initialDateTime: initialDateTime,
                      use24hFormat: true,
                      minuteInterval: 1,
                      onDateTimeChanged: (dateTime) {
                        selectedDateTime = dateTime;
                        setPickerState(() {});
                      },
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildImagePickerRow({
    required List<String> imageBase64List,
    required ValueChanged<List<String>> onImagesChanged,
  }) {
    final imageBytesList = _decodeImages(imageBase64List);

    return InkWell(
      onTap: () async {
        try {
          final pickedImageBase64List = await _pickImageBase64List();
          if (pickedImageBase64List.isNotEmpty) {
            onImagesChanged([...imageBase64List, ...pickedImageBase64List]);
          }
        } catch (_) {
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('画像を選択できませんでした')));
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5FA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (imageBytesList.isNotEmpty) ...[
              SizedBox(
                height: 320,
                child: PageView.builder(
                  itemCount: imageBytesList.length,
                  itemBuilder: (context, index) {
                    final imageBytes = imageBytesList[index];
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: GestureDetector(
                            onTap: () => _showImagePreview(imageBytes),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                imageBytes,
                                width: double.infinity,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints.tightFor(
                                width: 34,
                                height: 34,
                              ),
                              padding: EdgeInsets.zero,
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 18,
                              ),
                              tooltip: 'この画像を削除',
                              onPressed: () {
                                final nextImages = [...imageBase64List]
                                  ..removeAt(index);
                                onImagesChanged(nextImages);
                              },
                            ),
                          ),
                        ),
                        if (imageBytesList.length > 1)
                          Positioned(
                            left: 8,
                            bottom: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${index + 1}/${imageBytesList.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Icon(Icons.image_outlined, size: 20, color: s.primaryColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    imageBytesList.isNotEmpty
                        ? '画像を追加（${imageBytesList.length}枚）'
                        : '画像を添付（任意）',
                    style: TextStyle(
                      fontSize: 15,
                      color: imageBytesList.isNotEmpty
                          ? Colors.black87
                          : Colors.grey,
                    ),
                  ),
                ),
                if (imageBytesList.isNotEmpty)
                  GestureDetector(
                    onTap: () => onImagesChanged([]),
                    child: Icon(
                      Icons.close,
                      size: 18,
                      color: Colors.grey.shade400,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskTagPicker({
    required String? selectedTaskTag,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: selectedTaskTag ?? noTaskTagLabel,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'タグ',
        prefixIcon: Icon(Icons.label_outline, color: s.primaryColor),
        filled: true,
        fillColor: const Color(0xFFF5F5FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      items: [
        noTaskTagLabel,
        ...s.taskTags,
      ].map((tag) => DropdownMenuItem(value: tag, child: Text(tag))).toList(),
      onChanged: (tag) {
        if (tag != null) {
          onChanged(tag == noTaskTagLabel ? null : tag);
        }
      },
    );
  }

  Widget _buildRecurrencePicker({
    required RecurrenceRule selectedRecurrenceRule,
    required ValueChanged<RecurrenceRule> onChanged,
  }) {
    return DropdownButtonFormField<RecurrenceRule>(
      initialValue: selectedRecurrenceRule,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: '繰り返し',
        prefixIcon: Icon(Icons.repeat, color: s.primaryColor),
        filled: true,
        fillColor: const Color(0xFFF5F5FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      items: RecurrenceRule.values
          .map((rule) => DropdownMenuItem(value: rule, child: Text(rule.label)))
          .toList(),
      onChanged: (rule) {
        if (rule != null) {
          onChanged(rule);
        }
      },
    );
  }

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

  void _addItem(
    String title,
    String category, {
    String? description,
    String? taskTag,
    DateTime? dueDate,
    RecurrenceRule recurrenceRule = RecurrenceRule.none,
    List<String> imageBase64List = const [],
    TaskPriority priority = TaskPriority.none,
  }) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    final newItem = TodoItem(
      title: trimmed,
      description: _normalizeOptionalText(description),
      category: category,
      taskTag: _normalizeKnownTaskTag(taskTag),
      dueDate: dueDate,
      recurrenceRule: recurrenceRule,
      imageBase64List: imageBase64List,
      priority: priority,
    );
    setState(() {
      _allItems.add(newItem);
    });
    _saveData();
    NotificationService().scheduleNotification(newItem, s.notificationTiming);
  }

  // ─── カードから直接期限を変更 ───
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
        setState(() {
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
      setState(() {
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

  void _completeItemWithFade(TodoItem item) {
    // 繰り返しタスク・完了済み→未完了はアニメーション不要
    if (item.isDone || (item.isRecurring && item.dueDate != null)) {
      _toggleItem(item);
      return;
    }
    setState(() => _fadingOutItems.add(item.id));
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _fadingOutItems.remove(item.id));
      _toggleItem(item);
    });
  }

  void _toggleItem(TodoItem item) {
    if (!item.isDone && item.isRecurring && item.dueDate != null) {
      late final DateTime nextDueDate;
      setState(() {
        nextDueDate = _nextRecurringDueDate(item.dueDate!, item.recurrenceRule);
        item.dueDate = nextDueDate;
      });
      _saveData();
      NotificationService().scheduleNotification(item, s.notificationTiming);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '次回: ${DateFormat('yyyy/MM/dd (E) HH:mm', 'ja').format(nextDueDate)} に更新しました',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      item.isDone = !item.isDone;
    });
    _saveData();
    if (item.isDone) {
      NotificationService().cancelNotification(item.id);
    } else {
      NotificationService().scheduleNotification(item, s.notificationTiming);
    }
  }

  DateTime _nextRecurringDueDate(DateTime dueDate, RecurrenceRule rule) {
    var nextDate = dueDate;
    final now = DateTime.now();
    do {
      nextDate = _addRecurrenceInterval(nextDate, rule);
    } while (!nextDate.isAfter(now));
    return nextDate;
  }

  DateTime _addRecurrenceInterval(DateTime date, RecurrenceRule rule) {
    switch (rule) {
      case RecurrenceRule.daily:
        return date.add(const Duration(days: 1));
      case RecurrenceRule.weekly:
        return date.add(const Duration(days: 7));
      case RecurrenceRule.monthly:
        return _addMonthsClamped(date, 1);
      case RecurrenceRule.none:
        return date;
    }
  }

  DateTime _addMonthsClamped(DateTime date, int months) {
    final targetMonthIndex = date.month - 1 + months;
    final targetYear = date.year + targetMonthIndex ~/ 12;
    final targetMonth = targetMonthIndex % 12 + 1;
    final targetDay = date.day.clamp(
      1,
      DateUtils.getDaysInMonth(targetYear, targetMonth),
    );
    return DateTime(
      targetYear,
      targetMonth,
      targetDay,
      date.hour,
      date.minute,
      date.second,
      date.millisecond,
      date.microsecond,
    );
  }

  String _formatTodoCardDueDate(DateTime dueDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final timeText = DateFormat('HH:mm').format(dueDate);

    if (dueDate.isBefore(now)) {
      return DateFormat('M/d(E) HH:mm', 'ja').format(dueDate);
    }
    if (dueDay == today) {
      return '今日 $timeText';
    }
    if (dueDay == tomorrow) {
      return '明日 $timeText';
    }
    return DateFormat('M/d(E) HH:mm', 'ja').format(dueDate);
  }

  void _deleteItem(TodoItem item) {
    setState(() {
      _allItems.remove(item);
    });
    _saveData();
    NotificationService().cancelNotification(item.id);
  }

  String? _normalizeKnownTaskTag(String? tag) {
    final normalized = normalizeTaskTag(tag);
    if (normalized == null || !s.taskTags.contains(normalized)) return null;
    return normalized;
  }

  void _renameTaskTag(String oldTag, String newTag) {
    setState(() {
      for (final item in _allItems) {
        if (item.taskTag == oldTag) {
          item.taskTag = newTag;
        }
      }
      if (_selectedTaskTagFilter == oldTag) {
        _selectedTaskTagFilter = newTag;
      }
    });
    _saveData();
  }

  void _deleteTaskTag(String tag) {
    setState(() {
      for (final item in _allItems) {
        if (item.taskTag == tag) {
          item.taskTag = null;
        }
      }
      if (_selectedTaskTagFilter == tag) {
        _selectedTaskTagFilter = allTaskCategoriesLabel;
      }
    });
    _saveData();
  }

  void _removeUnknownTaskTags() {
    var changed = false;
    for (final item in _allItems) {
      if (item.taskTag != null && !s.taskTags.contains(item.taskTag)) {
        item.taskTag = null;
        changed = true;
      }
    }
    if (_selectedTaskTagFilter != allTaskCategoriesLabel &&
        !s.taskTags.contains(_selectedTaskTagFilter)) {
      _selectedTaskTagFilter = allTaskCategoriesLabel;
    }
    if (changed) {
      _saveData();
    }
  }

  void _showAddTaskTagDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'タグを追加',
          style: TextStyle(color: s.primaryColor, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          hintLocales: const [Locale('ja', 'JP')],
          decoration: InputDecoration(
            hintText: 'タグ名',
            filled: true,
            fillColor: const Color(0xFFF5F5FA),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (_) {
            if (_addTaskTagFromHome(controller.text)) {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              if (_addTaskTagFromHome(controller.text)) {
                Navigator.pop(context);
              }
            },
            child: Text(
              '追加',
              style: TextStyle(
                color: s.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _addTaskTagFromHome(String value) {
    final tag = normalizeTaskTag(value);
    if (tag == null) return false;
    if (s.taskTags.contains(tag)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('「$tag」はすでにあります')));
      return false;
    }
    setState(() {
      s.taskTags.add(tag);
      _selectedTaskTagFilter = tag;
    });
    s.saveToPrefs();
    widget.onSettingsChanged();
    return true;
  }

  void _showTaskTagActions(String tag) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.edit, color: s.primaryColor),
                  title: const Text('タグ名を変更'),
                  subtitle: Text(tag),
                  onTap: () {
                    Navigator.pop(context);
                    _showRenameTaskTagDialog(tag);
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: Colors.red.shade300,
                  ),
                  title: const Text('タグを削除'),
                  subtitle: const Text('このタグが付いたタスクはタグなしになります'),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDeleteTaskTagFromHome(tag);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRenameTaskTagDialog(String oldTag) {
    final controller = TextEditingController(text: oldTag);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'タグ名を変更',
          style: TextStyle(color: s.primaryColor, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          hintLocales: const [Locale('ja', 'JP')],
          decoration: InputDecoration(
            hintText: 'タグ名',
            filled: true,
            fillColor: const Color(0xFFF5F5FA),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (_) {
            if (_renameTaskTagFromHome(oldTag, controller.text)) {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              if (_renameTaskTagFromHome(oldTag, controller.text)) {
                Navigator.pop(context);
              }
            },
            child: Text(
              '保存',
              style: TextStyle(
                color: s.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _renameTaskTagFromHome(String oldTag, String value) {
    final newTag = normalizeTaskTag(value);
    if (newTag == null) return false;
    if (newTag == oldTag) return true;
    if (s.taskTags.contains(newTag)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('「$newTag」はすでにあります')));
      return false;
    }

    final index = s.taskTags.indexOf(oldTag);
    if (index == -1) return false;
    s.taskTags[index] = newTag;
    _renameTaskTag(oldTag, newTag);
    s.saveToPrefs();
    widget.onSettingsChanged();
    return true;
  }

  Future<void> _confirmDeleteTaskTagFromHome(String tag) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'タグを削除',
          style: TextStyle(color: s.primaryColor, fontWeight: FontWeight.bold),
        ),
        content: Text('「$tag」を削除しますか？\nこのタグが付いたタスクはタグなしになります。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text(
              '削除',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (result != true) return;

    s.taskTags.remove(tag);
    _deleteTaskTag(tag);
    s.saveToPrefs();
    widget.onSettingsChanged();
  }

  // ─── 削除（確認あり/なし切替） ───
  Future<bool> _handleDelete(TodoItem item) async {
    if (!s.showDeleteConfirm) {
      _deleteItem(item);
      return true;
    }
    return await _showDeleteConfirmDialog(item);
  }

  Future<bool> _showDeleteConfirmDialog(TodoItem item) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'タスクを削除',
          style: TextStyle(fontWeight: FontWeight.bold, color: s.primaryColor),
        ),
        content: Text(
          '「${item.title}」を削除しますか？\nこの操作は取り消せません。',
          style: const TextStyle(fontSize: 15, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'キャンセル',
              style: TextStyle(color: Colors.grey, fontSize: 15),
            ),
          ),
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text(
              '削除',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ],
      ),
    );
    if (result == true) {
      _deleteItem(item);
      return true;
    }
    return false;
  }

  // ─── やることに移動ダイアログ ───
  void _showMoveToTodoDialog(TodoItem item) {
    final textController = TextEditingController(text: item.title);
    final descriptionController = TextEditingController(
      text: item.description ?? '',
    );

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) {
        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
            ),
            child: Material(
              color: Colors.transparent,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                child: Container(
                  padding: const EdgeInsets.only(left: 24, right: 24, top: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '「${s.todoTabName}」に移動',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: s.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '優先度はリセットされます',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: textController,
                          autofocus: true,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            hintText: 'タスクを入力...',
                            filled: true,
                            fillColor: const Color(0xFFF5F5FA),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: descriptionController,
                          textInputAction: TextInputAction.done,
                          minLines: 1,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: '概要を入力（任意）',
                            filled: true,
                            fillColor: const Color(0xFFF5F5FA),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.all(16),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () {
                            final trimmed = textController.text.trim();
                            if (trimmed.isEmpty) return;
                            setState(() {
                              item.title = trimmed;
                              item.description = _normalizeOptionalText(
                                descriptionController.text,
                              );
                              item.category = 'todo';
                              item.priority = TaskPriority.none;
                            });
                            _saveData();
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: s.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            '「${s.todoTabName}」に移動',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── やりたいことに戻すダイアログ ───
  void _showMoveToFutureDialog(TodoItem item) {
    final textController = TextEditingController(text: item.title);
    final descriptionController = TextEditingController(
      text: item.description ?? '',
    );
    var selectedTaskPriority = item.priority;

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 16,
                  right: 16,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.85,
                    ),
                    child: Container(
                      padding: const EdgeInsets.only(
                        left: 24,
                        right: 24,
                        top: 24,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '「${s.futureTabName}」に移動',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: s.primaryColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: textController,
                              autofocus: true,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                hintText: 'タスクを入力...',
                                filled: true,
                                fillColor: const Color(0xFFF5F5FA),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: descriptionController,
                              textInputAction: TextInputAction.done,
                              minLines: 1,
                              maxLines: 4,
                              decoration: InputDecoration(
                                hintText: '概要を入力（任意）',
                                filled: true,
                                fillColor: const Color(0xFFF5F5FA),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.all(16),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildTaskPriorityPicker(
                              selectedTaskPriority: selectedTaskPriority,
                              onChanged: (p) =>
                                  setSheetState(() => selectedTaskPriority = p),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () {
                                final trimmed = textController.text.trim();
                                if (trimmed.isEmpty) return;
                                setState(() {
                                  item.title = trimmed;
                                  item.description = _normalizeOptionalText(
                                    descriptionController.text,
                                  );
                                  item.category = 'future';
                                  item.priority = selectedTaskPriority;
                                });
                                _saveData();
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: s.primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                '「${s.futureTabName}」に移動',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ─── 編集ダイアログ ───
  void _showEditDialog(TodoItem item, {String tabKey = ''}) {
    final isFromTodayTab = tabKey == 'today';
    final textController = TextEditingController(text: item.title);
    final descriptionController = TextEditingController(
      text: item.description ?? '',
    );
    DateTime? selectedDate = item.dueDate;
    var selectedImageBase64List = [...item.imageBase64List];
    var selectedTaskTag = item.taskTag;
    var selectedRecurrenceRule = item.recurrenceRule;
    var selectedTaskPriority = item.priority;

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final mediaQuery = MediaQuery.of(context);
            final topInset = mediaQuery.padding.top;
            final keyboardInset = mediaQuery.viewInsets.bottom;
            final topOffset = topInset + 4;
            final bottomGap = keyboardInset > 0 ? 20.0 : 16.0;
            final maxModalHeight =
                (mediaQuery.size.height - topOffset - keyboardInset - bottomGap)
                    .clamp(240.0, mediaQuery.size.height * 0.8);
            void submit() {
              _editItem(
                item,
                textController.text,
                description: descriptionController.text,
                taskTag: selectedTaskTag,
                dueDate: selectedDate,
                recurrenceRule: selectedRecurrenceRule,
                imageBase64List: selectedImageBase64List,
                priority: selectedTaskPriority,
              );
              Navigator.pop(context);
            }

            return Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(
                  top: topOffset,
                  left: 16,
                  right: 16,
                  bottom: keyboardInset + bottomGap,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxModalHeight),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Flexible(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'タスクを編集',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: s.primaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: textController,
                                    autofocus: true,
                                    textInputAction: TextInputAction.next,
                                    decoration: InputDecoration(
                                      hintText: 'タスクを入力...',
                                      filled: true,
                                      fillColor: const Color(0xFFF5F5FA),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 14,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: descriptionController,
                                    textInputAction: TextInputAction.done,
                                    minLines: 1,
                                    maxLines: 4,
                                    onSubmitted: (_) => submit(),
                                    decoration: InputDecoration(
                                      hintText: '概要を入力（任意）',
                                      filled: true,
                                      fillColor: const Color(0xFFF5F5FA),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding: const EdgeInsets.all(16),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildTaskTagPicker(
                                    selectedTaskTag: selectedTaskTag,
                                    onChanged: (tag) => setSheetState(
                                      () => selectedTaskTag = tag,
                                    ),
                                  ),
                                  if (item.category == 'future') ...[
                                    const SizedBox(height: 12),
                                    _buildTaskPriorityPicker(
                                      selectedTaskPriority:
                                          selectedTaskPriority,
                                      onChanged: (p) => setSheetState(
                                        () => selectedTaskPriority = p,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  if (isFromTodayTab)
                                    _buildTimeOnlyPickerRow(
                                      selectedDate: selectedDate,
                                      onTimeSelected: (date) => setSheetState(
                                        () => selectedDate = date,
                                      ),
                                      onTimeCleared: () => setSheetState(
                                        () => selectedDate = null,
                                      ),
                                    )
                                  else
                                    _buildDatePickerRow(
                                      selectedDate: selectedDate,
                                      onDateSelected: (date) => setSheetState(
                                        () => selectedDate = date,
                                      ),
                                      onDateCleared: () => setSheetState(
                                        () => selectedDate = null,
                                      ),
                                    ),
                                  const SizedBox(height: 12),
                                  _buildRecurrencePicker(
                                    selectedRecurrenceRule:
                                        selectedRecurrenceRule,
                                    onChanged: (rule) => setSheetState(
                                      () => selectedRecurrenceRule = rule,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildImagePickerRow(
                                    imageBase64List: selectedImageBase64List,
                                    onImagesChanged: (imageBase64List) =>
                                        setSheetState(
                                          () => selectedImageBase64List =
                                              imageBase64List,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: s.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              '保存',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _editItem(
    TodoItem item,
    String newTitle, {
    String? description,
    String? taskTag,
    DateTime? dueDate,
    RecurrenceRule recurrenceRule = RecurrenceRule.none,
    List<String> imageBase64List = const [],
    TaskPriority priority = TaskPriority.none,
  }) {
    final trimmed = newTitle.trim();
    if (trimmed.isEmpty) return;
    final hadDueDate = item.dueDate != null;
    setState(() {
      item.title = trimmed;
      item.description = _normalizeOptionalText(description);
      item.taskTag = _normalizeKnownTaskTag(taskTag);
      item.dueDate = dueDate;
      item.recurrenceRule = recurrenceRule;
      item.imageBase64List = imageBase64List;
      item.priority = priority;
    });
    _saveData();
    if (item.dueDate == null && hadDueDate) {
      NotificationService().cancelNotification(item.id);
    } else {
      NotificationService().scheduleNotification(item, s.notificationTiming);
    }
  }

  // ─── 設定ページへ遷移 ───
  void _openSettings() async {
    final timingBefore = s.notificationTiming;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsPage(
          settings: s,
          onSettingsChanged: () {
            widget.onSettingsChanged();
            _removeUnknownTaskTags();
            // タブ数が変わった場合のみ再構築
            if (_tabController == null ||
                _tabController!.length != _activeTabKeys.length) {
              setState(() {
                _rebuildTabController();
              });
            }
          },
          onTaskTagRenamed: _renameTaskTag,
          onTaskTagDeleted: _deleteTaskTag,
        ),
      ),
    );
    // 戻ってきたとき、タブ数が変わっていたら反映
    if (_tabController == null ||
        _tabController!.length != _activeTabKeys.length) {
      _rebuildTabController();
    }
    // 通知タイミングが変わっていたら全ての通知を再スケジュール
    if (timingBefore != s.notificationTiming) {
      NotificationService().rescheduleAll(_allItems, s.notificationTiming);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_tabController == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          s.appTitle,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
            tooltip: '設定',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          labelPadding: EdgeInsets.zero,
          tabs: _activeTabKeys
              .map(
                (key) => Tab(
                  child: Text(
                    _tabName(key),
                    textAlign: TextAlign.center,
                    softWrap: true,
                  ),
                ),
              )
              .toList(),
          indicatorWeight: 3,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _activeTabKeys.map((key) => _buildTodoList(key)).toList(),
      ),
      floatingActionButton: _currentTabKey != 'done'
          ? FloatingActionButton(
              onPressed: _showAddDialog,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  // ─── リスト表示 ───
  Widget _buildTodoList(String category) {
    final items = _itemsByCategory(category);

    return Column(
      children: [
        _buildTaskTagFilter(),
        Expanded(
          child: items.isEmpty
              ? _buildEmptyListMessage(category)
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _buildTodoCard(items[i], category),
                ),
        ),
      ],
    );
  }

  Widget _buildTaskTagFilter() {
    if (s.taskTags.isEmpty) {
      return Container(
        height: 52,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ActionChip(
          avatar: Icon(Icons.label_outline, color: s.primaryColor, size: 18),
          label: const Text('タグを追加'),
          backgroundColor: Colors.white,
          side: BorderSide(color: Colors.grey.shade300),
          labelStyle: TextStyle(
            color: s.primaryColor,
            fontWeight: FontWeight.bold,
          ),
          onPressed: _showAddTaskTagDialog,
        ),
      );
    }

    final tags = [allTaskCategoriesLabel, ...s.taskTags];

    return Container(
      height: 52,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: tags.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == tags.length) {
            return ActionChip(
              avatar: Icon(Icons.add, color: s.primaryColor, size: 18),
              label: const Text('タグを追加'),
              backgroundColor: Colors.white,
              side: BorderSide(color: Colors.grey.shade300),
              labelStyle: TextStyle(
                color: s.primaryColor,
                fontWeight: FontWeight.bold,
              ),
              onPressed: _showAddTaskTagDialog,
            );
          }

          final tag = tags[index];
          final isSelected = tag == _selectedTaskTagFilter;
          final canEditTag = tag != allTaskCategoriesLabel;

          return GestureDetector(
            onLongPress: canEditTag ? () => _showTaskTagActions(tag) : null,
            child: ChoiceChip(
              label: Text(tag),
              selected: isSelected,
              showCheckmark: false,
              selectedColor: s.primaryColor,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              side: BorderSide(
                color: isSelected ? s.primaryColor : Colors.grey.shade300,
              ),
              onSelected: (_) {
                setState(() {
                  _selectedTaskTagFilter = tag;
                });
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyListMessage(String category) {
    final hasTagFilter = _selectedTaskTagFilter != allTaskCategoriesLabel;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            category == 'done'
                ? Icons.check_circle_outline
                : category == 'future'
                ? Icons.lightbulb_outline
                : category == 'today'
                ? Icons.today_outlined
                : Icons.inbox_outlined,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 12),
          Text(
            hasTagFilter
                ? '$_selectedTaskTagFilterのタスクはありません'
                : category == 'done'
                ? '${s.doneTabName}のタスクはありません'
                : category == 'today'
                ? '${s.todayTabName}のタスクはありません'
                : '${_tabName(category)}を追加しましょう',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  // ─── 個別カード ───
  Widget _buildTodoCard(TodoItem item, String category) {
    Widget compactIconButton({
      required Widget icon,
      required VoidCallback? onPressed,
      required String tooltip,
    }) {
      return IconButton(
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(width: 34, height: 34),
        padding: EdgeInsets.zero,
        icon: icon,
        onPressed: onPressed,
        tooltip: tooltip,
      );
    }

    return AnimatedOpacity(
      opacity: _fadingOutItems.contains(item.id) ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      child: Dismissible(
        key: ValueKey(item),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) => _handleDelete(item),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.red.shade400,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        child: Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: Colors.white,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            onTap: category == 'done'
                ? null
                : () => _showEditDialog(item, tabKey: category),
            leading: category == 'done'
                ? null
                : Checkbox(
                    value: item.isDone,
                    onChanged: (_) => _completeItemWithFade(item),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    activeColor: s.primaryColor,
                  ),
            title: Text(
              item.title,
              style: TextStyle(
                fontSize: 16,
                decoration: item.isDone
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
                color: item.isDone ? Colors.grey : Colors.black87,
              ),
            ),
            subtitle: _buildTodoSubtitle(item),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.isDone)
                  compactIconButton(
                    icon: Icon(Icons.replay, color: s.accentColor),
                    onPressed: () async {
                      final result = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          title: Text(
                            '未完了に戻す',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: s.primaryColor,
                            ),
                          ),
                          content: Text(
                            '「${item.title}」を未完了に戻しますか？',
                            style: const TextStyle(fontSize: 15, height: 1.5),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text(
                                'キャンセル',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                            TextButton(
                              autofocus: true,
                              onPressed: () => Navigator.pop(context, true),
                              child: Text(
                                '戻す',
                                style: TextStyle(
                                  color: s.primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                      if (result == true) _toggleItem(item);
                    },
                    tooltip: '未完了に戻す',
                  ),
                if (!item.isDone && item.category == 'future')
                  compactIconButton(
                    icon: Icon(
                      Icons.arrow_circle_left_outlined,
                      color: s.primaryColor,
                      size: 22,
                    ),
                    onPressed: () => _showMoveToTodoDialog(item),
                    tooltip: 'やることに移動',
                  ),
                if (!item.isDone && item.category == 'todo')
                  compactIconButton(
                    icon: Icon(
                      Icons.arrow_circle_right_outlined,
                      color: Colors.orange.shade400,
                      size: 22,
                    ),
                    onPressed: () => _showMoveToFutureDialog(item),
                    tooltip: 'やりたいことに戻す',
                  ),
                if (category == 'today')
                  compactIconButton(
                    icon: Icon(
                      Icons.access_time,
                      color: item.dueDate != null
                          ? s.primaryColor
                          : const Color(0xFFAAAAAA),
                      size: 20,
                    ),
                    onPressed: () => _showTimePickerForItem(item),
                    tooltip: '時間を設定',
                  )
                else if (category != 'done')
                  compactIconButton(
                    icon: Icon(
                      Icons.calendar_today,
                      color: item.dueDate != null
                          ? s.primaryColor
                          : const Color(0xFFAAAAAA),
                      size: 20,
                    ),
                    onPressed: () => _showDatePickerForItem(item),
                    tooltip: '期限を設定',
                  ),
                compactIconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: Colors.red.shade300,
                    size: 20,
                  ),
                  onPressed: () => _handleDelete(item),
                  tooltip: '削除',
                ),
              ],
            ),
          ),
        ),
      ), // Dismissible
    ); // AnimatedOpacity
  }

  Widget? _buildTodoSubtitle(TodoItem item) {
    final imageBytesList = _decodeImages(item.imageBase64List);
    final description = item.description;
    final hasTaskPriority =
        item.category == 'future' && item.priority != TaskPriority.none;
    if (item.taskTag == null &&
        !item.isRecurring &&
        !hasTaskPriority &&
        description == null &&
        item.dueDate == null &&
        imageBytesList.isEmpty) {
      return null;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.taskTag != null || item.isRecurring || hasTaskPriority)
            _buildTaskLabels(item, hasTaskPriority: hasTaskPriority),
          if ((item.taskTag != null || item.isRecurring || hasTaskPriority) &&
              (description != null ||
                  item.dueDate != null ||
                  imageBytesList.isNotEmpty))
            const SizedBox(height: 8),
          if (description != null)
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: item.isDone ? Colors.grey.shade500 : Colors.black54,
              ),
            ),
          if (description != null &&
              (item.dueDate != null || imageBytesList.isNotEmpty))
            const SizedBox(height: 8),
          if (item.dueDate != null)
            Text(
              _formatTodoCardDueDate(item.dueDate!),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: TextStyle(
                fontSize: 12,
                color: item.isOverdue ? Colors.red : Colors.grey.shade700,
                fontWeight: item.isOverdue
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          if (imageBytesList.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              child: PageView.builder(
                itemCount: imageBytesList.length,
                itemBuilder: (context, index) {
                  final imageBytes = imageBytesList[index];
                  return GestureDetector(
                    onTap: () => _showImagePreview(imageBytes),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Container(
                              color: const Color(0xFFF5F5FA),
                              child: Image.memory(
                                imageBytes,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          if (imageBytesList.length > 1)
                            Positioned(
                              left: 8,
                              bottom: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '${index + 1}/${imageBytesList.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

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

  String? _normalizeOptionalText(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
