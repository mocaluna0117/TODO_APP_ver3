part of '../main.dart';

extension _TodoHomeEditDialog on _TodoHomePageState {
  void _showEditDialog(TodoItem item, {String tabKey = ''}) {
    final isFromTodayTab = tabKey == 'today';
    final draft = _EditTodoDraft(item);

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
              _editItem(
                item,
                draft.textController.text,
                description: draft.descriptionController.text,
                taskTag: draft.selectedTaskTag,
                dueDate: draft.selectedDate,
                recurrenceRule: draft.selectedRecurrenceRule,
                imageBase64List: draft.selectedImageBase64List,
                priority: draft.selectedTaskPriority,
              );
              Navigator.pop(context);
            }

            return _buildEditDialogContent(
              item: item,
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
