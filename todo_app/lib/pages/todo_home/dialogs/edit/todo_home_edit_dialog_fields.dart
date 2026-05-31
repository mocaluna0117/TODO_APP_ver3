part of '../../../../main.dart';

extension _TodoHomeEditDialogFields on _TodoHomePageState {
  Widget _buildEditDialogFields({
    required TodoItem item,
    required bool isFromTodayTab,
    required _EditTodoDraft draft,
    required VoidCallback submit,
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
        _buildEditDialogDescriptionField(draft, submit),
        const SizedBox(height: 12),
        _buildTaskTagPicker(
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
