part of '../main.dart';

extension _TodoHomeTaskDialogs on _TodoHomePageState {
  void _showAddTaskTagDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'タグを追加',
          style: TextStyle(color: s.primaryColor, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          hintLocales: const [Locale('ja', 'JP')],
          decoration: InputDecoration(
            hintText: 'タグ名',
            filled: true,
            fillColor: const Color(0xFFF5F5FA),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (_) {
            if (_addTaskTagFromHome(controller.text)) {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              if (_addTaskTagFromHome(controller.text)) {
                Navigator.pop(context);
              }
            },
            child: Text(
              '追加',
              style: TextStyle(
                color: s.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _addTaskTagFromHome(String value) {
    final tag = normalizeTaskTag(value);
    if (tag == null) return false;
    if (s.taskTags.contains(tag)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('「$tag」はすでにあります')));
      return false;
    }
    _updateState(() {
      s.taskTags.add(tag);
      _selectedTaskTagFilter = tag;
    });
    s.saveToPrefs();
    widget.onSettingsChanged();
    return true;
  }

  void _showTaskTagActions(String tag) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.edit, color: s.primaryColor),
                  title: const Text('タグ名を変更'),
                  subtitle: Text(tag),
                  onTap: () {
                    Navigator.pop(context);
                    _showRenameTaskTagDialog(tag);
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: Colors.red.shade300,
                  ),
                  title: const Text('タグを削除'),
                  subtitle: const Text('このタグが付いたタスクはタグなしになります'),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDeleteTaskTagFromHome(tag);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRenameTaskTagDialog(String oldTag) {
    final controller = TextEditingController(text: oldTag);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'タグ名を変更',
          style: TextStyle(color: s.primaryColor, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          hintLocales: const [Locale('ja', 'JP')],
          decoration: InputDecoration(
            hintText: 'タグ名',
            filled: true,
            fillColor: const Color(0xFFF5F5FA),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (_) {
            if (_renameTaskTagFromHome(oldTag, controller.text)) {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              if (_renameTaskTagFromHome(oldTag, controller.text)) {
                Navigator.pop(context);
              }
            },
            child: Text(
              '保存',
              style: TextStyle(
                color: s.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _renameTaskTagFromHome(String oldTag, String value) {
    final newTag = normalizeTaskTag(value);
    if (newTag == null) return false;
    if (newTag == oldTag) return true;
    if (s.taskTags.contains(newTag)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('「$newTag」はすでにあります')));
      return false;
    }

    final index = s.taskTags.indexOf(oldTag);
    if (index == -1) return false;
    s.taskTags[index] = newTag;
    _renameTaskTag(oldTag, newTag);
    s.saveToPrefs();
    widget.onSettingsChanged();
    return true;
  }

  Future<void> _confirmDeleteTaskTagFromHome(String tag) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'タグを削除',
          style: TextStyle(color: s.primaryColor, fontWeight: FontWeight.bold),
        ),
        content: Text('「$tag」を削除しますか？\nこのタグが付いたタスクはタグなしになります。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text(
              '削除',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (result != true) return;

    s.taskTags.remove(tag);
    _deleteTaskTag(tag);
    s.saveToPrefs();
    widget.onSettingsChanged();
  }

  // ─── 削除（確認あり/なし切替） ───
  Future<bool> _handleDelete(TodoItem item) async {
    if (!s.showDeleteConfirm) {
      _deleteItem(item);
      return true;
    }
    return await _showDeleteConfirmDialog(item);
  }

  Future<bool> _showDeleteConfirmDialog(TodoItem item) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'タスクを削除',
          style: TextStyle(fontWeight: FontWeight.bold, color: s.primaryColor),
        ),
        content: Text(
          '「${item.title}」を削除しますか？\nこの操作は取り消せません。',
          style: const TextStyle(fontSize: 15, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'キャンセル',
              style: TextStyle(color: Colors.grey, fontSize: 15),
            ),
          ),
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text(
              '削除',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ],
      ),
    );
    if (result == true) {
      _deleteItem(item);
      return true;
    }
    return false;
  }

  // ─── やることに移動ダイアログ ───
  void _showMoveToTodoDialog(TodoItem item) {
    final textController = TextEditingController(text: item.title);
    final descriptionController = TextEditingController(
      text: item.description ?? '',
    );

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) {
        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
            ),
            child: Material(
              color: Colors.transparent,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                child: Container(
                  padding: const EdgeInsets.only(left: 24, right: 24, top: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '「${s.todoTabName}」に移動',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: s.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '優先度はリセットされます',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: textController,
                          autofocus: true,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            hintText: 'タスクを入力...',
                            filled: true,
                            fillColor: const Color(0xFFF5F5FA),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: descriptionController,
                          textInputAction: TextInputAction.done,
                          minLines: 1,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: '概要を入力（任意）',
                            filled: true,
                            fillColor: const Color(0xFFF5F5FA),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.all(16),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () {
                            final trimmed = textController.text.trim();
                            if (trimmed.isEmpty) return;
                            _updateState(() {
                              item.title = trimmed;
                              item.description = _normalizeOptionalText(
                                descriptionController.text,
                              );
                              item.category = 'todo';
                              item.priority = TaskPriority.none;
                            });
                            _saveData();
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: s.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            '「${s.todoTabName}」に移動',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── やりたいことに戻すダイアログ ───
  void _showMoveToFutureDialog(TodoItem item) {
    final textController = TextEditingController(text: item.title);
    final descriptionController = TextEditingController(
      text: item.description ?? '',
    );
    var selectedTaskPriority = item.priority;

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 16,
                  right: 16,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.85,
                    ),
                    child: Container(
                      padding: const EdgeInsets.only(
                        left: 24,
                        right: 24,
                        top: 24,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '「${s.futureTabName}」に移動',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: s.primaryColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: textController,
                              autofocus: true,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                hintText: 'タスクを入力...',
                                filled: true,
                                fillColor: const Color(0xFFF5F5FA),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: descriptionController,
                              textInputAction: TextInputAction.done,
                              minLines: 1,
                              maxLines: 4,
                              decoration: InputDecoration(
                                hintText: '概要を入力（任意）',
                                filled: true,
                                fillColor: const Color(0xFFF5F5FA),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.all(16),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildTaskPriorityPicker(
                              selectedTaskPriority: selectedTaskPriority,
                              onChanged: (p) =>
                                  setSheetState(() => selectedTaskPriority = p),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () {
                                final trimmed = textController.text.trim();
                                if (trimmed.isEmpty) return;
                                _updateState(() {
                                  item.title = trimmed;
                                  item.description = _normalizeOptionalText(
                                    descriptionController.text,
                                  );
                                  item.category = 'future';
                                  item.priority = selectedTaskPriority;
                                });
                                _saveData();
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: s.primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                '「${s.futureTabName}」に移動',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ─── 編集ダイアログ ───
  void _showEditDialog(TodoItem item, {String tabKey = ''}) {
    final isFromTodayTab = tabKey == 'today';
    final textController = TextEditingController(text: item.title);
    final descriptionController = TextEditingController(
      text: item.description ?? '',
    );
    DateTime? selectedDate = item.dueDate;
    var selectedImageBase64List = [...item.imageBase64List];
    var selectedTaskTag = item.taskTag;
    var selectedRecurrenceRule = item.recurrenceRule;
    var selectedTaskPriority = item.priority;

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final mediaQuery = MediaQuery.of(context);
            final topInset = mediaQuery.padding.top;
            final keyboardInset = mediaQuery.viewInsets.bottom;
            final topOffset = topInset + 4;
            final bottomGap = keyboardInset > 0 ? 20.0 : 16.0;
            final maxModalHeight =
                (mediaQuery.size.height - topOffset - keyboardInset - bottomGap)
                    .clamp(240.0, mediaQuery.size.height * 0.8);
            void submit() {
              _editItem(
                item,
                textController.text,
                description: descriptionController.text,
                taskTag: selectedTaskTag,
                dueDate: selectedDate,
                recurrenceRule: selectedRecurrenceRule,
                imageBase64List: selectedImageBase64List,
                priority: selectedTaskPriority,
              );
              Navigator.pop(context);
            }

            return Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(
                  top: topOffset,
                  left: 16,
                  right: 16,
                  bottom: keyboardInset + bottomGap,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxModalHeight),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Flexible(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'タスクを編集',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: s.primaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: textController,
                                    autofocus: true,
                                    textInputAction: TextInputAction.next,
                                    decoration: InputDecoration(
                                      hintText: 'タスクを入力...',
                                      filled: true,
                                      fillColor: const Color(0xFFF5F5FA),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 14,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: descriptionController,
                                    textInputAction: TextInputAction.done,
                                    minLines: 1,
                                    maxLines: 4,
                                    onSubmitted: (_) => submit(),
                                    decoration: InputDecoration(
                                      hintText: '概要を入力（任意）',
                                      filled: true,
                                      fillColor: const Color(0xFFF5F5FA),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding: const EdgeInsets.all(16),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildTaskTagPicker(
                                    selectedTaskTag: selectedTaskTag,
                                    onChanged: (tag) => setSheetState(
                                      () => selectedTaskTag = tag,
                                    ),
                                  ),
                                  if (item.category == 'future') ...[
                                    const SizedBox(height: 12),
                                    _buildTaskPriorityPicker(
                                      selectedTaskPriority:
                                          selectedTaskPriority,
                                      onChanged: (p) => setSheetState(
                                        () => selectedTaskPriority = p,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  if (isFromTodayTab)
                                    _buildTimeOnlyPickerRow(
                                      selectedDate: selectedDate,
                                      onTimeSelected: (date) => setSheetState(
                                        () => selectedDate = date,
                                      ),
                                      onTimeCleared: () => setSheetState(
                                        () => selectedDate = null,
                                      ),
                                    )
                                  else
                                    _buildDatePickerRow(
                                      selectedDate: selectedDate,
                                      onDateSelected: (date) => setSheetState(
                                        () => selectedDate = date,
                                      ),
                                      onDateCleared: () => setSheetState(
                                        () => selectedDate = null,
                                      ),
                                    ),
                                  const SizedBox(height: 12),
                                  _buildRecurrencePicker(
                                    selectedRecurrenceRule:
                                        selectedRecurrenceRule,
                                    onChanged: (rule) => setSheetState(
                                      () => selectedRecurrenceRule = rule,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildImagePickerRow(
                                    imageBase64List: selectedImageBase64List,
                                    onImagesChanged: (imageBase64List) =>
                                        setSheetState(
                                          () => selectedImageBase64List =
                                              imageBase64List,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: s.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              '保存',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
