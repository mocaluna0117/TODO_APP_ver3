part of '../../settings_page.dart';

extension _SettingsSections on _SettingsPageState {
  List<Widget> _buildSettingsSections() {
    return [
      ..._buildAppTitleSection(),
      ..._buildTaskTagSection(),
      ..._buildBehaviorSection(),
      ..._buildNotificationSection(),
      ..._buildSortSection(),
      ..._buildThemeSection(),
      ..._buildBackupSection(),
      ..._buildDataSection(),
      ..._buildInquirySection(),
      ..._buildAccountSection(),
      const SizedBox(height: 32),
    ];
  }
}
