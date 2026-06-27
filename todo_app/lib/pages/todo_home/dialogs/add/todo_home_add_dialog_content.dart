part of '../../../../main.dart';

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
                      // スクロール（ドラッグ）でキーボードを閉じる
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: _buildAddDialogFields(
                        category: category,
                        isFromTodayTab: isFromTodayTab,
                        draft: draft,
                        setSheetState: setSheetState,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // タスク名が空の間は追加ボタンを押せないようにする
                  ListenableBuilder(
                    listenable: draft.textController,
                    builder: (context, _) {
                      final canSubmit =
                          draft.textController.text.trim().isNotEmpty;
                      return ElevatedButton(
                        onPressed: canSubmit ? submit : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: s.primaryColor,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade300,
                          disabledForegroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('追加', style: TextStyle(fontSize: 16)),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
