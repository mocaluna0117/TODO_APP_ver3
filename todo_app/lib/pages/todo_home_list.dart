part of '../main.dart';

extension _TodoHomeList on _TodoHomePageState {
  // ─── リスト表示 ───
  Widget _buildTodoList(String category) {
    final items = _itemsByCategory(category);

    return Column(
      children: [
        _buildTaskTagFilter(),
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

  Widget _buildTaskTagFilter() {
    if (s.taskTags.isEmpty) {
      return Container(
        height: 52,
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
      height: 52,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: tags.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == tags.length) {
            return ActionChip(
              avatar: Icon(Icons.add, color: s.primaryColor, size: 18),
              label: const Text('タグを追加'),
              backgroundColor: Colors.white,
              side: BorderSide(color: Colors.grey.shade300),
              labelStyle: TextStyle(
                color: s.primaryColor,
                fontWeight: FontWeight.bold,
              ),
              onPressed: _showAddTaskTagDialog,
            );
          }

          final tag = tags[index];
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

  Widget _buildEmptyListMessage(String category) {
    final hasTagFilter = _selectedTaskTagFilter != allTaskCategoriesLabel;

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
                ? '$_selectedTaskTagFilterのタスクはありません'
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

  // ─── 個別カード ───
  Widget _buildTodoCard(TodoItem item, String category) {
    Widget compactIconButton({
      required Widget icon,
      required VoidCallback? onPressed,
      required String tooltip,
    }) {
      return IconButton(
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(width: 34, height: 34),
        padding: EdgeInsets.zero,
        icon: icon,
        onPressed: onPressed,
        tooltip: tooltip,
      );
    }

    return AnimatedOpacity(
      opacity: _fadingOutItems.contains(item.id) ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      child: Dismissible(
        key: ValueKey(item),
        direction: s.enableSwipeDelete
            ? DismissDirection.endToStart
            : DismissDirection.none,
        confirmDismiss: (_) => _handleDelete(item),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.red.shade400,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        child: Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: Colors.white,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            onTap: category == 'done'
                ? null
                : () => _showEditDialog(item, tabKey: category),
            leading: category == 'done'
                ? null
                : Checkbox(
                    value: item.isDone,
                    onChanged: (_) => _completeItemWithFade(item),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    activeColor: s.primaryColor,
                  ),
            title: Text(
              item.title,
              style: TextStyle(
                fontSize: 16,
                decoration: item.isDone
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
                color: item.isDone ? Colors.grey : Colors.black87,
              ),
            ),
            subtitle: _buildTodoSubtitle(item),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.isDone)
                  compactIconButton(
                    icon: Icon(Icons.replay, color: s.accentColor),
                    onPressed: () async {
                      final result = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          title: Text(
                            '未完了に戻す',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: s.primaryColor,
                            ),
                          ),
                          content: Text(
                            '「${item.title}」を未完了に戻しますか？',
                            style: const TextStyle(fontSize: 15, height: 1.5),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text(
                                'キャンセル',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                            TextButton(
                              autofocus: true,
                              onPressed: () => Navigator.pop(context, true),
                              child: Text(
                                '戻す',
                                style: TextStyle(
                                  color: s.primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                      if (result == true) _toggleItem(item);
                    },
                    tooltip: '未完了に戻す',
                  ),
                if (!item.isDone && item.category == 'future')
                  compactIconButton(
                    icon: Icon(
                      Icons.arrow_circle_left_outlined,
                      color: s.primaryColor,
                      size: 22,
                    ),
                    onPressed: () => _showMoveToTodoDialog(item),
                    tooltip: 'やることに移動',
                  ),
                if (!item.isDone && item.category == 'todo')
                  compactIconButton(
                    icon: Icon(
                      Icons.arrow_circle_right_outlined,
                      color: Colors.orange.shade400,
                      size: 22,
                    ),
                    onPressed: () => _showMoveToFutureDialog(item),
                    tooltip: 'やりたいことに戻す',
                  ),
                if (category == 'today')
                  compactIconButton(
                    icon: Icon(
                      Icons.access_time,
                      color: item.dueDate != null
                          ? s.primaryColor
                          : const Color(0xFFAAAAAA),
                      size: 20,
                    ),
                    onPressed: () => _showTimePickerForItem(item),
                    tooltip: '時間を設定',
                  )
                else if (category != 'done')
                  compactIconButton(
                    icon: Icon(
                      Icons.calendar_today,
                      color: item.dueDate != null
                          ? s.primaryColor
                          : const Color(0xFFAAAAAA),
                      size: 20,
                    ),
                    onPressed: () => _showDatePickerForItem(item),
                    tooltip: '期限を設定',
                  ),
                compactIconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: Colors.red.shade300,
                    size: 20,
                  ),
                  onPressed: () => _handleDelete(item),
                  tooltip: '削除',
                ),
              ],
            ),
          ),
        ),
      ), // Dismissible
    ); // AnimatedOpacity
  }

  Widget? _buildTodoSubtitle(TodoItem item) {
    final imageBytesList = _decodeImages(item.imageBase64List);
    final description = item.description;
    final hasTaskPriority =
        item.category == 'future' && item.priority != TaskPriority.none;
    if (item.taskTag == null &&
        !item.isRecurring &&
        !hasTaskPriority &&
        description == null &&
        item.dueDate == null &&
        imageBytesList.isEmpty) {
      return null;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.taskTag != null || item.isRecurring || hasTaskPriority)
            _buildTaskLabels(item, hasTaskPriority: hasTaskPriority),
          if ((item.taskTag != null || item.isRecurring || hasTaskPriority) &&
              (description != null ||
                  item.dueDate != null ||
                  imageBytesList.isNotEmpty))
            const SizedBox(height: 8),
          if (description != null)
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: item.isDone ? Colors.grey.shade500 : Colors.black54,
              ),
            ),
          if (description != null &&
              (item.dueDate != null || imageBytesList.isNotEmpty))
            const SizedBox(height: 8),
          if (item.dueDate != null)
            Text(
              _formatTodoCardDueDate(item.dueDate!),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: TextStyle(
                fontSize: 12,
                color: item.isOverdue ? Colors.red : Colors.grey.shade700,
                fontWeight: item.isOverdue
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          if (imageBytesList.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              child: PageView.builder(
                itemCount: imageBytesList.length,
                itemBuilder: (context, index) {
                  final imageBytes = imageBytesList[index];
                  return GestureDetector(
                    onTap: () =>
                        _showImagePreview(imageBytesList, initialIndex: index),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Container(
                              color: const Color(0xFFF5F5FA),
                              child: Image.memory(
                                imageBytes,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          if (imageBytesList.length > 1)
                            Positioned(
                              left: 8,
                              bottom: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '${index + 1}/${imageBytesList.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTaskLabels(TodoItem item, {bool hasTaskPriority = false}) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (hasTaskPriority) _buildTaskPriorityLabel(item),
        if (item.taskTag != null) _buildTaskTagLabel(item),
        if (item.isRecurring) _buildRecurrenceLabel(item),
      ],
    );
  }

  Widget _buildTaskPriorityLabel(TodoItem item) {
    final color = priorityColor(item.priority);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: item.isDone ? 0.08 : 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPriorityStars(
            item.priority,
            size: 12,
            color: item.isDone ? Colors.grey.shade500 : color,
          ),
        ],
      ),
    );
  }

  Widget _buildTaskTagLabel(TodoItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: s.primaryColor.withValues(alpha: item.isDone ? 0.08 : 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        item.taskTag!,
        style: TextStyle(
          color: item.isDone ? Colors.grey.shade500 : s.primaryColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildRecurrenceLabel(TodoItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: s.accentColor.withValues(alpha: item.isDone ? 0.08 : 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.repeat,
            size: 11,
            color: item.isDone ? Colors.grey.shade500 : s.primaryColor,
          ),
          const SizedBox(width: 3),
          Text(
            item.recurrenceRule.label,
            style: TextStyle(
              color: item.isDone ? Colors.grey.shade500 : s.primaryColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
