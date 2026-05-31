part of '../main.dart';

extension _TodoHomeEditDialogContent on _TodoHomePageState {
  Widget _buildEditDialogContent({
    required TodoItem item,
    required bool isFromTodayTab,
    required _EditTodoDraft draft,
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
                      child: _buildEditDialogFields(
                        item: item,
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
                    child: const Text('保存', style: TextStyle(fontSize: 16)),
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
