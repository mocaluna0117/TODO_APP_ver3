part of '../../../main.dart';

extension _TodoHomeExport on _TodoHomePageState {
  Future<void> _exportTasks({required bool completedOnly}) async {
    final items = completedOnly
        ? _allItems.where((item) => item.isDone).toList()
        : List<TodoItem>.from(_allItems);
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(completedOnly ? '完了済みタスクがありません' : 'タスクがありません')),
      );
      return;
    }

    final label = completedOnly ? '完了済みタスク' : '全タスク';

    try {
      final exportedAt = DateTime.now();
      final payload = {
        'formatVersion': 1,
        'type': completedOnly ? 'completed_tasks' : 'all_tasks',
        'exportedAt': exportedAt.toIso8601String(),
        'taskCount': items.length,
        'tasks': items.map((item) => item.toJson()).toList(),
      };
      const encoder = JsonEncoder.withIndent('  ');
      final jsonText = encoder.convert(payload);
      final prefix = completedOnly ? 'todo_completed' : 'todo_all';
      final folderName =
          '${prefix}_${DateFormat('yyyyMMdd_HHmmss').format(exportedAt)}';
      final jsonFileName = '$folderName.json';
      final textFileName = 'todo.txt';
      final archive = Archive()
        ..addFile(
          ArchiveFile.string(
            '$folderName/$textFileName',
            _buildTasksText(items, exportedAt, label),
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
          subject: '$labelのバックアップ',
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

  String _buildTasksText(
    List<TodoItem> items,
    DateTime exportedAt,
    String label,
  ) {
    final buffer = StringBuffer()
      ..writeln(label)
      ..writeln('書き出し日時: ${DateFormat('yyyy/MM/dd HH:mm').format(exportedAt)}')
      ..writeln('件数: ${items.length}')
      ..writeln();

    // 未完了はカテゴリ別（やること → やりたいこと → その他）、完了は「完了済み」へ集約
    final pendingItems = items.where((item) => !item.isDone).toList();
    final doneItems = items.where((item) => item.isDone).toList();

    const categoryOrder = ['todo', 'future'];
    final pendingKeys = [
      ...categoryOrder.where(
        (key) => pendingItems.any((item) => item.category == key),
      ),
      ...pendingItems
          .map((item) => item.category)
          .where((key) => !categoryOrder.contains(key))
          .toSet(),
    ];

    for (final key in pendingKeys) {
      _writeTaskGroup(
        buffer,
        _tabName(key),
        pendingItems.where((item) => item.category == key).toList(),
      );
    }
    _writeTaskGroup(buffer, _tabName('done'), doneItems);

    return buffer.toString().trimRight();
  }

  void _writeTaskGroup(StringBuffer buffer, String title, List<TodoItem> items) {
    if (items.isEmpty) return;
    buffer.writeln('【$title】');
    for (final item in items) {
      buffer.writeln('・${item.title}');
      for (final detail in _taskDetailLines(item)) {
        buffer.writeln('   ・$detail');
      }
    }
    buffer.writeln();
  }

  List<String> _taskDetailLines(TodoItem item) {
    return <String>[
      '概要：${(item.description ?? '').trim()}',
      'タグ：${item.taskTag ?? ''}',
      if (item.dueDate != null)
        '期限：${DateFormat('yyyy/MM/dd HH:mm').format(item.dueDate!)}',
      if (item.priority != TaskPriority.none) '優先度：${item.priority.label}',
      if (item.completedAt != null)
        '完了日時：${DateFormat('yyyy/MM/dd HH:mm').format(item.completedAt!)}',
    ];
  }
}
