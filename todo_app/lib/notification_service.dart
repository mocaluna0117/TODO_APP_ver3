import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'app_settings.dart';
import 'main.dart'; // TodoItemを使うため

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  Future<void>? _initFuture;

  Future<void> init() => _initFuture ??= _init();

  Future<void> _init() async {
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

    // 一旦このタスクの既存通知をすべてキャンセル
    await cancelNotification(item.id);

    if (item.dueDate == null || item.isDone) {
      return;
    }

    // タスク固有の設定があればそれを、無ければ全体のデフォルトを使用する。
    // 値は「期限までの分数」。
    final List<int> offsets;
    if (item.notificationOffsets != null) {
      offsets = item.notificationOffsets!;
    } else if (defaultTiming == NotificationTiming.none) {
      offsets = const [];
    } else {
      offsets = [notificationTimingToMinutes(defaultTiming)];
    }
    final uniqueOffsets = offsets.where((m) => m >= 0).toSet();
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

  // 全ての通知を再スケジュール（設定画面でタイミングが変更された時に使用）
  Future<void> rescheduleAll(
    List<TodoItem> items,
    NotificationTiming defaultTiming,
  ) async {
    if (kIsWeb) return;
    await init();
    await _notificationsPlugin.cancelAll();
    for (var item in items) {
      if (!item.isDone && item.dueDate != null) {
        await scheduleNotification(item, defaultTiming);
      }
    }
  }
}
