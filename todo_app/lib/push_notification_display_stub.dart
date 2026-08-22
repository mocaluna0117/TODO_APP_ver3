// ネイティブ用スタブ。ネイティブのフォアグラウンド表示は
// flutter_local_notifications 側で行うため、ここでは何もしない。
bool isBrowserNotificationGranted() => true;

Future<bool> requestBrowserNotificationPermission() async => false;

void showBrowserNotification(String title, String body) {}
