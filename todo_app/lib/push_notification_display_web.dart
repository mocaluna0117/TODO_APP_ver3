import 'dart:js_interop';

import 'package:web/web.dart' as web;

// ブラウザの通知許可を求める。許可されたら true。
Future<bool> requestBrowserNotificationPermission() async {
  try {
    final permission = await web.Notification.requestPermission().toDart;
    return permission.toDart == 'granted';
  } catch (_) {
    // 通知に対応していないブラウザ（古い Safari など）
    return false;
  }
}

// タブを開いている間に受け取った通知を、ブラウザの通知として表示する。
// バックグラウンド（タブが非表示・閉じている）分は Service Worker が表示する。
void showBrowserNotification(String title, String body) {
  try {
    if (web.Notification.permission != 'granted') return;
    web.Notification(title, web.NotificationOptions(body: body));
  } catch (_) {
    // 表示できない環境では黙って諦める
  }
}
