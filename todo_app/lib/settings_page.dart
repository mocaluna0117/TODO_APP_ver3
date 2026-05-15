import 'package:flutter/material.dart';
import 'app_settings.dart';
import 'notification_service.dart'; // 追加

// ─────────────────────────────────────────────
// 設定ページ
// ─────────────────────────────────────────────
class SettingsPage extends StatefulWidget {
  final AppSettings settings;
  final VoidCallback onSettingsChanged;

  const SettingsPage({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  AppSettings get s => widget.settings;

  void _notify() {
    widget.settings.saveToPrefs();
    widget.onSettingsChanged();
    setState(() {});
  }

  // ─── テキスト編集用ダイアログ ───
  void _showTextEditDialog({
    required String title,
    required String currentValue,
    required ValueChanged<String> onSave,
  }) {
    final controller = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: TextStyle(color: s.primaryColor, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF5F5FA),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) { onSave(v.trim()); }
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              final v = controller.text.trim();
              if (v.isNotEmpty) { onSave(v); }
              Navigator.pop(context);
            },
            child: Text('保存', style: TextStyle(color: s.primaryColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('設定', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: s.primaryColor,
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFF5F5FA),
      body: SafeArea(
        child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          // ── アプリ名 ──
          _buildSectionHeader('アプリ名'),
          _buildCard(
            children: [
              ListTile(
                leading: Icon(Icons.title, color: s.primaryColor),
                title: const Text('アプリタイトル'),
                subtitle: Text(s.appTitle),
                trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
                onTap: () => _showTextEditDialog(
                  title: 'アプリタイトルを変更',
                  currentValue: s.appTitle,
                  onSave: (v) { s.appTitle = v; _notify(); },
                ),
              ),
            ],
          ),

          // ── タブ設定 ──
          _buildSectionHeader('タブ設定'),
          _buildCard(
            children: [
              // やること（常にON）
              ListTile(
                leading: Icon(Icons.inbox, color: s.primaryColor),
                title: Text(s.todoTabName),
                subtitle: const Text('常に表示'),
                trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
                onTap: () => _showTextEditDialog(
                  title: 'タブ名を変更',
                  currentValue: s.todoTabName,
                  onSave: (v) { s.todoTabName = v; _notify(); },
                ),
              ),
              _divider(),
              // 完了済み
              SwitchListTile(
                secondary: Icon(Icons.check_circle_outline, color: s.primaryColor),
                title: Text(s.doneTabName),
                subtitle: const Text('タブの表示/非表示'),
                value: s.showDoneTab,
                activeColor: s.primaryColor,
                onChanged: (v) { s.showDoneTab = v; _notify(); },
              ),
              Padding(
                padding: const EdgeInsets.only(left: 56, right: 16, bottom: 8),
                child: InkWell(
                  onTap: () => _showTextEditDialog(
                    title: 'タブ名を変更',
                    currentValue: s.doneTabName,
                    onSave: (v) { s.doneTabName = v; _notify(); },
                  ),
                  child: Row(
                    children: [
                      Text('名前を変更', style: TextStyle(color: s.accentColor, fontSize: 13)),
                      const SizedBox(width: 4),
                      Icon(Icons.edit, size: 14, color: s.accentColor),
                    ],
                  ),
                ),
              ),
              _divider(),
              // 今後やりたいこと
              SwitchListTile(
                secondary: Icon(Icons.lightbulb_outline, color: s.primaryColor),
                title: Text(s.futureTabName),
                subtitle: const Text('タブの表示/非表示'),
                value: s.showFutureTab,
                activeColor: s.primaryColor,
                onChanged: (v) { s.showFutureTab = v; _notify(); },
              ),
              Padding(
                padding: const EdgeInsets.only(left: 56, right: 16, bottom: 8),
                child: InkWell(
                  onTap: () => _showTextEditDialog(
                    title: 'タブ名を変更',
                    currentValue: s.futureTabName,
                    onSave: (v) { s.futureTabName = v; _notify(); },
                  ),
                  child: Row(
                    children: [
                      Text('名前を変更', style: TextStyle(color: s.accentColor, fontSize: 13)),
                      const SizedBox(width: 4),
                      Icon(Icons.edit, size: 14, color: s.accentColor),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── 動作設定 ──
          _buildSectionHeader('動作設定'),
          _buildCard(
            children: [
              SwitchListTile(
                secondary: Icon(Icons.warning_amber_rounded, color: s.primaryColor),
                title: const Text('削除時の確認ダイアログ'),
                subtitle: const Text('削除前に確認を表示する'),
                value: s.showDeleteConfirm,
                activeColor: s.primaryColor,
                onChanged: (v) { s.showDeleteConfirm = v; _notify(); },
              ),
              _divider(),
              ListTile(
                leading: Icon(Icons.notifications_active, color: s.primaryColor),
                title: const Text('期限の通知タイミング'),
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
                      // 通知設定が変更されたら親に通知を再スケジュールさせるフラグとしても使えるが
                      // ここでは直接呼ばず、親が戻ってきた時にrescheduleAllを呼ぶのが良い
                    }
                  },
                ),
              ),
            ],
          ),

          // ── 並び順 ──
          _buildSectionHeader('並び順'),
          _buildCard(
            children: [
              RadioGroup<SortOrder>(
                groupValue: s.sortOrder,
                onChanged: (v) { if (v != null) { s.sortOrder = v; _notify(); } },
                child: Column(
                  children: [
                    RadioListTile<SortOrder>(
                      secondary: Icon(Icons.arrow_upward, color: s.primaryColor),
                      title: const Text('期限が近い順（昇順）'),
                      value: SortOrder.dueDateAsc,
                      activeColor: s.primaryColor,
                    ),
                    _divider(),
                    RadioListTile<SortOrder>(
                      secondary: Icon(Icons.arrow_downward, color: s.primaryColor),
                      title: const Text('期限が遠い順（降順）'),
                      value: SortOrder.dueDateDesc,
                      activeColor: s.primaryColor,
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ── カラーテーマ ──
          _buildSectionHeader('カラーテーマ'),
          _buildCard(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: AppSettings.colorThemes.map((theme) {
                    final isSelected = s.primaryColor.value == theme.primary.value;
                    return GestureDetector(
                      onTap: () {
                        s.primaryColor = theme.primary;
                        s.accentColor = theme.accent;
                        _notify();
                      },
                      child: Column(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [theme.primary, theme.accent],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(color: Colors.black87, width: 3)
                                  : null,
                              boxShadow: isSelected
                                  ? [BoxShadow(color: theme.primary.withOpacity(0.4), blurRadius: 8)]
                                  : null,
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, color: Colors.white, size: 24)
                                : null,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            theme.name,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? theme.primary : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
      ),
    );
  }

  // ── ヘルパーウィジェット ──
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }

  Widget _divider() => Divider(height: 1, indent: 56, color: Colors.grey.shade200);
}
