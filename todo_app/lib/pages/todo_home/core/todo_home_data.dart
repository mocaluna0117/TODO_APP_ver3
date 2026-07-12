part of '../../../main.dart';

extension _TodoHomeData on _TodoHomePageState {
  // ログイン中ユーザーの todos コレクション（users/{uid}/todos）
  CollectionReference<Map<String, dynamic>> _todosCollection() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('todos');
  }

  Future<void> _loadData() async {
    final col = _todosCollection();

    // 初回のみ、ローカル(SharedPreferences)のデータを Firestore へ移行
    await _migrateLocalDataIfNeeded(col);

    // リアルタイム同期リスナー。別端末の変更もここで反映される。
    _todosSub = col.snapshots().listen((snapshot) {
      if (!mounted) return;
      final items = snapshot.docs
          .map((doc) => TodoItem.fromJson(doc.data()))
          .toList();
      _knownTodoDocIds = snapshot.docs.map((d) => d.id).toSet();
      _updateState(() {
        _allItems
          ..clear()
          ..addAll(items);
      });
    });
  }

  // 端末間でデータを同期しつつ、既存のローカルデータを一度だけクラウドへ移す。
  Future<void> _migrateLocalDataIfNeeded(
    CollectionReference<Map<String, dynamic>> col,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    // 移行済みなら何もしない（削除後の再インポートを防ぐため必ずフラグで判定）
    if (prefs.getBool('firestore_migrated') ?? false) return;

    final itemsJson = prefs.getString('todo_items');
    if (itemsJson != null) {
      final List<dynamic> decoded = jsonDecode(itemsJson);
      final localItems = decoded.map((e) => TodoItem.fromJson(e)).toList();
      // 既にクラウドにデータがある場合（別端末で作成済み等）は上書きしない
      if (localItems.isNotEmpty) {
        final existing = await col.limit(1).get();
        if (existing.docs.isEmpty) {
          final batch = FirebaseFirestore.instance.batch();
          for (final item in localItems) {
            batch.set(col.doc(item.id.toString()), item.toJson());
          }
          await batch.commit();
        }
      }
    }

    await prefs.setBool('firestore_migrated', true);
  }

  // 現在の _allItems を Firestore に反映する（追加/更新 + 削除された分を消す）。
  Future<void> _saveData() async {
    final col = _todosCollection();
    final batch = FirebaseFirestore.instance.batch();
    final currentIds = _allItems.map((e) => e.id.toString()).toSet();

    for (final item in _allItems) {
      batch.set(col.doc(item.id.toString()), item.toJson());
    }
    // _allItems から消えた項目を Firestore からも削除
    for (final knownId in _knownTodoDocIds) {
      if (!currentIds.contains(knownId)) {
        batch.delete(col.doc(knownId));
      }
    }

    await batch.commit();
  }
}
