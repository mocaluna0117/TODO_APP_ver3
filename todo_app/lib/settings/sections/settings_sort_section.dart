part of '../../settings_page.dart';

extension _SettingsSortSection on _SettingsPageState {
  List<Widget> _buildSortSection() {
    return [
      _buildSectionHeader('並び順'),
      _buildCard(
        children: [
          RadioGroup<SortOrder>(
            groupValue: s.sortOrder,
            onChanged: (v) {
              if (v != null) {
                s.sortOrder = v;
                _notify();
              }
            },
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
    ];
  }
}
