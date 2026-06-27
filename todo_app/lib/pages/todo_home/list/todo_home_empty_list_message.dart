part of '../../../main.dart';

extension _TodoHomeEmptyListMessage on _TodoHomePageState {
  Widget _buildEmptyListMessage(String category) {
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
                : Icons.inbox_outlined,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 12),
          Text(
            hasTagFilter
                ? '$tagFilterのタスクはありません'
                : category == 'done'
                ? '${s.doneTabName}のタスクはありません'
                : category == 'today'
                ? '${s.todayTabName}のタスクはありません'
                : '${_tabName(category)}を追加しましょう',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}
