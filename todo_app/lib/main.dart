import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'app_settings.dart';
import 'settings_page.dart';
import 'notification_service.dart';

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
  DateTime? dueDate;
  String? imageBase64;

  TodoItem({
    int? id,
    required this.title,
    this.description,
    this.isDone = false,
    this.category = 'todo',
    this.dueDate,
    this.imageBase64,
  }) : id = id ?? (DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF);

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
    'dueDate': dueDate?.toIso8601String(),
    'imageBase64': imageBase64,
  };

  factory TodoItem.fromJson(Map<String, dynamic> json) => TodoItem(
    id: (json['id'] as int) & 0x7FFFFFFF,
    title: json['title'],
    description: json['description'],
    isDone: json['isDone'] ?? false,
    category: json['category'] ?? 'todo',
    dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
    imageBase64: json['imageBase64'] ?? json['picture'],
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

  AppSettings get s => widget.settings;

  // 有効なタブのカテゴリキーリスト
  List<String> get _activeTabKeys {
    final keys = <String>['todo'];
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
    final items = category == 'done'
        ? _allItems.where((item) => item.isDone).toList()
        : _allItems
              .where((item) => item.category == category && !item.isDone)
              .toList();

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

  // 現在のタブのカテゴリキー
  String get _currentTabKey => _activeTabKeys[_tabController!.index];

  // ─── アイテム追加ダイアログ ───
  void _showAddDialog() {
    final textController = TextEditingController();
    final descriptionController = TextEditingController();
    final category = _currentTabKey == 'done' ? 'todo' : _currentTabKey;
    DateTime? selectedDate;
    String? selectedImageBase64;

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
                          _addItem(
                            textController.text,
                            category,
                            description: descriptionController.text,
                            dueDate: selectedDate,
                            imageBase64: selectedImageBase64,
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
                      _buildDatePickerRow(
                        selectedDate: selectedDate,
                        onDateSelected: (date) =>
                            setSheetState(() => selectedDate = date),
                        onDateCleared: () =>
                            setSheetState(() => selectedDate = null),
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
                            dueDate: selectedDate,
                            imageBase64: selectedImageBase64,
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
        final pickedDate = await showDatePicker(
          context: context,
          initialDate: selectedDate ?? DateTime.now(),
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
          locale: const Locale('ja'),
        );
        if (pickedDate != null) {
          if (!mounted) return;
          final pickedTime = await showTimePicker(
            context: context,
            initialTime: selectedDate != null
                ? TimeOfDay.fromDateTime(selectedDate)
                : const TimeOfDay(hour: 9, minute: 0),
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

  void _addItem(
    String title,
    String category, {
    String? description,
    DateTime? dueDate,
    String? imageBase64,
  }) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    final newItem = TodoItem(
      title: trimmed,
      description: _normalizeOptionalText(description),
      category: category,
      dueDate: dueDate,
      imageBase64: imageBase64,
    );
    setState(() {
      _allItems.add(newItem);
    });
    _saveData();
    NotificationService().scheduleNotification(newItem, s.notificationTiming);
  }

  // ─── カードから直接期限を変更 ───
  void _showDatePickerForItem(TodoItem item) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: item.dueDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      locale: const Locale('ja'),
    );
    if (pickedDate != null) {
      if (!mounted) return;
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: item.dueDate != null
            ? TimeOfDay.fromDateTime(item.dueDate!)
            : const TimeOfDay(hour: 9, minute: 0),
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

  void _toggleItem(TodoItem item) {
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

  void _deleteItem(TodoItem item) {
    setState(() {
      _allItems.remove(item);
    });
    _saveData();
    NotificationService().cancelNotification(item.id);
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

  // ─── 編集ダイアログ ───
  void _showEditDialog(TodoItem item) {
    final textController = TextEditingController(text: item.title);
    final descriptionController = TextEditingController(
      text: item.description ?? '',
    );
    DateTime? selectedDate = item.dueDate;
    String? selectedImageBase64 = item.imageBase64;

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
                            dueDate: selectedDate,
                            imageBase64: selectedImageBase64,
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
                      _buildDatePickerRow(
                        selectedDate: selectedDate,
                        onDateSelected: (date) =>
                            setSheetState(() => selectedDate = date),
                        onDateCleared: () =>
                            setSheetState(() => selectedDate = null),
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
                            dueDate: selectedDate,
                            imageBase64: selectedImageBase64,
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
    DateTime? dueDate,
    String? imageBase64,
  }) {
    final trimmed = newTitle.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      item.title = trimmed;
      item.description = _normalizeOptionalText(description);
      item.dueDate = dueDate;
      item.imageBase64 = imageBase64;
    });
    _saveData();
    NotificationService().scheduleNotification(item, s.notificationTiming);
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
            // タブ数が変わった場合のみ再構築
            if (_tabController == null ||
                _tabController!.length != _activeTabKeys.length) {
              setState(() {
                _rebuildTabController();
              });
            }
          },
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
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              category == 'done'
                  ? Icons.check_circle_outline
                  : category == 'future'
                  ? Icons.lightbulb_outline
                  : Icons.inbox_outlined,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              category == 'done'
                  ? '${s.doneTabName}のタスクはありません'
                  : '${_tabName(category)}を追加しましょう',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade400),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: items.length,
      itemBuilder: (_, i) => _buildTodoCard(items[i]),
    );
  }

  // ─── 個別カード ───
  Widget _buildTodoCard(TodoItem item) {
    return Dismissible(
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
          onTap: () => _showEditDialog(item),
          leading: Checkbox(
            value: item.isDone,
            onChanged: (_) => _toggleItem(item),
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
                  onPressed: () => _toggleItem(item),
                  tooltip: '未完了に戻す',
                )
              else
                IconButton(
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: Color(0xFFAAAAAA),
                    size: 20,
                  ),
                  onPressed: () => _showEditDialog(item),
                  tooltip: '編集',
                ),
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
    );
  }

  Widget? _buildTodoSubtitle(TodoItem item) {
    final imageBytes = _decodeImage(item.imageBase64);
    final description = item.description;
    if (description == null && item.dueDate == null && imageBytes == null) {
      return null;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
              '期限: ${DateFormat('yyyy/MM/dd (E) HH:mm', 'ja').format(item.dueDate!)}',
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

  String? _normalizeOptionalText(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
