part of '../../../main.dart';

extension _TodoHomeTaskTagFilter on _TodoHomePageState {
  Widget _buildTaskTagFilter() {
    // 文字拡大に合わせて高さも伸ばし、チップ内テキストの重なりを防ぐ
    final filterHeight = 52 * MediaQuery.textScalerOf(context).scale(1);
    if (s.taskTags.isEmpty) {
      return Container(
        height: filterHeight,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ActionChip(
          avatar: Icon(Icons.label_outline, color: s.primaryColor, size: 18),
          label: const Text('タグを追加'),
          backgroundColor: Colors.white,
          side: BorderSide(color: Colors.grey.shade300),
          labelStyle: TextStyle(
            color: s.primaryColor,
            fontWeight: FontWeight.bold,
          ),
          onPressed: _showAddTaskTagDialog,
        ),
      );
    }

    final tags = [allTaskCategoriesLabel, ...s.taskTags];

    return Container(
      height: filterHeight,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: tags.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          // 「すべて」(index 0) のすぐ右に「＋」追加ボタンを置く。
          // タグが1つ以上ある場合はアイコンのみ表示する。
          if (index == 1) {
            return ActionChip(
              label: Icon(Icons.add, color: s.primaryColor, size: 18),
              labelPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              backgroundColor: Colors.white,
              side: BorderSide(color: Colors.grey.shade300),
              tooltip: 'タグを追加',
              onPressed: _showAddTaskTagDialog,
            );
          }

          // index 0 は「すべて」、index 2以降は実タグ（+ボタン分ずらす）
          final tag = index == 0 ? tags[0] : tags[index - 1];
          final isSelected = tag == _selectedTaskTagFilter;
          final canEditTag = tag != allTaskCategoriesLabel;

          return GestureDetector(
            onLongPress: canEditTag ? () => _showTaskTagActions(tag) : null,
            child: ChoiceChip(
              label: Text(tag),
              selected: isSelected,
              showCheckmark: false,
              selectedColor: s.primaryColor,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              side: BorderSide(
                color: isSelected ? s.primaryColor : Colors.grey.shade300,
              ),
              onSelected: (_) {
                _updateState(() {
                  _selectedTaskTagFilter = tag;
                });
              },
            ),
          );
        },
      ),
    );
  }
}
