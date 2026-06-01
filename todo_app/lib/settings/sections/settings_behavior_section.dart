part of '../../settings_page.dart';

extension _SettingsBehaviorSection on _SettingsPageState {
  List<Widget> _buildBehaviorSection() {
    return [
      _buildSectionHeader('動作設定'),
      _buildCard(
        children: [
          SwitchListTile(
            secondary: Icon(Icons.warning_amber_rounded, color: s.primaryColor),
            title: const Text('削除時の確認ダイアログ'),
            subtitle: const Text(
              '削除前に確認を表示',
              style: TextStyle(fontSize: 12),
            ),
            value: s.showDeleteConfirm,
            activeThumbColor: s.primaryColor,
            onChanged: (v) {
              s.showDeleteConfirm = v;
              _notify();
            },
          ),
          _divider(),
          SwitchListTile(
            secondary: Icon(Icons.swipe_left_alt, color: s.primaryColor),
            title: const Text('スワイプで削除'),
            subtitle: const Text(
              'タスクを左にスワイプして削除',
              overflow: TextOverflow.visible,
              softWrap: false,
              style: TextStyle(fontSize: 12),
            ),
            value: s.enableSwipeDelete,
            activeThumbColor: s.primaryColor,
            onChanged: (v) {
              s.enableSwipeDelete = v;
              _notify();
            },
          ),
          _divider(),
          ListTile(
            leading: Icon(Icons.notifications_active, color: s.primaryColor),
            title: const Text('期限の通知タイミング'),
            // ▽（上）とその真下に現在値を縦に並べて表示。
            // PopupMenuButtonにすることでメニュー幅が項目に合い、折り返さない
            trailing: PopupMenuButton<NotificationTiming>(
              initialValue: s.notificationTiming,
              tooltip: '通知タイミングを選択',
              onSelected: (v) {
                s.notificationTiming = v;
                _notify();
              },
              itemBuilder: (context) => NotificationTiming.values.map((timing) {
                return PopupMenuItem<NotificationTiming>(
                  value: timing,
                  child: Text(timing.label),
                );
              }).toList(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.arrow_drop_down),
                  // 幅を固定し、長い値だけ縮小して1行表示（タイトルを折り返させない）
                  SizedBox(
                    width: 56,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        s.notificationTiming.label,
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(fontSize: 13, color: s.primaryColor),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ];
  }
}
