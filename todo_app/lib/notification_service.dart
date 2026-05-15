import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'app_settings.dart';
import 'main.dart'; // TodoItemを使うため

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // タイムゾーンの初期化
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));

    // Android用の初期化設定（アプリアイコンを指定）
    const AndroidInitializationSettings initSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS用の初期化設定（権限の要求を含む）
    const DarwinInitializationSettings initSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: initSettingsAndroid,
      iOS: initSettingsIOS,
    );

    await _notificationsPlugin.initialize(initSettings);

    // Android用のパーミッション要求 (Android 13+の通知権限とAndroid 12+のアラーム権限)
    final androidPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
      await androidPlugin.requestExactAlarmsPermission();
    }
  }

  // 通知をスケジュールする
  Future<void> scheduleNotification(TodoItem item, NotificationTiming timing) async {
    // 一旦既存の通知をキャンセル
    await cancelNotification(item.id);

    if (item.isDone || item.dueDate == null || timing == NotificationTiming.none) {
      return;
    }

    // 設定された期限の時間をそのまま使用する
    DateTime scheduledTime = item.dueDate!;

    switch (timing) {
      case NotificationTiming.atTime:
        // 朝9:00のまま
        break;
      case NotificationTiming.minutes10:
        scheduledTime = scheduledTime.subtract(const Duration(minutes: 10));
        break;
      case NotificationTiming.hour1:
        scheduledTime = scheduledTime.subtract(const Duration(hours: 1));
        break;
      case NotificationTiming.day1:
        scheduledTime = scheduledTime.subtract(const Duration(days: 1));
        break;
      case NotificationTiming.none:
        return;
    }

    // スケジュール時刻が過去の場合は通知しない
    if (scheduledTime.isBefore(DateTime.now())) {
      return;
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
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

    await _notificationsPlugin.zonedSchedule(
      item.id,
      '期限が近づいています',
      '「${item.title}」の期限が迫っています！',
      tz.TZDateTime.from(scheduledTime, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // 通知をキャンセル
  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  // 全ての通知を再スケジュール（設定画面でタイミングが変更された時に使用）
  Future<void> rescheduleAll(List<TodoItem> items, NotificationTiming timing) async {
    await _notificationsPlugin.cancelAll();
    for (var item in items) {
      if (!item.isDone && item.dueDate != null) {
        await scheduleNotification(item, timing);
      }
    }
  }
}
