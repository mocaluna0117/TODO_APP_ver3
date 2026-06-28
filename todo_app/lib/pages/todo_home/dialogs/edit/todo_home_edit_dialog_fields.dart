part of '../../../../main.dart';

extension _TodoHomeEditDialogFields on _TodoHomePageState {
  Widget _buildEditDialogFields({
    required TodoItem item,
    required bool isFromTodayTab,
    required _EditTodoDraft draft,
    required StateSetter setSheetState,
  }) {
    return Column(
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
        _buildEditDialogTitleField(draft),
        const SizedBox(height: 12),
        _buildEditDialogDescriptionField(draft),
        const SizedBox(height: 12),
        _buildLinksField(
          controllers: draft.linkControllers,
          onAdd: () =>
              setSheetState(() => draft.linkControllers.add(TextEditingController())),
          onRemove: (i) =>
              setSheetState(() => draft.linkControllers.removeAt(i)),
        ),
        const SizedBox(height: 12),
        _buildTaskTagPicker(
          category: item.category,
          selectedTaskTag: draft.selectedTaskTag,
          onChanged: (tag) => setSheetState(() => draft.selectedTaskTag = tag),
        ),
        if (item.category == 'future') ...[
          const SizedBox(height: 12),
          _buildTaskPriorityPicker(
            selectedTaskPriority: draft.selectedTaskPriority,
            onChanged: (p) =>
                setSheetState(() => draft.selectedTaskPriority = p),
          ),
        ],
        const SizedBox(height: 12),
        if (isFromTodayTab)
          _buildTimeOnlyPickerRow(
            selectedDate: draft.selectedDate,
            onTimeSelected: (date) =>
                setSheetState(() => draft.selectedDate = date),
            onTimeCleared: () => setSheetState(() => draft.selectedDate = null),
          )
        else
          _buildDatePickerRow(
            selectedDate: draft.selectedDate,
            onDateSelected: (date) =>
                setSheetState(() => draft.selectedDate = date),
            onDateCleared: () => setSheetState(() => draft.selectedDate = null),
          ),
        const SizedBox(height: 12),
        _buildRecurrencePicker(
          selectedRecurrenceRule: draft.selectedRecurrenceRule,
          onChanged: (rule) =>
              setSheetState(() => draft.selectedRecurrenceRule = rule),
        ),
        if (draft.selectedDate != null) ...[
          const SizedBox(height: 12),
          _buildNotificationTimingPicker(
            dueDate: draft.selectedDate!,
            selectedOffsets: draft.selectedNotificationOffsets,
            onChanged: (offsets) =>
                setSheetState(() => draft.selectedNotificationOffsets = offsets),
          ),
        ],
        const SizedBox(height: 12),
        _buildImagePickerRow(
          imageBase64List: draft.selectedImageBase64List,
          onImagesChanged: (imageBase64List) => setSheetState(
            () => draft.selectedImageBase64List = imageBase64List,
          ),
        ),
      ],
    );
  }
}
