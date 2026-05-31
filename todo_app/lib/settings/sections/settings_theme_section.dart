part of '../../settings_page.dart';

extension _SettingsThemeSection on _SettingsPageState {
  List<Widget> _buildThemeSection() {
    return [
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
                  ? Border.all(color: Colors.black87, width: 3)
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
              color: isSelected ? theme.primary : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
