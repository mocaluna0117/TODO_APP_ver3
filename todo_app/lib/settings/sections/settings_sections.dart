part of '../../settings_page.dart';

extension _SettingsSections on _SettingsPageState {
  List<Widget> _buildSettingsSections() {
    return [
      ..._buildAppTitleSection(),
      ..._buildTabSettingsSection(),
      ..._buildTaskTagSection(),
      ..._buildBehaviorSection(),
      ..._buildSortSection(),
      ..._buildThemeSection(),
      ..._buildBackupSection(),
      ..._buildDataSection(),
      const SizedBox(height: 32),
    ];
  }
}
