part of '../../../main.dart';

extension _TodoHomeAppBarActions on _TodoHomePageState {
  List<Widget> _buildAppBarActions() {
    return [
      // 完了タブで、完了済みタスクがある時のみ「全削除」を表示
      if (_currentTabKey == 'done' && _allItems.any((item) => item.isDone))
        IconButton(
          icon: const Icon(Icons.delete_sweep_outlined),
          onPressed: _confirmDeleteCompletedItems,
          tooltip: '完了済みを全削除',
        ),
      IconButton(
        icon: const Icon(Icons.settings),
        onPressed: _openSettings,
        tooltip: '設定',
      ),
    ];
  }
}
