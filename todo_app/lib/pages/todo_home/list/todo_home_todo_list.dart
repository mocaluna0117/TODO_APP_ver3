part of '../../../main.dart';

extension _TodoHomeTodoList on _TodoHomePageState {
  // ─── リスト表示 ───
  Widget _buildTodoList(String category) {
    final items = _itemsByCategory(category);

    final content = Column(
      // タグ行とカード列の左端を揃える（中央寄せに縮まないようにする）
      crossAxisAlignment: CrossAxisAlignment.stretch,
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

    // 2ペイン時は左ペインの幅いっぱいにカードを表示する
    // （ペイン幅はユーザーがドラッグで調整するため上限を設けない）
    if (_isWideLayout) return content;

    // 1ペイン時は横に間延びしないよう、コンテンツ幅を制限して中央寄せ
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
        child: content,
      ),
    );
  }
}
