part of '../../../../main.dart';

extension _TodoHomeEditDialogContent on _TodoHomePageState {
  Widget _buildEditDialogContent({
    required TodoItem item,
    required String tabKey,
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
        // Ctrl/Cmd+V でクリップボードの画像を添付できるようにする
        child: _buildImagePasteShortcut(
          onPasteImage: () => _handlePasteImage(
            imageBase64List: draft.selectedImageBase64List,
            onImagesChanged: (imageBase64List) => setSheetState(
              () => draft.selectedImageBase64List = imageBase64List,
            ),
            isProcessing: draft.isProcessingImage,
            onProcessingChanged: (v) =>
                setSheetState(() => draft.isProcessingImage = v),
          ),
          child: Material(
            color: Colors.transparent,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: maxModalHeight,
                maxWidth: 560,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                decoration: BoxDecoration(
                  color: s.surfaceColor,
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
                        child: _buildEditDialogFields(
                          item: item,
                          tabKey: tabKey,
                          draft: draft,
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
      ),
    );
  }
}
