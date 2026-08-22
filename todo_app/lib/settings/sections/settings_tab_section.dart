part of '../../settings_page.dart';

extension _SettingsTabSection on _SettingsPageState {
  List<Widget> _buildTabSettingsSection() {
    return [
      _buildSectionHeader('タブ設定'),
      _buildCard(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              '右の ≡ をドラッグすると、タブの並び順を変えられます。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          _divider(),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            // 行にスイッチがあるため、長押しではなく専用のつまみで並び替える
            buildDefaultDragHandles: false,
            onReorderItem: _reorderTabs,
            children: [
              for (var i = 0; i < s.tabOrder.length; i++)
                _buildTabTile(s.tabOrder[i], i),
            ],
          ),
          _divider(),
          ListTile(
            leading: Icon(Icons.refresh, color: Colors.grey.shade500),
            title: Text(
              'タブ名と並び順をデフォルトに戻す',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            onTap: () {
              s.todoTabName = 'やること';
              s.todayTabName = '今日やること';
              s.doneTabName = '完了済み';
              s.futureTabName = 'やりたいこと';
              s.tabOrder = normalizeTabOrder(null);
              _notify();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('タブ名と並び順をデフォルトに戻しました')),
              );
            },
          ),
        ],
      ),
    ];
  }

  void _reorderTabs(int oldIndex, int newIndex) {
    // onReorderItem は移動元を抜いたあとの位置を渡してくるので補正は不要
    final order = [...s.tabOrder];
    order.insert(newIndex, order.removeAt(oldIndex));
    s.tabOrder = order;
    _notify();
  }

  // タブ1つぶんの行。並び替えのつまみを右端に置く。
  Widget _buildTabTile(String key, int index) {
    final dragHandle = ReorderableDragStartListener(
      index: index,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Icon(Icons.drag_handle, color: Colors.grey.shade500),
      ),
    );

    // やることタブは非表示にできないので、スイッチを出さない
    if (key == 'todo') {
      return ListTile(
        key: const ValueKey('todo'),
        leading: Icon(Icons.inbox, color: s.primaryColor),
        title: _tabTitleWithEdit(s.todoTabName, (v) {
          s.todoTabName = v;
          _notify();
        }),
        subtitle: const Text('常に表示', style: TextStyle(fontSize: 12)),
        trailing: dragHandle,
      );
    }

    final (icon, title, value, onChanged, onRename) = _tabTileData(key);
    return ListTile(
      key: ValueKey(key),
      leading: Icon(icon, color: s.primaryColor),
      title: _tabTitleWithEdit(title, onRename),
      subtitle: const Text('タブの表示/非表示', style: TextStyle(fontSize: 12)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            value: value,
            activeThumbColor: s.primaryColor,
            onChanged: onChanged,
          ),
          dragHandle,
        ],
      ),
    );
  }

  // タブごとの見た目と設定の読み書きをまとめる
  (IconData, String, bool, ValueChanged<bool>, ValueChanged<String>)
  _tabTileData(String key) {
    switch (key) {
      case 'today':
        return (
          Icons.today_outlined,
          s.todayTabName,
          s.showTodayTab,
          (v) {
            s.showTodayTab = v;
            _notify();
          },
          (v) {
            s.todayTabName = v;
            _notify();
          },
        );
      case 'done':
        return (
          Icons.check_circle_outline,
          s.doneTabName,
          s.showDoneTab,
          (v) {
            s.showDoneTab = v;
            _notify();
          },
          (v) {
            s.doneTabName = v;
            _notify();
          },
        );
      default:
        return (
          Icons.lightbulb_outline,
          s.futureTabName,
          s.showFutureTab,
          (v) {
            s.showFutureTab = v;
            _notify();
          },
          (v) {
            s.futureTabName = v;
            _notify();
          },
        );
    }
  }

  // タブ名の真横に鉛筆アイコンを置き、タップでリネームする
  Widget _tabTitleWithEdit(String title, ValueChanged<String> onRename) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(title)),
        IconButton(
          icon: Icon(Icons.edit, size: 16, color: s.accentColor),
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          padding: EdgeInsets.zero,
          tooltip: 'タブ名を変更',
          onPressed: () => _showTextEditDialog(
            title: 'タブ名を変更',
            currentValue: title,
            onSave: onRename,
          ),
        ),
      ],
    );
  }
}
