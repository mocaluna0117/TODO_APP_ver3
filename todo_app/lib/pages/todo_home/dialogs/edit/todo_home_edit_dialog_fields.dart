part of '../../../../main.dart';

extension _TodoHomeEditDialogFields on _TodoHomePageState {
  Widget _buildEditDialogFields({
    required TodoItem item,
    required String tabKey,
    required _EditTodoDraft draft,
    required StateSetter setSheetState,
  }) {
    // 日付が決まっているタブ（今日/明日やること）では時刻だけ選ばせる
    final fixedDay = _fixedDayForTab(tabKey);
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
        if (fixedDay != null)
          _buildTimeOnlyPickerRow(
            day: fixedDay,
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
          selectedRecurrence: draft.selectedRecurrence,
          dueDate: draft.selectedDate,
          onChanged: (recurrence) =>
              setSheetState(() => draft.selectedRecurrence = recurrence),
        ),
        // 期限が既に過ぎている場合は通知を鳴らせないため、通知の選択自体を出さない
        if (draft.selectedDate != null &&
            draft.selectedDate!.isAfter(DateTime.now())) ...[
          const SizedBox(height: 12),
          _buildNotificationTimingPicker(
            dueDate: draft.selectedDate!,
            selectedOffsets: draft.selectedNotificationOffsets,
            onChanged: (offsets) =>
                setSheetState(() => draft.selectedNotificationOffsets = offsets),
          ),
        ],
        const SizedBox(height: 12),
        _buildFilePickerRow(
          attachments: draft.selectedFiles,
          pendingFiles: draft.pendingFiles,
          onAttachmentsChanged: (files) =>
              setSheetState(() => draft.selectedFiles = files),
          onPendingFilesChanged: (files) =>
              setSheetState(() => draft.pendingFiles = files),
        ),
        const SizedBox(height: 12),
        _buildImagePickerRow(
          imageBase64List: draft.selectedImageBase64List,
          onImagesChanged: (imageBase64List) => setSheetState(
            () => draft.selectedImageBase64List = imageBase64List,
          ),
          isProcessing: draft.isProcessingImage,
          onProcessingChanged: (v) =>
              setSheetState(() => draft.isProcessingImage = v),
        ),
      ],
    );
  }
}
