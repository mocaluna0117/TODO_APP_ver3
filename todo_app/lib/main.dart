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
      return Colors.red.shade400;
    case TaskPriority.medium:
      return Colors.orange.shade400;
    case TaskPriority.low:
      return Colors.blue.shade400;
    case TaskPriority.none:
      return Colors.grey;
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
  String? imageBase64;
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
    this.imageBase64,
    this.priority = TaskPriority.none,
  }) : id = id ?? (DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF);

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
    'imageBase64': imageBase64,
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
    imageBase64: json['imageBase64'] ?? json['picture'],
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
    String? selectedImageBase64;
    String? selectedTaskTag;
    var selectedRecurrenceRule = RecurrenceRule.none;
    var selectedTaskPriority = TaskPriority.none;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.only(left: 24, right: 24, top: 24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SingleChildScrollView(
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
                          contentPadding: const EdgeInsets.symmetric(
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
                        minLines: 2,
                        maxLines: 4,
                        onSubmitted: (_) {
                          _addItem(
                            textController.text,
                            category,
                            description: descriptionController.text,
                            taskTag: selectedTaskTag,
                            dueDate: selectedDate,
                            recurrenceRule: selectedRecurrenceRule,
                            imageBase64: selectedImageBase64,
                            priority: selectedTaskPriority,
                          );
                          Navigator.pop(context);
                        },
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
                        onChanged: (tag) =>
                            setSheetState(() => selectedTaskTag = tag),
                      ),
                      if (category == 'future') ...[
                        const SizedBox(height: 12),
                        _buildTaskPriorityPicker(
                          selectedTaskPriority: selectedTaskPriority,
                          onChanged: (p) =>
                              setSheetState(() => selectedTaskPriority = p),
                        ),
                      ],
                      const SizedBox(height: 12),
                      if (isFromTodayTab)
                        _buildTimeOnlyPickerRow(
                          selectedDate: selectedDate,
                          onTimeSelected: (date) =>
                              setSheetState(() => selectedDate = date),
                          onTimeCleared: () =>
                              setSheetState(() => selectedDate = null),
                        )
                      else
                        _buildDatePickerRow(
                          selectedDate: selectedDate,
                          onDateSelected: (date) =>
                              setSheetState(() => selectedDate = date),
                          onDateCleared: () =>
                              setSheetState(() => selectedDate = null),
                        ),
                      const SizedBox(height: 12),
                      _buildRecurrencePicker(
                        selectedRecurrenceRule: selectedRecurrenceRule,
                        onChanged: (rule) =>
                            setSheetState(() => selectedRecurrenceRule = rule),
                      ),
                      const SizedBox(height: 12),
                      _buildImagePickerRow(
                        imageBase64: selectedImageBase64,
                        onImageChanged: (imageBase64) => setSheetState(
                          () => selectedImageBase64 = imageBase64,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () {
                          _addItem(
                            textController.text,
                            category,
                            description: descriptionController.text,
                            taskTag: selectedTaskTag,
                            dueDate: selectedDate,
                            recurrenceRule: selectedRecurrenceRule,
                            imageBase64: selectedImageBase64,
                            priority: selectedTaskPriority,
                          );
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
                        child: const Text('追加', style: TextStyle(fontSize: 16)),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<String?> _pickImageBase64() async {
    final pickedImage = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (pickedImage == null) return null;

    final bytes = await pickedImage.readAsBytes();
    return base64Encode(bytes);
  }

  Uint8List? _decodeImage(String? imageBase64) {
    if (imageBase64 == null || imageBase64.isEmpty) return null;
    try {
      return base64Decode(imageBase64);
    } on FormatException {
      return null;
    }
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
          final isToday = pickedDate.year == now.year &&
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
      final minMins =
          minimumDateTime.hour * 60 + minimumDateTime.minute + 1;
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
                                  color: isValid
                                      ? s.primaryColor
                                      : Colors.grey,
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
    required String? imageBase64,
    required ValueChanged<String?> onImageChanged,
  }) {
    final imageBytes = _decodeImage(imageBase64);

    return InkWell(
      onTap: () async {
        try {
          final pickedImageBase64 = await _pickImageBase64();
          if (pickedImageBase64 != null) {
            onImageChanged(pickedImageBase64);
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
        child: Row(
          children: [
            Icon(Icons.image_outlined, size: 20, color: s.primaryColor),
            const SizedBox(width: 10),
            if (imageBytes != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  imageBytes,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                imageBytes != null ? '画像を変更' : '画像を添付（任意）',
                style: TextStyle(
                  fontSize: 15,
                  color: imageBytes != null ? Colors.black87 : Colors.grey,
                ),
              ),
            ),
            if (imageBytes != null)
              GestureDetector(
                onTap: () => onImageChanged(null),
                child: Icon(Icons.close, size: 18, color: Colors.grey.shade400),
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
    return DropdownButtonFormField<TaskPriority>(
      initialValue: selectedTaskPriority,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: '優先度',
        prefixIcon: Icon(Icons.flag_outlined, color: s.primaryColor),
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
      items: TaskPriority.values
          .map(
            (p) => DropdownMenuItem(
              value: p,
              child: Row(
                children: [
                  if (p != TaskPriority.none)
                    Icon(Icons.flag, size: 16, color: priorityColor(p)),
                  if (p != TaskPriority.none) const SizedBox(width: 6),
                  Text(p.label),
                ],
              ),
            ),
          )
          .toList(),
      onChanged: (p) {
        if (p != null) onChanged(p);
      },
    );
  }

  void _addItem(
    String title,
    String category, {
    String? description,
    String? taskTag,
    DateTime? dueDate,
    RecurrenceRule recurrenceRule = RecurrenceRule.none,
    String? imageBase64,
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
      imageBase64: imageBase64,
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
      final isToday = pickedDate.year == now.year &&
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.only(left: 24, right: 24, top: 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
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
                    minLines: 2,
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
                        item.description =
                            _normalizeOptionalText(descriptionController.text);
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.only(left: 24, right: 24, top: 24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                        minLines: 2,
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
                          padding: const EdgeInsets.symmetric(vertical: 14),
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
    String? selectedImageBase64 = item.imageBase64;
    var selectedTaskTag = item.taskTag;
    var selectedRecurrenceRule = item.recurrenceRule;
    var selectedTaskPriority = item.priority;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.only(left: 24, right: 24, top: 24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SingleChildScrollView(
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
                        minLines: 2,
                        maxLines: 4,
                        onSubmitted: (_) {
                          _editItem(
                            item,
                            textController.text,
                            description: descriptionController.text,
                            taskTag: selectedTaskTag,
                            dueDate: selectedDate,
                            recurrenceRule: selectedRecurrenceRule,
                            imageBase64: selectedImageBase64,
                            priority: selectedTaskPriority,
                          );
                          Navigator.pop(context);
                        },
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
                        onChanged: (tag) =>
                            setSheetState(() => selectedTaskTag = tag),
                      ),
                      if (item.category == 'future') ...[
                        const SizedBox(height: 12),
                        _buildTaskPriorityPicker(
                          selectedTaskPriority: selectedTaskPriority,
                          onChanged: (p) =>
                              setSheetState(() => selectedTaskPriority = p),
                        ),
                      ],
                      const SizedBox(height: 12),
                      if (isFromTodayTab)
                        _buildTimeOnlyPickerRow(
                          selectedDate: selectedDate,
                          onTimeSelected: (date) =>
                              setSheetState(() => selectedDate = date),
                          onTimeCleared: () =>
                              setSheetState(() => selectedDate = null),
                        )
                      else
                        _buildDatePickerRow(
                          selectedDate: selectedDate,
                          onDateSelected: (date) =>
                              setSheetState(() => selectedDate = date),
                          onDateCleared: () =>
                              setSheetState(() => selectedDate = null),
                        ),
                      const SizedBox(height: 12),
                      _buildRecurrencePicker(
                        selectedRecurrenceRule: selectedRecurrenceRule,
                        onChanged: (rule) =>
                            setSheetState(() => selectedRecurrenceRule = rule),
                      ),
                      const SizedBox(height: 12),
                      _buildImagePickerRow(
                        imageBase64: selectedImageBase64,
                        onImageChanged: (imageBase64) => setSheetState(
                          () => selectedImageBase64 = imageBase64,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () {
                          _editItem(
                            item,
                            textController.text,
                            description: descriptionController.text,
                            taskTag: selectedTaskTag,
                            dueDate: selectedDate,
                            recurrenceRule: selectedRecurrenceRule,
                            imageBase64: selectedImageBase64,
                            priority: selectedTaskPriority,
                          );
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
                        child: const Text('保存', style: TextStyle(fontSize: 16)),
                      ),
                      const SizedBox(height: 24),
                    ],
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
    String? imageBase64,
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
      item.imageBase64 = imageBase64;
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                IconButton(
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
                IconButton(
                  icon: Icon(
                    Icons.arrow_circle_left_outlined,
                    color: s.primaryColor,
                    size: 22,
                  ),
                  onPressed: () => _showMoveToTodoDialog(item),
                  tooltip: 'やることに移動',
                ),
              if (!item.isDone && item.category == 'todo')
                IconButton(
                  icon: Icon(
                    Icons.arrow_circle_right_outlined,
                    color: Colors.orange.shade400,
                    size: 22,
                  ),
                  onPressed: () => _showMoveToFutureDialog(item),
                  tooltip: 'やりたいことに戻す',
                ),
              if (category == 'today')
                IconButton(
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
                IconButton(
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
              IconButton(
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
    ),  // Dismissible
    );  // AnimatedOpacity
  }

  Widget? _buildTodoSubtitle(TodoItem item) {
    final imageBytes = _decodeImage(item.imageBase64);
    final description = item.description;
    final hasTaskPriority =
        item.category == 'future' && item.priority != TaskPriority.none;
    if (item.taskTag == null &&
        !item.isRecurring &&
        !hasTaskPriority &&
        description == null &&
        item.dueDate == null &&
        imageBytes == null) {
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
                  imageBytes != null))
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
              (item.dueDate != null || imageBytes != null))
            const SizedBox(height: 8),
          if (item.dueDate != null)
            Text(
              DateFormat('yyyy/MM/dd (E) HH:mm', 'ja').format(item.dueDate!),
              style: TextStyle(
                fontSize: 12,
                color: item.isOverdue ? Colors.red : Colors.grey.shade500,
                fontWeight: item.isOverdue
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          if (imageBytes != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(
                imageBytes,
                width: 120,
                height: 84,
                fit: BoxFit.cover,
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
          Icon(
            Icons.flag,
            size: 11,
            color: item.isDone ? Colors.grey.shade500 : color,
          ),
          const SizedBox(width: 3),
          Text(
            item.priority.label,
            style: TextStyle(
              color: item.isDone ? Colors.grey.shade500 : color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
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
