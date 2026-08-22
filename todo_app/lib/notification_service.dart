import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'app_settings.dart';
import 'main.dart'; // TodoItemを使うため
import 'notification_offset.dart'; // notificationOffsetLabel を使うため
import 'push_notification_display.dart'; // Webのフォアグラウンド表示

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  Future<void>? _initFuture;

  // Web用のプッシュ鍵（Firebaseコンソール → Cloud Messaging → ウェブプッシュ証明書）。
  // これはブラウザへ配られる公開鍵なので、リポジトリに置いても問題ない。
  // 鍵を差し替えたいときは --dart-define=FCM_VAPID_KEY=... で上書きできる。
  static const String _webVapidKey = String.fromEnvironment(
    'FCM_VAPID_KEY',
    defaultValue:
        'BCsvlVCLLDpwbsSatacXD14YXBYSBSRClI1x79-OCDyPtSuJAfClL4zQdDHHlGD-FSYYcsTB97ObZSzXnH57WoY',
  );

  // プッシュ（FCM）が使えている端末かどうか。
  // 使えている端末では端末内スケジュールを行わず、二重に鳴らないようにする。
  bool get usesPush => _pushToken != null;
  String? _pushToken;

  Future<void> init() => _initFuture ??= _init();

  Future<void> _init() async {
    await _initPush();
    if (kIsWeb) return;

    // タイムゾーンの初期化
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));

    // Android用の初期化設定（アプリアイコンを指定）
    const AndroidInitializationSettings initSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS用の初期化設定（権限の要求を含む）
    const DarwinInitializationSettings initSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initSettings = InitializationSettings(
      android: initSettingsAndroid,
      iOS: initSettingsIOS,
    );

    await _notificationsPlugin.initialize(settings: initSettings);

    // Android用のパーミッション要求 (Android 13+の通知権限とAndroid 12+のアラーム権限)
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
      await androidPlugin.requestExactAlarmsPermission();
    }
  }

  // タスクの通知をスケジュールする（タスクごとに複数件設定可能）。
  // [defaultTiming] はタスク固有の設定が無い場合に使う全体のデフォルト。
  Future<void> scheduleNotification(
    TodoItem item,
    NotificationTiming defaultTiming,
  ) async {
    if (kIsWeb) return;

    await init();
    // プッシュが使える端末では、サーバーから送られる分だけを鳴らす
    if (usesPush) return;

    // 一旦このタスクの既存通知をすべてキャンセル
    await cancelNotification(item.id);

    if (item.dueDate == null || item.isDone) {
      return;
    }

    final uniqueOffsets = resolveOffsets(item, defaultTiming);
    if (uniqueOffsets.isEmpty) {
      return;
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'todo_app_channel',
          'Todo Notifications',
          importance: Importance.max,
          priority: Priority.high,
        );
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final now = DateTime.now();
    for (final minutes in uniqueOffsets) {
      final scheduledTime = item.dueDate!.subtract(Duration(minutes: minutes));
      // スケジュール時刻が過去の場合は通知しない
      if (scheduledTime.isBefore(now)) {
        continue;
      }

      await _notificationsPlugin.zonedSchedule(
        id: _notificationId(item.id, minutes),
        title: '期限が近づいています',
        body: _notificationBody(item, minutes),
        scheduledDate: tz.TZDateTime.from(scheduledTime, tz.local),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        // どのタスクの通知かを判別するためアイテムIDを payload に持たせる
        payload: item.id.toString(),
      );
    }
  }

  // タスクに適用される通知タイミング（期限までの分数）を返す。
  // タスク固有の設定があればそれを、無ければ全体のデフォルトを使う。
  Set<int> resolveOffsets(TodoItem item, NotificationTiming defaultTiming) {
    final List<int> offsets;
    if (item.notificationOffsets != null) {
      offsets = item.notificationOffsets!;
    } else if (defaultTiming == NotificationTiming.none) {
      offsets = const [];
    } else {
      offsets = [notificationTimingToMinutes(defaultTiming)];
    }
    return offsets.where((m) => m >= 0).toSet();
  }

  String notificationBody(TodoItem item, int minutes) =>
      _notificationBody(item, minutes);

  String _notificationBody(TodoItem item, int minutes) {
    if (minutes <= 0) {
      return '「${item.title}」が期限の時間です！';
    }
    return '「${item.title}」の期限が近づいています（${notificationOffsetLabel(minutes)}）';
  }

  // タスクIDと通知タイミングから一意の通知IDを導出する。
  // 1タスクに複数件の通知をスケジュールしても衝突しないようにする。
  int _notificationId(int itemId, int minutes) {
    return Object.hash(itemId, minutes) & 0x7FFFFFFF;
  }

  // 指定タスクの通知をすべてキャンセル
  Future<void> cancelNotification(int id) async {
    if (kIsWeb) return;
    await init();
    // 旧バージョンでアイテムID直指定だった通知も念のためキャンセル
    await _notificationsPlugin.cancel(id: id);
    // payload にこのアイテムIDを持つ通知（複数件）をまとめてキャンセル
    final pending = await _notificationsPlugin.pendingNotificationRequests();
    final payload = id.toString();
    for (final request in pending) {
      if (request.payload == payload) {
        await _notificationsPlugin.cancel(id: request.id);
      }
    }
  }

  // ─── プッシュ通知（FCM） ───
  //
  // 端末のトークンを Firestore に登録しておき、サーバー側（Cloud Functions）が
  // 時刻になったら同じアカウントの全端末へ送る。これで、ある端末で設定した
  // 通知が別の端末でも鳴る。
  // APNs 未設定の iOS など、プッシュを使えない端末では例外を握りつぶして
  // 端末内スケジュール（ローカル通知）にフォールバックする。
  Future<void> _initPush() async {
    // ブラウザは「利用者の操作」からでないと通知の許可を求められない。
    // 特に iOS のホーム画面アプリでは、起動時に自動で求めると拒否扱いになり、
    // 二度と許可ダイアログを出せなくなる。そのため Web では、すでに許可済みの
    // ときだけ設定を進め、未許可なら設定画面のボタンから求める。
    if (kIsWeb && !isBrowserNotificationGranted()) return;
    await _setupPush(requestPermission: !kIsWeb);
  }

  // 設定画面のボタン（利用者の操作）から通知を有効にする。
  // 有効にできたら true。
  Future<bool> enablePushFromUserAction() async {
    if (kIsWeb) {
      final granted = await requestBrowserNotificationPermission();
      if (!granted) return false;
    }
    await init();
    await _setupPush(requestPermission: !kIsWeb);
    return usesPush;
  }

  Future<void> _setupPush({required bool requestPermission}) async {
    if (_pushToken != null) return; // すでに設定済み
    try {
      final messaging = FirebaseMessaging.instance;
      if (requestPermission) {
        final settings = await messaging.requestPermission();
        if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      }
      if (kIsWeb && _webVapidKey.isEmpty) return; // 鍵が無ければ使わない

      final token = kIsWeb
          ? await messaging.getToken(vapidKey: _webVapidKey)
          : await messaging.getToken();
      if (token == null || token.isEmpty) return;

      _pushToken = token;
      await _saveDeviceToken(token);
      messaging.onTokenRefresh.listen((refreshed) {
        _pushToken = refreshed;
        _saveDeviceToken(refreshed);
      });

      // アプリを開いている間に届いた分は自分で表示する
      // （この状態ではOS/ブラウザが自動表示しないため）
      FirebaseMessaging.onMessage.listen(_showForegroundMessage);
    } catch (error, stackTrace) {
      debugPrint('Push notifications unavailable: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  // ログイン中のユーザーへ、この端末のトークンを登録し直す。
  // アカウントを切り替えたときに新しいユーザー側へ登録するため、
  // ログイン後の画面から毎回呼ぶ。
  Future<void> registerCurrentDevice() async {
    final token = _pushToken;
    if (token == null) return;
    await _saveDeviceToken(token);
  }

  // ログアウト時に、この端末のトークンを今のユーザーから外す。
  // 残したままだと、別のアカウントで使っても前のユーザー宛の通知が届いてしまう。
  Future<void> unregisterDevice() async {
    final token = _pushToken;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (token == null || uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('devices')
          .doc(token)
          .delete();
    } catch (error) {
      debugPrint('Failed to unregister device token: $error');
    }
  }

  // この端末（インストール）を表す固定ID。
  // トークンは再登録などで変わるため、同じ端末だと分かる目印を別に持たせ、
  // 古い登録が残って同じ端末に通知が二重に届くのを防ぐ。
  Future<String> _installationId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('installationId');
    if (id != null && id.isNotEmpty) return id;
    id =
        '${DateTime.now().microsecondsSinceEpoch}'
        '-${DateTime.now().hashCode.toUnsigned(16)}';
    await prefs.setString('installationId', id);
    return id;
  }

  // 端末のトークンを users/{uid}/devices/{token} に登録する
  Future<void> _saveDeviceToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final installationId = await _installationId();
      final devices = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('devices');
      await devices.doc(token).set({
        'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
        'installationId': installationId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      // 同じ端末の古い登録は消す（通知が重複して届かないようにする）
      final sameDevice = await devices
          .where('installationId', isEqualTo: installationId)
          .get();
      for (final doc in sameDevice.docs) {
        if (doc.id != token) await doc.reference.delete();
      }
    } catch (error) {
      debugPrint('Failed to register device token: $error');
    }
  }

  void _showForegroundMessage(RemoteMessage message) {
    // Web は data だけで届く（表示を Service Worker と二重にしないため）ので、
    // notification が無い場合は data から組み立てる。
    final notification = message.notification;
    final title = notification?.title ?? message.data['title']?.toString();
    final body = notification?.body ?? message.data['body']?.toString() ?? '';
    if (title == null || title.isEmpty) return;

    if (kIsWeb) {
      showBrowserNotification(title, body);
      return;
    }
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'todo_app_channel',
        'Todo Notifications',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
    _notificationsPlugin.show(
      id: message.hashCode & 0x7FFFFFFF,
      title: title,
      body: body,
      notificationDetails: details,
      payload: message.data['taskId']?.toString(),
    );
  }

  // 全ての通知を再スケジュール（設定画面でタイミングが変更された時に使用）
  Future<void> rescheduleAll(
    List<TodoItem> items,
    NotificationTiming defaultTiming,
  ) async {
    if (kIsWeb) return;
    await init();
    await _notificationsPlugin.cancelAll();
    // プッシュが使える端末では端末内スケジュールは持たない
    if (usesPush) return;
    for (var item in items) {
      if (!item.isDone && item.dueDate != null) {
        await scheduleNotification(item, defaultTiming);
      }
    }
  }
}
