import 'package:flutter/material.dart';
import 'app_settings.dart';
import 'notification_offset.dart';

part 'settings/actions/settings_actions.dart';
part 'settings/actions/settings_tag_actions.dart';
part 'settings/actions/settings_text_edit_dialog.dart';
part 'settings/sections/settings_sections.dart';
part 'settings/sections/settings_app_title_section.dart';
part 'settings/sections/settings_tab_section.dart';
part 'settings/sections/settings_tag_section.dart';
part 'settings/sections/settings_backup_section.dart';
part 'settings/sections/settings_data_section.dart';
part 'settings/sections/settings_account_section.dart';
part 'settings/sections/settings_behavior_section.dart';
part 'settings/sections/settings_notification_section.dart';
part 'settings/sections/settings_sort_section.dart';
part 'settings/sections/settings_theme_section.dart';
part 'settings/widgets/settings_widgets.dart';

// ─────────────────────────────────────────────
// 設定ページ
// ─────────────────────────────────────────────
class SettingsPage extends StatefulWidget {
  final AppSettings settings;
  final VoidCallback onSettingsChanged;
  final void Function(String oldTag, String newTag, {required bool isFuture})?
  onTaskTagRenamed;
  final void Function(String tag, {required bool isFuture})? onTaskTagDeleted;
  final Future<void> Function({required bool completedOnly})? onExportTasks;
  final Future<void> Function()? onImportTasks;
  final VoidCallback? onDeleteAllTasks;
  final String? userEmail;
  final VoidCallback? onSignOut;

  const SettingsPage({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
    this.onTaskTagRenamed,
    this.onTaskTagDeleted,
    this.onExportTasks,
    this.onImportTasks,
    this.onDeleteAllTasks,
    this.userEmail,
    this.onSignOut,
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
        // 広い画面（PC等）では中央寄せして横に間延びさせない
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: _buildSettingsSections(),
            ),
          ),
        ),
      ),
    );
  }
}
