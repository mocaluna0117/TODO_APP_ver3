part of '../main.dart';

class _AddTodoDraft {
  _AddTodoDraft({required bool isFromTodayTab})
    : selectedDate = isFromTodayTab ? _endOfToday() : null;

  final textController = TextEditingController();
  final descriptionController = TextEditingController();
  DateTime? selectedDate;
  List<String> selectedImageBase64List = <String>[];
  String? selectedTaskTag;
  RecurrenceRule selectedRecurrenceRule = RecurrenceRule.none;
  TaskPriority selectedTaskPriority = TaskPriority.none;

  static DateTime _endOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 23, 59);
  }
}

extension _TodoHomeAddDialogContent on _TodoHomePageState {
  Widget _buildAddDialogContent({
    required String category,
    required bool isFromTodayTab,
    required _AddTodoDraft draft,
    required double maxModalHeight,
    required EdgeInsets padding,
    required VoidCallback submit,
    required StateSetter setSheetState,
  }) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: padding,
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
                      child: _buildAddDialogFields(
                        category: category,
                        isFromTodayTab: isFromTodayTab,
                        draft: draft,
                        submit: submit,
                        setSheetState: setSheetState,
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
                    child: const Text('追加', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddDialogFields({
    required String category,
    required bool isFromTodayTab,
    required _AddTodoDraft draft,
    required VoidCallback submit,
    required StateSetter setSheetState,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${_tabName(category)}を追加',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: s.primaryColor,
          ),
        ),
        const SizedBox(height: 16),
        _buildAddDialogTitleField(draft),
        const SizedBox(height: 12),
        _buildAddDialogDescriptionField(draft, submit),
        const SizedBox(height: 12),
        _buildTaskTagPicker(
          selectedTaskTag: draft.selectedTaskTag,
          onChanged: (tag) => setSheetState(() => draft.selectedTaskTag = tag),
        ),
        if (category == 'future') ...[
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
        if (!isFromTodayTab) ...[
          const SizedBox(height: 12),
          _buildRecurrencePicker(
            selectedRecurrenceRule: draft.selectedRecurrenceRule,
            onChanged: (rule) =>
                setSheetState(() => draft.selectedRecurrenceRule = rule),
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

  Widget _buildAddDialogTitleField(_AddTodoDraft draft) {
    return TextField(
      controller: draft.textController,
      autofocus: true,
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.next,
      hintLocales: const [Locale('ja', 'JP')],
      decoration: _addDialogTextFieldDecoration('タスクを入力...'),
    );
  }

  Widget _buildAddDialogDescriptionField(
    _AddTodoDraft draft,
    VoidCallback submit,
  ) {
    return TextField(
      controller: draft.descriptionController,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.done,
      hintLocales: const [Locale('ja', 'JP')],
      minLines: 1,
      maxLines: 4,
      onSubmitted: (_) => submit(),
      decoration: _addDialogTextFieldDecoration(
        '概要を入力（任意）',
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }

  InputDecoration _addDialogTextFieldDecoration(
    String hintText, {
    EdgeInsetsGeometry contentPadding = const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 14,
    ),
  }) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: const Color(0xFFF5F5FA),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: contentPadding,
    );
  }
}
