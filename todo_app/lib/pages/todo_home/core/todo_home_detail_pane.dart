part of '../../../main.dart';

// 広い画面（PC等）用の右側詳細ペイン。
// 選択したタスクの編集フォームをモーダルではなく常設で表示する。
extension _TodoHomeDetailPane on _TodoHomePageState {
  // 現在の画面幅が2ペインレイアウトの対象かどうか
  bool get _isWideLayout =>
      MediaQuery.sizeOf(context).width >= kTwoPaneBreakpoint;

  // 左ペインの実効幅。既定は画面幅の半分（1:1）で、
  // 右ペインの最低幅を確保できる範囲で自由に調整できる。
  double get _effectiveListPaneWidth {
    final screenWidth = MediaQuery.sizeOf(context).width;
    var maxWidth = screenWidth - kDetailPaneMinWidth;
    if (maxWidth < kListPaneMinWidth) maxWidth = kListPaneMinWidth;
    final width = _listPaneWidth ?? screenWidth / 2;
    return width.clamp(kListPaneMinWidth, maxWidth);
  }

  Future<void> _loadListPaneWidth() async {
    final prefs = await SharedPreferences.getInstance();
    final width = prefs.getDouble('listPaneWidth');
    if (width != null && mounted) {
      _updateState(() => _listPaneWidth = width);
    }
  }

  Future<void> _saveListPaneWidth() async {
    final prefs = await SharedPreferences.getInstance();
    final width = _listPaneWidth;
    if (width == null) {
      // 既定（画面幅の半分）に戻した場合は保存値を消し、画面サイズに追従させる
      await prefs.remove('listPaneWidth');
    } else {
      await prefs.setDouble('listPaneWidth', width);
    }
  }

  // ペインの境目に置くドラッグハンドル。左右ドラッグで左ペインの幅を調整する。
  Widget _buildPaneResizer() {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (details) {
          _updateState(() {
            _listPaneWidth = _effectiveListPaneWidth + details.delta.dx;
          });
        },
        onHorizontalDragEnd: (_) => _saveListPaneWidth(),
        // ダブルタップで既定幅（画面幅の半分＝1:1）に戻す
        onDoubleTap: () {
          _updateState(() => _listPaneWidth = null);
          _saveListPaneWidth();
        },
        child: SizedBox(
          width: 9,
          child: Center(
            child: Container(width: 1, color: Colors.grey.shade300),
          ),
        ),
      ),
    );
  }

  // 選択中のタスク（削除や同期で消えた場合は null）
  TodoItem? get _selectedDetailItem {
    final id = _selectedDetailItemId;
    if (id == null) return null;
    for (final item in _allItems) {
      if (item.id == id) return item;
    }
    return null;
  }

  Widget _buildDetailPane() {
    final item = _selectedDetailItem;
    if (item == null) {
      // 未選択（または選択中のタスクが削除された）
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.checklist_rounded, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'タスクを選択して詳細を表示',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
          ],
        ),
      );
    }

    // 選択が変わったらドラフトを作り直す
    if (_detailDraft == null || _detailDraftItemId != item.id) {
      _detailDraft = _EditTodoDraft(
        item,
        defaultNotificationOffsets: _defaultNotificationOffsets(),
      );
      _detailDraftItemId = item.id;
    }
    final draft = _detailDraft!;

    void submit() {
      _editItem(
        item,
        draft.textController.text,
        description: draft.descriptionController.text,
        links: draft.linkControllers.map((c) => c.text).toList(),
        taskTag: draft.selectedTaskTag,
        dueDate: draft.selectedDate,
        recurrenceRule: draft.selectedRecurrenceRule,
        imageBase64List: draft.selectedImageBase64List,
        priority: draft.selectedTaskPriority,
        notificationOffsets: draft.selectedNotificationOffsets,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('保存しました'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 12),
                      // スクロール（ドラッグ）でキーボードを閉じる
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: _buildEditDialogFields(
                        item: item,
                        isFromTodayTab: _selectedDetailTabKey == 'today',
                        draft: draft,
                        setSheetState: _updateState,
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
              // 選択を解除して詳細を閉じる
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  icon: Icon(Icons.close, color: Colors.grey.shade500),
                  tooltip: '閉じる',
                  onPressed: () => _updateState(() {
                    _selectedDetailItemId = null;
                    _detailDraft = null;
                    _detailDraftItemId = null;
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
