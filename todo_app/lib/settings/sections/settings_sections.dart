part of '../../settings_page.dart';

extension _SettingsSections on _SettingsPageState {
  List<Widget> _buildSettingsSections() {
    return [
      ..._buildAppTitleSection(),
      ..._buildTabSettingsSection(),
      ..._buildTaskTagSection(),
      ..._buildBackupSection(),
      ..._buildBehaviorSection(),
      ..._buildSortSection(),
      ..._buildThemeSection(),
      const SizedBox(height: 32),
    ];
  }
}
