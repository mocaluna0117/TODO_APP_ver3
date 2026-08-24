part of '../../settings_page.dart';

extension _SettingsNotificationSection on _SettingsPageState {
  // この端末で通知を受け取るための許可。
  // ブラウザ（特に iPhone のホーム画面アプリ）は、利用者がボタンを押した
  // ときにしか許可を求められないため、設定画面に導線を置く。
  List<Widget> _buildPushPermissionSection() {
    final isEnabled = widget.isPushEnabled;
    final enable = widget.onEnablePushNotifications;
    if (isEnabled == null || enable == null) return const [];

    final enabled = isEnabled();
    return [
      _buildSectionHeader('この端末の通知'),
      _buildCard(
        children: [
          ListTile(
            leading: Icon(
              enabled
                  ? Icons.notifications_active
                  : Icons.notifications_off_outlined,
              color: enabled ? s.accentOnSurface : Colors.grey,
            ),
            title: Text(enabled ? '通知を受け取れます' : 'この端末で通知を受け取る'),
            subtitle: Text(
              enabled
                  ? '他の端末で設定した通知も、この端末に届きます'
                  : 'タップして許可すると、他の端末で設定した通知もこの端末に届きます',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: enabled
                ? Icon(Icons.check, color: s.accentOnSurface)
                : const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: enabled ? null : () => _enablePushNotifications(enable),
          ),
        ],
      ),
    ];
  }

  Future<void> _enablePushNotifications(
    Future<bool> Function() enable,
  ) async {
    final granted = await enable();
    if (!mounted) return;
    rebuild();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          granted
              ? 'この端末で通知を受け取れるようになりました'
              : '通知を許可できませんでした。ブラウザやOSの設定を確認してください',
        ),
      ),
    );
  }

  List<Widget> _buildNotificationSection() {
    final presets = [...s.notificationPresets]..sort();

    return [
      ..._buildPushPermissionSection(),
      _buildSectionHeader('通知プリセット'),
      _buildCard(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Text(
              'タスクの通知タイミングの選択肢をカスタマイズできます。\n「期限の時間」は常に表示されます。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          _divider(),
          if (presets.isEmpty)
            ListTile(
              leading: Icon(
                Icons.notifications_off_outlined,
                color: s.accentOnSurface,
              ),
              title: const Text('プリセットはありません'),
              subtitle: const Text(
                '「期限の時間」のみ選べます',
                style: TextStyle(fontSize: 12),
              ),
            )
          else
            for (var i = 0; i < presets.length; i++)
              _buildNotificationPresetTile(
                presets[i],
                isLast: i == presets.length - 1,
              ),
          _divider(),
          ListTile(
            leading: Icon(Icons.add, color: s.accentOnSurface),
            title: const Text('プリセットを追加'),
            trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
            onTap: _addNotificationPreset,
          ),
        ],
      ),
    ];
  }

  Widget _buildNotificationPresetTile(int minutes, {required bool isLast}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: Icon(Icons.notifications_active, color: s.accentOnSurface),
          title: Text(notificationOffsetLabel(minutes)),
          trailing: IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.red.shade300),
            tooltip: '削除',
            onPressed: () {
              s.notificationPresets.remove(minutes);
              _notify();
            },
          ),
        ),
        if (!isLast) _divider(),
      ],
    );
  }

  Future<void> _addNotificationPreset() async {
    final minutes = await showCustomNotificationOffsetSheet(
      context,
      accentColor: s.accentOnSurface,
    );
    if (!mounted || minutes == null || minutes < 1) return;
    if (!s.notificationPresets.contains(minutes)) {
      s.notificationPresets.add(minutes);
      s.notificationPresets.sort();
    }
    _notify();
  }
}
