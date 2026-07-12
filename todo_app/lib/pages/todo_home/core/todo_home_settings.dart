part of '../../../main.dart';

extension _TodoHomeSettings on _TodoHomePageState {
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
              _updateState(() {
                _rebuildTabController();
              });
            }
          },
          onTaskTagRenamed: _renameTaskTag,
          onTaskTagDeleted: _deleteTaskTag,
          onExportTasks: _exportTasks,
          onImportTasks: _importTasks,
          onDeleteAllTasks: _deleteAllTasks,
          userEmail: widget.userEmail,
          onSignOut: widget.onSignOut,
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
    _updateState(() {});
  }
}
