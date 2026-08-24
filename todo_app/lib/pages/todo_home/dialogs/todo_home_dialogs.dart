part of '../../../main.dart';

extension _TodoHomeDialogs on _TodoHomePageState {
  void _showAddDialog() {
    final tabKey = _currentTabKey;
    final fixedDay = _fixedDayForTab(tabKey);
    // 「今日やること」「明日やること」「完了済み」は期限や状態で自動的に集まる
    // 表示用のタブなので、保存先のカテゴリは「やること」にする
    final category = (tabKey == 'done' || fixedDay != null) ? 'todo' : tabKey;
    final draft = _AddTodoDraft(
      fixedDay: fixedDay,
      defaultNotificationOffsets: _defaultNotificationOffsets(),
    );

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
                links: draft.linkControllers.map((c) => c.text).toList(),
                taskTag: draft.selectedTaskTag,
                dueDate: draft.selectedDate,
                recurrence: draft.selectedRecurrence,
                imageBase64List: draft.selectedImageBase64List,
                attachments: draft.selectedFiles,
                pendingFiles: draft.pendingFiles,
                priority: draft.selectedTaskPriority,
                notificationOffsets: draft.selectedNotificationOffsets,
              );
              Navigator.pop(context);
            }

            return _buildAddDialogContent(
              category: category,
              tabKey: tabKey,
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
