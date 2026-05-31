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
            subtitle: const Text('削除前に確認を表示'),
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
            title: const Text(
              '期限の通知タイミング',
              overflow: TextOverflow.visible,
              softWrap: false,
            ),
            trailing: DropdownButton<NotificationTiming>(
              value: s.notificationTiming,
              underline: const SizedBox(),
              icon: const Icon(Icons.arrow_drop_down),
              items: NotificationTiming.values.map((timing) {
                return DropdownMenuItem(
                  value: timing,
                  child: Text(timing.label),
                );
              }).toList(),
              onChanged: (v) {
                if (v != null) {
                  s.notificationTiming = v;
                  _notify();
                }
              },
            ),
          ),
        ],
      ),
    ];
  }
}
