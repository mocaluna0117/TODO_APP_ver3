import 'package:flutter/material.dart';

enum NotificationTiming {
  none('通知しない'),
  atTime('期限の時間'),
  minutes10('10分前'),
  hour1('1時間前'),
  day1('1日前');

  final String label;
  const NotificationTiming(this.label);
}

enum SortOrder { dueDateAsc, dueDateDesc }

// ─────────────────────────────────────────────
// アプリ設定モデル
// ─────────────────────────────────────────────
class AppSettings {
  // アプリタイトル
  String appTitle;

  // タブ名
  String todoTabName;
  String doneTabName;
  String futureTabName;

  // タブ表示ON/OFF（todoは常にtrue）
  bool showDoneTab;
  bool showFutureTab;

  // 削除確認ダイアログ表示ON/OFF
  bool showDeleteConfirm;

  // 並び順
  SortOrder sortOrder;

  // テーマカラー
  Color primaryColor;
  Color accentColor;

  // 通知タイミング
  NotificationTiming notificationTiming;

  AppSettings({
    this.appTitle = 'TODO',
    this.todoTabName = 'やること',
    this.doneTabName = '完了済み',
    this.futureTabName = '今後やりたいこと',
    this.showDoneTab = true,
    this.showFutureTab = true,
    this.showDeleteConfirm = true,
    this.sortOrder = SortOrder.dueDateAsc,
    this.primaryColor = const Color(0xFF4A55A2),
    this.accentColor = const Color(0xFF7895CB),
    this.notificationTiming = NotificationTiming.hour1,
  });

  // 選択可能なカラーテーマ一覧
  static const List<ColorThemeOption> colorThemes = [
    ColorThemeOption('インディゴ', Color(0xFF4A55A2), Color(0xFF7895CB)),
    ColorThemeOption('ティール', Color(0xFF00796B), Color(0xFF4DB6AC)),
    ColorThemeOption('ローズ', Color(0xFFC62828), Color(0xFFEF5350)),
    ColorThemeOption('パープル', Color(0xFF6A1B9A), Color(0xFFAB47BC)),
    ColorThemeOption('オレンジ', Color(0xFFE65100), Color(0xFFFF8A65)),
    ColorThemeOption('ブルー', Color(0xFF1565C0), Color(0xFF42A5F5)),
    ColorThemeOption('グリーン', Color(0xFF2E7D32), Color(0xFF66BB6A)),
    ColorThemeOption('ピンク', Color(0xFFAD1457), Color(0xFFEC407A)),
    ColorThemeOption('ブラック', Color(0xFF212121), Color(0xFF616161)),
  ];
}

class ColorThemeOption {
  final String name;
  final Color primary;
  final Color accent;
  const ColorThemeOption(this.name, this.primary, this.accent);
}
