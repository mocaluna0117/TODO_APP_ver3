part of '../../settings_page.dart';

extension _SettingsThemeSection on _SettingsPageState {
  List<Widget> _buildThemeSection() {
    return [
      _buildSectionHeader('画面の明るさ'),
      _buildCard(
        children: [
          for (final mode in ThemeMode.values) ...[
            _buildThemeModeTile(mode),
            if (mode != ThemeMode.values.last) _divider(),
          ],
        ],
      ),
      _buildSectionHeader('カラーテーマ'),
      _buildCard(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: AppSettings.colorThemes.map(_buildThemeSwatch).toList(),
            ),
          ),
        ],
      ),
    ];
  }

  Widget _buildThemeModeTile(ThemeMode mode) {
    final selected = s.themeMode == mode;
    final (icon, label, description) = switch (mode) {
      ThemeMode.system => (
        Icons.brightness_auto_outlined,
        '端末の設定に合わせる',
        '端末がダークモードなら暗い配色になります',
      ),
      ThemeMode.light => (Icons.light_mode_outlined, 'ライト', '明るい配色で固定します'),
      ThemeMode.dark => (Icons.dark_mode_outlined, 'ダーク', '暗い配色で固定します'),
    };

    return ListTile(
      leading: Icon(icon, color: selected ? s.primaryColor : Colors.grey),
      title: Text(label),
      subtitle: Text(description, style: const TextStyle(fontSize: 12)),
      trailing: selected
          ? Icon(Icons.check, color: s.primaryColor)
          : null,
      onTap: selected
          ? null
          : () {
              s.themeMode = mode;
              _notify();
            },
    );
  }

  Widget _buildThemeSwatch(ColorThemeOption theme) {
    final isSelected = s.primaryColor.toARGB32() == theme.primary.toARGB32();

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
                  ? Border.all(color: s.primaryTextColor, width: 3)
                  : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: theme.primary.withValues(alpha: 0.4),
                        blurRadius: 8,
                      ),
                    ]
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
              color: isSelected ? theme.primary : s.secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }
}
