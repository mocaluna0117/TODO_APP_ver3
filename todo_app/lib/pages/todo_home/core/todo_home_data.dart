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

  // ログイン中ユーザーの通知予定コレクション（users/{uid}/notifications）。
  // Cloud Functions がここを見て、時刻になった通知を全端末へ送る。
  CollectionReference<Map<String, dynamic>> _notificationsCollection() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications');
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
      // 受信した内容＝Firestore の中身なので、これを基準に差分を判定する
      _syncedTodoJson
        ..clear()
        ..addEntries(
          items.map((item) => MapEntry(item.id.toString(), _encodeTodo(item))),
        );
      _updateState(() {
        _allItems
          ..clear()
          ..addAll(items);
      });
      // 同期で受け取ったタスク（Web等の別端末で作成・編集された分を含む）の
      // 通知をこの端末で予約し直す（Webでは NotificationService 側で無視される）
      NotificationService().rescheduleAll(_allItems, s.notificationTiming);
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

    // base64画像とPDFを Storage にアップロードし URL に置き換える（Firestoreの1MB制限対策）。
    // アップロード中は「アップロード中」表示のためタスクIDを記録する。
    for (final item in _allItems) {
      final hasPendingImage = item.imageBase64List.any(
        (e) => e.isNotEmpty && !_isImageUrl(e),
      );
      final hasPendingFile = item.pendingFiles.isNotEmpty;
      if (!hasPendingImage && !hasPendingFile) continue;
      if (mounted) {
        _updateState(() => _uploadingImageItemIds.add(item.id));
      }
      try {
        if (hasPendingImage) {
          final updated = await _uploadPendingImages(item);
          if (!identical(updated, item.imageBase64List)) {
            item.imageBase64List = updated;
          }
        }
        if (hasPendingFile) {
          // PDF は base64 のまま持たず、ここで Storage へ送って URL に置き換える
          item.attachments = await _uploadPendingFiles(item);
          item.pendingFiles = [];
        }
        // 2ペインで開いたままなら、URLに置き換わった結果をドラフトにも反映する
        _syncOpenDetailDraftAttachments(item);
      } finally {
        if (mounted) {
          _updateState(() => _uploadingImageItemIds.remove(item.id));
        }
      }
    }

    final batch = FirebaseFirestore.instance.batch();
    final currentIds = _allItems.map((e) => e.id.toString()).toSet();
    // 書き込みが成功したあとに反映する差分（途中で失敗したら次回やり直す）
    final written = <String, String>{};
    final removed = <String>[];
    var operations = 0;

    // 中身が変わったタスクだけ書き込む。全件書き直すと、1回の保存で
    // タスク数ぶんの書き込みが発生して無料枠を無駄に消費するため。
    final notificationCol = _notificationsCollection();

    for (final item in _allItems) {
      final id = item.id.toString();
      final encoded = _encodeTodo(item);
      if (_syncedTodoJson[id] == encoded) continue;
      batch.set(col.doc(id), item.toJson());
      // 内容が変わったタスクは、送信予定の通知も作り直す
      _addNotificationOps(batch, notificationCol, item);
      written[id] = encoded;
      operations += 2;
    }
    // _allItems から消えた項目を Firestore からも削除
    for (final knownId in _knownTodoDocIds) {
      if (!currentIds.contains(knownId)) {
        batch.delete(col.doc(knownId));
        batch.delete(notificationCol.doc(knownId));
        removed.add(knownId);
        operations += 2;
      }
    }

    // 変更が無ければ通信しない
    if (operations == 0) return;

    await batch.commit();
    _syncedTodoJson.addAll(written);
    _syncedTodoJson.removeWhere((id, _) => removed.contains(id));
  }

  // 送信予定のプッシュ通知を、タスク1件につき1ドキュメントで持たせる。
  // Cloud Functions は nextSendAt を見て、時刻が来た分を全端末へ送る。
  void _addNotificationOps(
    WriteBatch batch,
    CollectionReference<Map<String, dynamic>> col,
    TodoItem item,
  ) {
    final docRef = col.doc(item.id.toString());
    final entries = _pendingNotificationEntries(item);
    if (entries.isEmpty) {
      batch.delete(docRef);
      return;
    }
    batch.set(docRef, {
      'taskId': item.id,
      'title': '期限が近づいています',
      'entries': entries,
      // 次に送る時刻。関数はこれで対象を絞り込む。
      'nextSendAt': entries.first['sendAt'],
    });
  }

  // 送信時刻の早い順に並べた通知予定（すでに過ぎた分は含めない）
  List<Map<String, dynamic>> _pendingNotificationEntries(TodoItem item) {
    final dueDate = item.dueDate;
    if (item.isDone || dueDate == null) return const [];
    final now = DateTime.now();
    final service = NotificationService();
    final offsets = service.resolveOffsets(item, s.notificationTiming).toList()
      // 期限までの分数が大きいほど早く送ることになる
      ..sort((a, b) => b.compareTo(a));
    final entries = <Map<String, dynamic>>[];
    for (final minutes in offsets) {
      final sendAt = dueDate.subtract(Duration(minutes: minutes));
      if (!sendAt.isAfter(now)) continue;
      entries.add({
        'sendAt': Timestamp.fromDate(sendAt),
        'body': service.notificationBody(item, minutes),
      });
    }
    return entries;
  }

  // 全タスクの通知予定を作り直す（全体の通知タイミング設定を変えたとき用）。
  // タスク自体は変わらないので、通知ドキュメントだけを書き換える。
  Future<void> _resyncAllNotifications() async {
    if (FirebaseAuth.instance.currentUser == null) return;
    final col = _notificationsCollection();
    final batch = FirebaseFirestore.instance.batch();
    for (final item in _allItems) {
      _addNotificationOps(batch, col, item);
    }
    if (_allItems.isEmpty) return;
    try {
      await batch.commit();
    } catch (error) {
      debugPrint('Failed to sync notifications: $error');
    }
  }

  // 差分判定用に、Firestore へ書き込む形へそろえた文字列を作る。
  // toJson のキー順は固定なので、そのまま文字列比較できる。
  String _encodeTodo(TodoItem item) => jsonEncode(item.toJson());
}
