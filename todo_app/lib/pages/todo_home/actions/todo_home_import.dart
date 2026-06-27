part of '../../../main.dart';

extension _TodoHomeImport on _TodoHomePageState {
  Future<void> _importTasks() async {
    // すでにファイル選択中なら無視（多重呼び出しで前の選択がキャンセルされるのを防ぐ）
    if (_isPickingBackup) return;
    _isPickingBackup = true;
    final FilePickerResult? picked;
    try {
      // 端末標準のファイル選択画面を開き、JSONファイルのみ選べるようにする
      picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to pick backup file: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ファイルを選択できませんでした')));
      return;
    } finally {
      _isPickingBackup = false;
    }
    if (picked == null || picked.files.isEmpty) return;

    final file = picked.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ファイルを読み込めませんでした')));
      return;
    }

    final List<TodoItem> importedItems;
    try {
      importedItems = _parseBackupBytes(bytes, file.name);
    } catch (error, stackTrace) {
      debugPrint('Failed to parse backup file: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('バックアップファイルの形式が正しくありません')));
      return;
    }

    if (importedItems.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('取り込めるタスクがありませんでした')));
      return;
    }

    // 既存のIDと重複しないものだけ復元する（既にあるタスクは上書きしない）
    final existingIds = _allItems.map((item) => item.id).toSet();
    final newItems = importedItems
        .where((item) => !existingIds.contains(item.id))
        .toList();
    final skipped = importedItems.length - newItems.length;

    if (newItems.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${importedItems.length}件はすべて既に存在しています')),
      );
      return;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'タスクを復元',
          style: TextStyle(fontWeight: FontWeight.bold, color: s.primaryColor),
        ),
        content: Text(
          '${newItems.length}件のタスクを復元します。'
          '${skipped > 0 ? '\n（$skipped件は既に存在するためスキップ）' : ''}',
          style: const TextStyle(fontSize: 15, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'キャンセル',
              style: TextStyle(color: Colors.grey, fontSize: 15),
            ),
          ),
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: s.primaryColor),
            child: const Text(
              '復元',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // 復元タスクが持つ未登録タグを、カテゴリ別のグループに取り込んで消えないようにする
    final newMainTags = newItems
        .where((item) => item.category != 'future' && item.taskTag != null)
        .map((item) => item.taskTag!)
        .where((tag) => !s.taskTags.contains(tag))
        .toSet();
    final newFutureTags = newItems
        .where((item) => item.category == 'future' && item.taskTag != null)
        .map((item) => item.taskTag!)
        .where((tag) => !s.futureTaskTags.contains(tag))
        .toSet();
    if (newMainTags.isNotEmpty || newFutureTags.isNotEmpty) {
      s.taskTags.addAll(newMainTags);
      s.futureTaskTags.addAll(newFutureTags);
      await s.saveToPrefs();
      widget.onSettingsChanged();
    }

    _updateState(() {
      _allItems.addAll(newItems);
    });
    await _saveData();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${newItems.length}件のタスクを復元しました'
          '${skipped > 0 ? '（$skipped件はスキップ）' : ''}',
        ),
      ),
    );
  }

  List<TodoItem> _parseBackupBytes(Uint8List bytes, String fileName) {
    final isZip =
        fileName.toLowerCase().endsWith('.zip') ||
        (bytes.length >= 2 && bytes[0] == 0x50 && bytes[1] == 0x4B);

    final String jsonText;
    if (isZip) {
      final archive = ZipDecoder().decodeBytes(bytes);
      final jsonFile = archive.files.firstWhere(
        (f) => f.isFile && f.name.toLowerCase().endsWith('.json'),
        orElse: () => throw const FormatException('JSONが含まれていません'),
      );
      jsonText = utf8.decode(jsonFile.content as List<int>);
    } else {
      jsonText = utf8.decode(bytes);
    }

    final decoded = jsonDecode(jsonText);
    final List<dynamic> rawTasks;
    if (decoded is Map<String, dynamic> && decoded['tasks'] is List) {
      rawTasks = decoded['tasks'] as List<dynamic>;
    } else if (decoded is List) {
      rawTasks = decoded;
    } else {
      throw const FormatException('タスク情報が見つかりません');
    }

    return rawTasks
        .whereType<Map<String, dynamic>>()
        .map((e) => TodoItem.fromJson(e))
        .toList();
  }
}
