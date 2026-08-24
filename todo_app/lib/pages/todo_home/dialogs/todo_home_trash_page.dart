part of '../../../main.dart';

extension _TodoHomeTrashPage on _TodoHomePageState {
  // ゴミ箱を開く。
  // 画面内で復元・削除ができるよう、この画面だけの再描画を持たせる。
  Future<void> _openTrash() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StatefulBuilder(
          builder: (context, refresh) => _buildTrashPage(refresh),
        ),
      ),
    );
    _updateState(() {});
  }

  Widget _buildTrashPage(StateSetter refresh) {
    final items = _trashedItems;
    final retentionDays = kTrashRetention.inDays;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ゴミ箱', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: s.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_forever),
              tooltip: 'ゴミ箱を空にする',
              onPressed: () => _confirmEmptyTrash(refresh),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: items.isEmpty
                ? _buildEmptyTrashMessage()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: items.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            '削除から$retentionDays日を過ぎたタスクは自動で完全に削除されます。',
                            style: TextStyle(
                              fontSize: 12,
                              color: s.secondaryTextColor,
                            ),
                          ),
                        );
                      }
                      return _buildTrashCard(items[index - 1], refresh);
                    },
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyTrashMessage() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.delete_outline, size: 64, color: s.outlineColor),
          const SizedBox(height: 12),
          Text(
            'ゴミ箱は空です',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildTrashCard(TodoItem item, StateSetter refresh) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: s.surfaceColor,
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
        title: Text(
          item.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: s.primaryTextColor,
          ),
        ),
        subtitle: Text(
          _trashItemSubtitle(item),
          style: TextStyle(fontSize: 12, color: s.secondaryTextColor),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 34, height: 34),
              padding: EdgeInsets.zero,
              icon: Icon(Icons.restore, color: s.accentColor),
              tooltip: '元に戻す',
              onPressed: () {
                _restoreFromTrash(item);
                refresh(() {});
              },
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 34, height: 34),
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.delete_forever,
                color: Colors.red.shade300,
                size: 20,
              ),
              tooltip: '完全に削除',
              onPressed: () => _confirmDeletePermanently(item, refresh),
            ),
          ],
        ),
      ),
    );
  }

  // 「3日前に削除・あと4日で自動削除」のような補足
  String _trashItemSubtitle(TodoItem item) {
    final deletedAt = item.deletedAt;
    if (deletedAt == null) return '';
    final deleted = DateFormat('M/d(E) HH:mm', 'ja').format(deletedAt);
    final remaining = kTrashRetention.inDays -
        DateTime.now().difference(deletedAt).inDays;
    if (remaining <= 0) return '$deleted に削除・まもなく自動削除されます';
    return '$deleted に削除・あと$remaining日で自動削除';
  }

  Future<void> _confirmDeletePermanently(
    TodoItem item,
    StateSetter refresh,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '完全に削除',
          style: TextStyle(fontWeight: FontWeight.bold, color: s.accentOnSurface),
        ),
        content: Text(
          '「${item.title}」を完全に削除しますか？\n添付した画像・PDFも削除され、元に戻せません。',
          style: const TextStyle(fontSize: 15, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text(
              '削除',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    _deleteItemPermanently(item);
    refresh(() {});
  }

  Future<void> _confirmEmptyTrash(StateSetter refresh) async {
    final count = _trashedItems.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'ゴミ箱を空にする',
          style: TextStyle(fontWeight: FontWeight.bold, color: s.accentOnSurface),
        ),
        content: Text(
          '$count件のタスクを完全に削除しますか？\n添付した画像・PDFも削除され、元に戻せません。',
          style: const TextStyle(fontSize: 15, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text(
              '空にする',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    _emptyTrash();
    refresh(() {});
  }
}
