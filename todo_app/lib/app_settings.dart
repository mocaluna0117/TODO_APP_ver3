import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

// 通知プリセットの初期値（期限までの分数）。10分前 / 1時間前 / 1日前。
// 「期限の時間」(0) はピッカーで常に表示するためプリセットには含めない。
const List<int> defaultNotificationPresets = [10, 60, 1440];

// ─────────────────────────────────────────────
// アプリ設定モデル
// ─────────────────────────────────────────────
class AppSettings {
  // アプリタイトル
  String appTitle;

  // タブ名
  String todoTabName;
  String todayTabName;
  String doneTabName;
  String futureTabName;

  // タブ表示ON/OFF（todoは常にtrue）
  bool showTodayTab;
  bool showDoneTab;
  bool showFutureTab;

  // 削除確認ダイアログ表示ON/OFF
  bool showDeleteConfirm;
  bool enableSwipeDelete;

  // 並び順
  SortOrder sortOrder;

  // テーマカラー
  Color primaryColor;
  Color accentColor;

  // 通知タイミング（新規タスクの既定値）
  NotificationTiming notificationTiming;

  // 通知プリセット（期限までの分数）。通知ピッカーの選択肢として表示する。
  List<int> notificationPresets;

  // タグ（main: やること/今日やること用、future: やりたいこと用）
  List<String> taskTags;
  List<String> futureTaskTags;

  AppSettings({
    this.appTitle = 'TODO',
    this.todoTabName = 'やること',
    this.todayTabName = '今日やること',
    this.doneTabName = '完了済み',
    this.futureTabName = 'やりたいこと',
    this.showTodayTab = true,
    this.showDoneTab = true,
    this.showFutureTab = true,
    this.showDeleteConfirm = true,
    this.enableSwipeDelete = false,
    this.sortOrder = SortOrder.dueDateAsc,
    this.primaryColor = const Color(0xFF4A55A2),
    this.accentColor = const Color(0xFF7895CB),
    this.notificationTiming = NotificationTiming.hour1,
    List<int>? notificationPresets,
    List<String>? taskTags,
    List<String>? futureTaskTags,
  }) : notificationPresets = _normalizeNotificationPresets(
         notificationPresets ?? defaultNotificationPresets,
       ),
       taskTags = _normalizeTaskTags(taskTags ?? []),
       futureTaskTags = _normalizeTaskTags(futureTaskTags ?? []);

  // カテゴリに対応するタグリストを返す（future かそれ以外かでグループが分かれる）
  List<String> tagsForCategory(String category) =>
      category == 'future' ? futureTaskTags : taskTags;

  Future<void> saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('appTitle', appTitle);
    await prefs.setString('todoTabName', todoTabName);
    await prefs.setString('todayTabName', todayTabName);
    await prefs.setString('doneTabName', doneTabName);
    await prefs.setString('futureTabName', futureTabName);
    await prefs.setBool('showTodayTab', showTodayTab);
    await prefs.setBool('showDoneTab', showDoneTab);
    await prefs.setBool('showFutureTab', showFutureTab);
    await prefs.setBool('showDeleteConfirm', showDeleteConfirm);
    await prefs.setBool('enableSwipeDelete', enableSwipeDelete);
    await prefs.setInt('sortOrder', sortOrder.index);
    await prefs.setInt('primaryColor', primaryColor.toARGB32());
    await prefs.setInt('accentColor', accentColor.toARGB32());
    await prefs.setInt('notificationTiming', notificationTiming.index);
    await prefs.setStringList(
      'notificationPresets',
      notificationPresets.map((e) => e.toString()).toList(),
    );
    await prefs.setStringList('taskTags', taskTags);
    await prefs.setStringList('futureTaskTags', futureTaskTags);
  }

  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    appTitle = prefs.getString('appTitle') ?? appTitle;
    todoTabName = prefs.getString('todoTabName') ?? todoTabName;
    todayTabName = prefs.getString('todayTabName') ?? todayTabName;
    doneTabName = prefs.getString('doneTabName') ?? doneTabName;
    futureTabName = prefs.getString('futureTabName') ?? futureTabName;
    showTodayTab = prefs.getBool('showTodayTab') ?? showTodayTab;
    showDoneTab = prefs.getBool('showDoneTab') ?? showDoneTab;
    showFutureTab = prefs.getBool('showFutureTab') ?? showFutureTab;
    showDeleteConfirm = prefs.getBool('showDeleteConfirm') ?? showDeleteConfirm;
    enableSwipeDelete = prefs.getBool('enableSwipeDelete') ?? enableSwipeDelete;

    if (prefs.containsKey('sortOrder')) {
      sortOrder = SortOrder.values[prefs.getInt('sortOrder')!];
    }
    if (prefs.containsKey('primaryColor')) {
      primaryColor = Color(prefs.getInt('primaryColor')!);
    }
    if (prefs.containsKey('accentColor')) {
      accentColor = Color(prefs.getInt('accentColor')!);
    }
    if (prefs.containsKey('notificationTiming')) {
      notificationTiming =
          NotificationTiming.values[prefs.getInt('notificationTiming')!];
    }
    final presetStrings = prefs.getStringList('notificationPresets');
    if (presetStrings != null) {
      notificationPresets = _normalizeNotificationPresets(
        presetStrings.map((e) => int.tryParse(e) ?? -1).toList(),
      );
    }
    taskTags = _normalizeTaskTags(prefs.getStringList('taskTags') ?? taskTags);
    futureTaskTags = _normalizeTaskTags(
      prefs.getStringList('futureTaskTags') ?? futureTaskTags,
    );
  }

  // 通知プリセットを正規化する（1分以上・重複なし・昇順）。
  // 0（期限の時間）はピッカーで常に表示するためプリセットには含めない。
  static List<int> _normalizeNotificationPresets(List<int> presets) {
    final normalized = <int>[];
    for (final p in presets) {
      if (p >= 1 && !normalized.contains(p)) normalized.add(p);
    }
    normalized.sort();
    return normalized;
  }

  static List<String> _normalizeTaskTags(List<String> tags) {
    final normalized = <String>[];
    for (final tag in tags) {
      final trimmed = tag.trim();
      if (trimmed.isNotEmpty && !normalized.contains(trimmed)) {
        normalized.add(trimmed);
      }
    }
    return normalized;
  }

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
