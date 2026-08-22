part of '../../../main.dart';

extension _TodoHomeSettings on _TodoHomePageState {
  // ─── 設定ページへ遷移 ───
  void _openSettings() async {
    final timingBefore = s.notificationTiming;
    // 並び替えでタブの位置が変わっても、同じタブを見続けられるようにする
    final tabKeyBefore = _currentTabKey;

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
          onEnablePushNotifications: () async {
            final enabled = await NotificationService()
                .enablePushFromUserAction();
            if (enabled) {
              await NotificationService().registerCurrentDevice();
            }
            return enabled;
          },
          isPushEnabled: () => NotificationService().usesPush,
        ),
      ),
    );
    // 戻ってきたとき、タブ数が変わっていたら反映
    if (_tabController == null ||
        _tabController!.length != _activeTabKeys.length) {
      _rebuildTabController();
    }
    // 並び替えで位置が変わっていたら、元と同じタブに合わせる
    final tabIndexAfter = _activeTabKeys.indexOf(tabKeyBefore);
    if (tabIndexAfter >= 0 && _tabController!.index != tabIndexAfter) {
      _tabController!.index = tabIndexAfter;
      _lastTabIndex = tabIndexAfter;
    }
    // 通知タイミングが変わっていたら全ての通知を再スケジュール
    if (timingBefore != s.notificationTiming) {
      NotificationService().rescheduleAll(_allItems, s.notificationTiming);
      // サーバーから送る分の予定も作り直す
      _resyncAllNotifications();
    }
    _updateState(() {});
  }
}
