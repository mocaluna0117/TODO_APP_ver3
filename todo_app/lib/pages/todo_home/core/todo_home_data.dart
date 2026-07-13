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

  // ログイン中ユーザーの設定ドキュメント（users/{uid}/meta/settings）
  DocumentReference<Map<String, dynamic>> _settingsDoc() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('meta')
        .doc('settings');
  }

  // 設定（タグ等）の端末間同期を開始する。
  Future<void> _startSettingsSync() async {
    // 設定を保存するたび Firestore にも書き込むフックを設定
    s.onCloudSave = (settings) async {
      if (FirebaseAuth.instance.currentUser == null) return;
      try {
        await _settingsDoc().set(settings.toMap());
      } catch (_) {
        // ネットワーク等で失敗しても保存自体は続行（オフラインは後で同期）
      }
    };

    // 既存のローカル設定を一度だけクラウドへ移行（タグは失わないよう和集合）
    await _migrateSettingsIfNeeded();

    // リアルタイム同期リスナー。別端末の設定変更を反映する。
    _settingsSub = _settingsDoc().snapshots().listen((snap) {
      if (!mounted || !snap.exists) return;
      final data = snap.data();
      if (data == null) return;
      _updateState(() => s.applyMap(data));
      widget.onSettingsChanged();
    });
  }

  Future<void> _migrateSettingsIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('settings_migrated') ?? false) return;

    final doc = _settingsDoc();
    final snap = await doc.get();
    if (!snap.exists) {
      // クラウドに設定がなければローカル設定をアップロード
      await doc.set(s.toMap());
    } else {
      // クラウドにある場合は、この端末のタグを失わないよう和集合にして書き戻す
      final data = snap.data() ?? {};
      final cloudTaskTags = (data['taskTags'] as List? ?? const [])
          .map((e) => e.toString())
          .toList();
      final cloudFutureTags = (data['futureTaskTags'] as List? ?? const [])
          .map((e) => e.toString())
          .toList();
      await doc.set({
        ...data,
        'taskTags': {...cloudTaskTags, ...s.taskTags}.toList(),
        'futureTaskTags': {...cloudFutureTags, ...s.futureTaskTags}.toList(),
      });
    }

    await prefs.setBool('settings_migrated', true);
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

    // base64画像を Storage にアップロードし URL に置き換える（Firestoreの1MB制限対策）。
    // アップロード中は「アップロード中」表示のためタスクIDを記録する。
    for (final item in _allItems) {
      final hasPending = item.imageBase64List.any(
        (e) => e.isNotEmpty && !_isImageUrl(e),
      );
      if (!hasPending) continue;
      if (mounted) {
        _updateState(() => _uploadingImageItemIds.add(item.id));
      }
      try {
        final updated = await _uploadPendingImages(item);
        if (!identical(updated, item.imageBase64List)) {
          item.imageBase64List = updated;
        }
      } finally {
        if (mounted) {
          _updateState(() => _uploadingImageItemIds.remove(item.id));
        }
      }
    }

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
