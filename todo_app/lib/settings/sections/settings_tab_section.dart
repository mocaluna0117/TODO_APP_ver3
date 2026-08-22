part of '../../settings_page.dart';

extension _SettingsTabSection on _SettingsPageState {
  List<Widget> _buildTabSettingsSection() {
    return [
      _buildSectionHeader('タブ設定'),
      _buildCard(
        children: [
          ListTile(
            leading: Icon(Icons.inbox, color: s.primaryColor),
            title: _tabTitleWithEdit(s.todoTabName, (v) {
              s.todoTabName = v;
              _notify();
            }),
            subtitle: const Text('常に表示', style: TextStyle(fontSize: 12)),
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
    return SwitchListTile(
      secondary: Icon(icon, color: s.primaryColor),
      title: _tabTitleWithEdit(title, onRename),
      subtitle: const Text('タブの表示/非表示', style: TextStyle(fontSize: 12)),
      value: value,
      activeThumbColor: s.primaryColor,
      onChanged: onChanged,
    );
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
