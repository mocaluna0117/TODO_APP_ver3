import 'dart:js_interop';

import 'package:web/web.dart' as web;

// ブラウザの通知が「許可済み」かどうか。
// 通知に対応していない場合（iOSのSafariタブなど）も false になる。
bool isBrowserNotificationGranted() {
  try {
    return web.Notification.permission == 'granted';
  } catch (_) {
    return false;
  }
}

// ブラウザの通知許可を求める。許可されたら true。
// ブラウザは「利用者の操作（タップ・クリック）」からでないと許可を求められない
// ため、この関数は設定画面のボタンなどから呼ぶ必要がある。
Future<bool> requestBrowserNotificationPermission() async {
  try {
    final permission = await web.Notification.requestPermission().toDart;
    return permission.toDart == 'granted';
  } catch (_) {
    // 通知に対応していないブラウザ（ホーム画面に追加していないiOSなど）
    return false;
  }
}

// タブを開いている間に受け取った通知を、ブラウザの通知として表示する。
// バックグラウンド（タブが非表示・閉じている）分は Service Worker が表示する。
void showBrowserNotification(String title, String body) {
  try {
    if (!isBrowserNotificationGranted()) return;
    web.Notification(title, web.NotificationOptions(body: body));
  } catch (_) {
    // 表示できない環境では黙って諦める
  }
}
