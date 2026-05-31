part of '../../../main.dart';

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

  // 現在のタブのカテゴリキー
  String get _currentTabKey => _activeTabKeys[_tabController!.index];

  void _updateState(VoidCallback fn) => setState(fn);

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
        actions: _buildAppBarActions(),
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
      floatingActionButton: _currentTabKey == 'done'
          ? _itemsByCategory('done').isNotEmpty
                ? FloatingActionButton(
                    onPressed: _confirmDeleteCompletedItems,
                    tooltip: '完了済みを全削除',
                    child: const Icon(Icons.delete_sweep_outlined),
                  )
                : null
          : FloatingActionButton(
              onPressed: _showAddDialog,
              child: const Icon(Icons.add),
            ),
    );
  }
}
