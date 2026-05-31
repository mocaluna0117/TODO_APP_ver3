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
      final folderName =
          'todo_completed_${DateFormat('yyyyMMdd_HHmmss').format(exportedAt)}';
      final jsonFileName = '$folderName.json';
      final textFileName = 'todo.txt';
      final archive = Archive()
        ..addFile(
          ArchiveFile.string(
            '$folderName/$textFileName',
            _buildCompletedTasksText(completedItems, exportedAt),
          ),
        )
        ..addFile(ArchiveFile.string('$folderName/$jsonFileName', jsonText));
      final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive));
      final zipFileName = '$folderName.zip';
      final renderBox = context.findRenderObject() as RenderBox?;
      final shareOrigin = renderBox == null
          ? null
          : renderBox.localToGlobal(Offset.zero) & renderBox.size;

      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              zipBytes,
              mimeType: 'application/zip',
              name: zipFileName,
            ),
          ],
          fileNameOverrides: [zipFileName],
          subject: '完了済みタスクのバックアップ',
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

  String _buildCompletedTasksText(
    List<TodoItem> completedItems,
    DateTime exportedAt,
  ) {
    final buffer = StringBuffer()
      ..writeln('完了済みタスク')
      ..writeln('書き出し日時: ${DateFormat('yyyy/MM/dd HH:mm').format(exportedAt)}')
      ..writeln('件数: ${completedItems.length}')
      ..writeln();

    for (final item in completedItems) {
      buffer.writeln(_completedTaskBullet(item));
    }
    return buffer.toString();
  }

  String _completedTaskBullet(TodoItem item) {
    final details = <String>[
      if (item.description != null && item.description!.trim().isNotEmpty)
        '概要: ${item.description}',
      if (item.taskTag != null) 'タグ: ${item.taskTag}',
      if (item.dueDate != null)
        '期限: ${DateFormat('yyyy/MM/dd HH:mm').format(item.dueDate!)}',
      if (item.priority != TaskPriority.none) '優先度: ${item.priority.label}',
      if (item.completedAt != null)
        '完了日時: ${DateFormat('yyyy/MM/dd HH:mm').format(item.completedAt!)}',
    ];
    if (details.isEmpty) return '・${item.title}';
    return '・${item.title}（${details.join(' / ')}）';
  }
}
