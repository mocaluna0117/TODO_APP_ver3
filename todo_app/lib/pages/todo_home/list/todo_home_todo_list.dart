part of '../../../main.dart';

extension _TodoHomeTodoList on _TodoHomePageState {
  // ─── リスト表示 ───
  Widget _buildTodoList(String category) {
    final items = _itemsByCategory(category);

    return Column(
      children: [
        // 完了タブはタグ絞り込みを表示しない
        if (category != 'done') _buildTaskTagFilter(category),
        Expanded(
          child: items.isEmpty
              ? _buildEmptyListMessage(category)
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _buildTodoCard(items[i], category),
                ),
        ),
      ],
    );
  }
}
