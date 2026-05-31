part of '../main.dart';

extension _TodoHomeEditDialog on _TodoHomePageState {
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
