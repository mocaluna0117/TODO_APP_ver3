// アプリを開いている状態（フォアグラウンド）で受け取ったプッシュを、
// OS/ブラウザの通知として表示するための実装をプラットフォームで切り替える。
// ネイティブは flutter_local_notifications を使うのでスタブ。
export 'push_notification_display_stub.dart'
    if (dart.library.js_interop) 'push_notification_display_web.dart';
