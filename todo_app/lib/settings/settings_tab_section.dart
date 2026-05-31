part of '../settings_page.dart';

extension _SettingsTabSection on _SettingsPageState {
  List<Widget> _buildTabSettingsSection() {
    return [
      _buildSectionHeader('タブ設定'),
      _buildCard(
        children: [
          ListTile(
            leading: Icon(Icons.inbox, color: s.primaryColor),
            title: Text(s.todoTabName),
            subtitle: const Text('常に表示'),
            trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
            onTap: () => _showTextEditDialog(
              title: 'タブ名を変更',
              currentValue: s.todoTabName,
              onSave: (v) {
                s.todoTabName = v;
                _notify();
              },
            ),
          ),
          _divider(),
          _buildEditableTabSwitch(
            icon: Icons.today_outlined,
            title: s.todayTabName,
            value: s.showTodayTab,
            onChanged: (v) {
              s.showTodayTab = v;
              _notify();
            },
            onRename: (v) {
              s.todayTabName = v;
              _notify();
            },
          ),
          _divider(),
          _buildEditableTabSwitch(
            icon: Icons.check_circle_outline,
            title: s.doneTabName,
            value: s.showDoneTab,
            onChanged: (v) {
              s.showDoneTab = v;
              _notify();
            },
            onRename: (v) {
              s.doneTabName = v;
              _notify();
            },
          ),
          _divider(),
          _buildEditableTabSwitch(
            icon: Icons.lightbulb_outline,
            title: s.futureTabName,
            value: s.showFutureTab,
            onChanged: (v) {
              s.showFutureTab = v;
              _notify();
            },
            onRename: (v) {
              s.futureTabName = v;
              _notify();
            },
          ),
          _divider(),
          ListTile(
            leading: Icon(Icons.refresh, color: Colors.grey.shade500),
            title: Text(
              'タブ名をデフォルトに戻す',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            onTap: () {
              s.todoTabName = 'やること';
              s.todayTabName = '今日やること';
              s.doneTabName = '完了済み';
              s.futureTabName = 'やりたいこと';
              _notify();
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('タブ名をデフォルトに戻しました')));
            },
          ),
        ],
      ),
    ];
  }

  Widget _buildEditableTabSwitch({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    required ValueChanged<String> onRename,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SwitchListTile(
          secondary: Icon(icon, color: s.primaryColor),
          title: Text(title),
          subtitle: const Text('タブの表示/非表示'),
          value: value,
          activeThumbColor: s.primaryColor,
          onChanged: onChanged,
        ),
        Padding(
          padding: const EdgeInsets.only(left: 56, right: 16, bottom: 8),
          child: InkWell(
            onTap: () => _showTextEditDialog(
              title: 'タブ名を変更',
              currentValue: title,
              onSave: onRename,
            ),
            child: Row(
              children: [
                Text(
                  '名前を変更',
                  style: TextStyle(color: s.accentColor, fontSize: 13),
                ),
                const SizedBox(width: 4),
                Icon(Icons.edit, size: 14, color: s.accentColor),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
