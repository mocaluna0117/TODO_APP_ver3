part of '../../../main.dart';

extension _TodoHomeTaskTagFilter on _TodoHomePageState {
  Widget _buildTaskTagFilter(String category) {
    final groupTags = s.tagsForCategory(category);
    final selectedFilter = _selectedTagFilterFor(category);
    // 文字拡大に合わせて高さも伸ばし、チップ内テキストの重なりを防ぐ
    final filterHeight = 52 * MediaQuery.textScalerOf(context).scale(1);
    if (groupTags.isEmpty) {
      return Container(
        height: filterHeight,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ActionChip(
          avatar: Icon(Icons.label_outline, color: s.accentOnSurface, size: 18),
          label: const Text('タグを追加'),
          backgroundColor: s.surfaceColor,
          side: BorderSide(color: s.outlineColor),
          labelStyle: TextStyle(
            color: s.accentOnSurface,
            fontWeight: FontWeight.bold,
          ),
          onPressed: () => _showAddTaskTagDialog(category),
        ),
      );
    }

    return Container(
      height: filterHeight,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const SizedBox(width: 16),
          // 「すべて」と「＋」は並び替えの対象外なので、リストの外に置く
          _buildTagFilterChip(
            allTaskCategoriesLabel,
            category,
            selectedFilter,
          ),
          const SizedBox(width: 8),
          _buildAddTagChip(category),
          const SizedBox(width: 8),
          Expanded(
            child: ReorderableListView.builder(
              // フォントの遅延読み込み後にチップを作り直し、文字幅を再計測させる
              // （Webで日本語フォント読み込み前の幅のまま文字が途切れるのを防ぐ）
              key: ValueKey('tag-filter-$category-$_fontGeneration'),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 16),
              itemCount: groupTags.length,
              // 既定のままだと、PCでは各チップに「≡」のつまみが重ねて
              // 描画されてしまうため、自分でドラッグの起点を仕込む
              buildDefaultDragHandles: false,
              onReorderItem: (oldIndex, newIndex) =>
                  _reorderTaskTagsFromHome(category, oldIndex, newIndex),
              itemBuilder: (context, index) {
                final tag = groupTags[index];
                final chip = Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Center(
                    child: _buildTagFilterChip(tag, category, selectedFilter),
                  ),
                );
                final key = ValueKey('tag-$category-$tag');
                // タッチ操作は長押しで、マウスはそのままドラッグで並び替える
                // （タッチで即ドラッグにすると横スクロールができなくなる）
                return _usesTouchDrag
                    ? ReorderableDelayedDragStartListener(
                        key: key,
                        index: index,
                        child: chip,
                      )
                    : ReorderableDragStartListener(
                        key: key,
                        index: index,
                        child: chip,
                      );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 指で操作する端末かどうか（並び替えの起点を長押しにするか決める）
  bool get _usesTouchDrag => switch (Theme.of(context).platform) {
    TargetPlatform.iOS || TargetPlatform.android => true,
    _ => false,
  };

  // 絞り込みチップ1つ。長押しでつかんで並び替えられる（並び替えは
  // ReorderableListView 側が処理するので、ここではタップだけ扱う）。
  Widget _buildTagFilterChip(String tag, String category, String selectedFilter) {
    final isSelected = tag == selectedFilter;
    return ChoiceChip(
      label: Text(tag),
      selected: isSelected,
      showCheckmark: false,
      selectedColor: s.primaryColor,
      backgroundColor: s.surfaceColor,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : s.primaryTextColor,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? s.accentOnSurface : s.outlineColor,
      ),
      onSelected: (_) {
        _updateState(() {
          _setSelectedTagFilter(category, tag);
        });
      },
    );
  }

  Widget _buildAddTagChip(String category) {
    return ActionChip(
      label: Icon(Icons.add, color: s.accentOnSurface, size: 18),
      labelPadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      backgroundColor: s.surfaceColor,
      side: BorderSide(color: s.outlineColor),
      tooltip: 'タグを追加',
      onPressed: () => _showAddTaskTagDialog(category),
    );
  }

  // 絞り込み行での並び替え。設定画面で変えたときと同じ並び順が使われる。
  void _reorderTaskTagsFromHome(String category, int oldIndex, int newIndex) {
    final groupTags = s.tagsForCategory(category);
    if (oldIndex < 0 || oldIndex >= groupTags.length) return;
    _updateState(() {
      final moved = groupTags.removeAt(oldIndex);
      groupTags.insert(newIndex.clamp(0, groupTags.length), moved);
    });
    s.saveToPrefs();
    widget.onSettingsChanged();
  }
}
