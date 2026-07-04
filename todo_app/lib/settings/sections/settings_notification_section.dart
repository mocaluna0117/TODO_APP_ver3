part of '../../settings_page.dart';

extension _SettingsNotificationSection on _SettingsPageState {
  List<Widget> _buildNotificationSection() {
    final presets = [...s.notificationPresets]..sort();

    return [
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
                color: s.primaryColor,
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
            leading: Icon(Icons.add, color: s.primaryColor),
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
          leading: Icon(Icons.notifications_active, color: s.primaryColor),
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
      accentColor: s.primaryColor,
    );
    if (!mounted || minutes == null || minutes < 1) return;
    if (!s.notificationPresets.contains(minutes)) {
      s.notificationPresets.add(minutes);
      s.notificationPresets.sort();
    }
    _notify();
  }
}
