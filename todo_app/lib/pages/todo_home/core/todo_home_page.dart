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
  // タグ絞り込みの選択状態（main: やること/今日やること用、future: やりたいこと用）
  String _selectedTaskTagFilter = allTaskCategoriesLabel;
  String _selectedFutureTaskTagFilter = allTaskCategoriesLabel;
  final Set<int> _fadingOutItems = {};
  // バックアップ復元のファイル選択中フラグ（多重呼び出しによる
  // PlatformException(multiple_request) を防ぐ）
  bool _isPickingBackup = false;

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

    final tabBar = TabBar(
      controller: _tabController,
      isScrollable: false,
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      tabs: _activeTabKeys
          .map(
            (key) => Tab(
              // 折り返さず、入りきらない分だけ縮小して1行で表示
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(_tabName(key), maxLines: 1, softWrap: false),
              ),
            ),
          )
          .toList(),
      indicatorWeight: 3,
    );

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        // AppBarの中身（追加・タイトル・設定）もコンテンツと同じ幅の帯に収めて
        // 中央寄せし、タブ・リストと左右端を揃える
        title: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
            child: Row(
              children: [
                // 完了タブ以外は左端にタスク追加ボタンを表示（幅を揃える）
                if (_currentTabKey == 'done')
                  const SizedBox(width: 48)
                else
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: '追加',
                    onPressed: _showAddDialog,
                  ),
                Expanded(
                  child: Text(
                    s.appTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                ..._buildAppBarActions(),
              ],
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: tabBar.preferredSize,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
              child: tabBar,
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _activeTabKeys.map((key) => _buildTodoList(key)).toList(),
      ),
    );
  }
}
