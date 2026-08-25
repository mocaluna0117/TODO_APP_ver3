part of '../../../main.dart';

extension _TodoHomeEmptyListMessage on _TodoHomePageState {
  Widget _buildEmptyListMessage(String category) {
    final query = _searchQuery.trim();
    if (query.isNotEmpty) {
      // 他のタブに一致があるなら、探し先を示してあげる
      final others = _searchMatchesInOtherTabs(category);
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off, size: 64, color: s.outlineColor),
              const SizedBox(height: 12),
              Text(
                '「$query」に一致するタスクはありません',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey.shade400),
              ),
              if (others > 0) ...[
                const SizedBox(height: 8),
                Text(
                  '他のタブに$others件あります',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: s.secondaryTextColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final tagFilter = _selectedTagFilterFor(category);
    // 完了タブは絞り込みなし
    final hasTagFilter =
        category != 'done' && tagFilter != allTaskCategoriesLabel;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            category == 'done'
                ? Icons.check_circle_outline
                : category == 'future'
                ? Icons.lightbulb_outline
                : category == 'today'
                ? Icons.today_outlined
                : category == 'tomorrow'
                ? Icons.event_outlined
                : Icons.inbox_outlined,
            size: 64,
            color: s.outlineColor,
          ),
          const SizedBox(height: 12),
          Text(
            hasTagFilter
                ? '$tagFilterのタスクはありません'
                // 期限で自動的に集まるタブは「追加しましょう」ではなく件数の話にする
                : (category == 'done' ||
                      category == 'today' ||
                      category == 'tomorrow')
                ? '${_tabName(category)}のタスクはありません'
                : '${_tabName(category)}を追加しましょう',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}
