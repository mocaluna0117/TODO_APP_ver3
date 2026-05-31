part of '../main.dart';

extension _TodoHomeDialogs on _TodoHomePageState {
  void _showAddDialog() {
    final isFromTodayTab = _currentTabKey == 'today';
    final category = _currentTabKey == 'done' || isFromTodayTab
        ? 'todo'
        : _currentTabKey;
    final draft = _AddTodoDraft(isFromTodayTab: isFromTodayTab);

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final mediaQuery = MediaQuery.of(context);
            final keyboardInset = mediaQuery.viewInsets.bottom;
            final topOffset = mediaQuery.padding.top + 4;
            final bottomGap = keyboardInset > 0 ? 20.0 : 16.0;
            final maxModalHeight =
                (mediaQuery.size.height - topOffset - keyboardInset - bottomGap)
                    .clamp(240.0, mediaQuery.size.height * 0.8);

            void submit() {
              _addItem(
                draft.textController.text,
                category,
                description: draft.descriptionController.text,
                taskTag: draft.selectedTaskTag,
                dueDate: draft.selectedDate,
                recurrenceRule: draft.selectedRecurrenceRule,
                imageBase64List: draft.selectedImageBase64List,
                priority: draft.selectedTaskPriority,
              );
              Navigator.pop(context);
            }

            return _buildAddDialogContent(
              category: category,
              isFromTodayTab: isFromTodayTab,
              draft: draft,
              maxModalHeight: maxModalHeight,
              padding: EdgeInsets.only(
                top: topOffset,
                left: 16,
                right: 16,
                bottom: keyboardInset + bottomGap,
              ),
              submit: submit,
              setSheetState: setSheetState,
            );
          },
        );
      },
    );
  }
}
