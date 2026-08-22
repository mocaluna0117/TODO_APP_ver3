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

  // 現在のタブで選択中のタスク。
  // 左の一覧（タブ＋タグ絞り込み後）に居ないタスクは詳細も出さない。
  // 削除・完了・タグ絞り込み・カテゴリ移動で一覧から消えたときに、
  // 右だけ古いタスクを表示し続けるのを防ぐ。
  TodoItem? get _selectedDetailItem {
    final id = _selectedDetailItemIds[_currentTabKey];
    if (id == null) return null;
    for (final item in _itemsByCategory(_currentTabKey)) {
      if (item.id == id) return item;
    }
    return null;
  }

  // 選択中のカードが左ペインで見えるようにスクロールする。
  // タブを戻したときに、右の詳細と左で見えているものを一致させるため。
  void _scrollToSelectedCardAfterBuild() {
    if (!_isWideLayout) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // まだ組み立てられていない（画面外の遠く）場合は何もしない。
      // その場合もリストの位置自体は PageStorage で復元されている。
      final id = _selectedDetailItemIds[_currentTabKey];
      final cardContext = id == null
          ? null
          : _cardKeys[_currentTabKey]?[id]?.currentContext;
      if (cardContext == null) return;
      Scrollable.ensureVisible(
        cardContext,
        // スクロール追従の基準（リスト上端）と揃えておく
        alignment: 0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  // 「今見ているカード」とみなす基準線を、リスト上端からどれだけ下に置くか。
  // 上端ぎりぎりに残っているだけのカードを選ばないための余白。
  static const double _visibleCardThreshold = 24;

  // スクロールが止まったとき、左で見えているタスクに右の詳細を合わせる。
  void _syncDetailToVisibleCard(
    String category,
    ScrollEndNotification notification,
  ) {
    if (!_isWideLayout || category != _currentTabKey) return;
    // まだ何も選んでいないときは、スクロールだけで詳細を開かない
    final selectedId = _selectedDetailItemIds[category];
    if (selectedId == null) return;
    // 未保存の入力があるときは切り替えない（入力を捨てないため）
    if (_hasUnsavedDetailChanges()) return;

    final viewport = notification.context?.findRenderObject();
    if (viewport is! RenderBox || !viewport.attached) return;
    final referenceY =
        viewport.localToGlobal(Offset.zero).dy + _visibleCardThreshold;

    final keys = _cardKeys[category];
    if (keys == null) return;
    for (final item in _itemsByCategory(category)) {
      final cardContext = keys[item.id]?.currentContext;
      // 画面外でまだ組み立てられていないカードは飛ばす
      if (cardContext == null) continue;
      final box = cardContext.findRenderObject();
      if (box is! RenderBox || !box.attached) continue;
      // 基準線より上に流れ切ったカードは対象外
      if (box.localToGlobal(Offset.zero).dy + box.size.height <= referenceY) {
        continue;
      }
      if (item.id == selectedId) return; // すでに一致している
      // スクロール処理中の setState を避けてフレーム後に反映する
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _updateState(() {
          _selectedDetailItemIds[category] = item.id;
          _detailDraft = null; // 別タスクなのでドラフトを作り直す
        });
      });
      return;
    }
  }

  // 右ペインに未保存の変更があるか
  bool _hasUnsavedDetailChanges() {
    final draft = _detailDraft;
    final item = _selectedDetailItem;
    if (draft == null || item == null || _detailDraftItemId != item.id) {
      return false;
    }
    if (draft.textController.text != item.title) return true;
    if (_normalizeOptionalText(draft.descriptionController.text) !=
        item.description) {
      return true;
    }
    if (!_sameDetailList(
      normalizeLinkList(draft.linkControllers.map((c) => c.text)),
      item.links,
    )) {
      return true;
    }
    if (draft.selectedDate != item.dueDate) return true;
    if (draft.selectedTaskTag != item.taskTag) return true;
    if (draft.selectedTaskPriority != item.priority) return true;
    if (!_sameDetailRecurrence(draft.selectedRecurrence, item.recurrence)) {
      return true;
    }
    if (!_sameDetailList(
      draft.selectedImageBase64List,
      item.imageBase64List,
    )) {
      return true;
    }
    return !_sameDetailList(
      draft.selectedNotificationOffsets,
      item.notificationOffsets ?? _defaultNotificationOffsets(),
    );
  }

  bool _sameDetailList<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool _sameDetailRecurrence(Recurrence? a, Recurrence? b) {
    if (a == null || b == null) return a == null && b == null;
    return a.hasSameConfig(b) && a.doneCount == b.doneCount;
  }

  Widget _buildDetailPane() {
    final item = _selectedDetailItem;
    if (item == null) {
      // 未選択（または選択中のタスクが削除された）
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.checklist_rounded,
              size: 56,
              color: Colors.grey.shade300,
            ),
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
        recurrence: draft.selectedRecurrence,
        imageBase64List: draft.selectedImageBase64List,
        priority: draft.selectedTaskPriority,
        notificationOffsets: draft.selectedNotificationOffsets,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存しました'), duration: Duration(seconds: 2)),
      );
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        // ペイン内にフォーカスがあるとき、Ctrl/Cmd+V でクリップボードの画像を添付できる
        child: _buildImagePasteShortcut(
          onPasteImage: () => _handlePasteImage(
            imageBase64List: draft.selectedImageBase64List,
            onImagesChanged: (imageBase64List) => _updateState(
              () => draft.selectedImageBase64List = imageBase64List,
            ),
            isProcessing: draft.isProcessingImage,
            onProcessingChanged: (v) =>
                _updateState(() => draft.isProcessingImage = v),
          ),
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
                          isFromTodayTab: _currentTabKey == 'today',
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
                      _selectedDetailItemIds.remove(_currentTabKey);
                      _detailDraft = null;
                      _detailDraftItemId = null;
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
