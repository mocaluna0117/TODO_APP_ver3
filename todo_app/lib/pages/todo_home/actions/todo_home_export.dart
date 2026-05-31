part of '../../../main.dart';

extension _TodoHomeExport on _TodoHomePageState {
  Future<void> _exportCompletedTasks() async {
    final completedItems = _allItems.where((item) => item.isDone).toList();
    if (completedItems.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('完了済みタスクがありません')));
      return;
    }

    try {
      final exportedAt = DateTime.now();
      final payload = {
        'formatVersion': 1,
        'type': 'completed_tasks',
        'exportedAt': exportedAt.toIso8601String(),
        'taskCount': completedItems.length,
        'tasks': completedItems.map((item) => item.toJson()).toList(),
      };
      const encoder = JsonEncoder.withIndent('  ');
      final jsonText = encoder.convert(payload);
      final jsonBytes = Uint8List.fromList(utf8.encode(jsonText));
      final fileName =
          'todo_completed_${DateFormat('yyyyMMdd_HHmmss').format(exportedAt)}.json';
      final renderBox = context.findRenderObject() as RenderBox?;
      final shareOrigin = renderBox == null
          ? null
          : renderBox.localToGlobal(Offset.zero) & renderBox.size;

      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              jsonBytes,
              mimeType: 'application/json',
              name: fileName,
            ),
          ],
          fileNameOverrides: [fileName],
          subject: '完了済みタスクのバックアップ',
          text: '完了済みタスク ${completedItems.length}件のバックアップです。',
          sharePositionOrigin: shareOrigin,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to export completed tasks: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('エクスポートできませんでした')));
    }
  }
}
