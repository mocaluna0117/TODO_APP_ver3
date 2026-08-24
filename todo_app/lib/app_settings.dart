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

  // 削除確認ダイアログ表示ON/OFF
  bool showDeleteConfirm;
  bool enableSwipeDelete;

  // 並び順
  SortOrder sortOrder;

  // 画面の明暗（system は端末の設定に従う）
  ThemeMode themeMode;

  // いま暗い配色で描画しているか。MyApp が毎回のビルドで設定する。
  // themeMode が system のときは端末の設定で決まるため、この値は保存しない。
  bool isDarkMode = false;

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

  // クラウド同期用フック。設定保存時に Firestore へも書き込む（アプリ層で設定）。
  Future<void> Function(AppSettings settings)? onCloudSave;

  AppSettings({
    this.appTitle = 'TODO',
    this.showDeleteConfirm = true,
    this.enableSwipeDelete = false,
    this.sortOrder = SortOrder.dueDateAsc,
    this.themeMode = ThemeMode.system,
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

  // ─── 配色 ───
  // 画面の明暗で変わる色はここにまとめ、各画面はこれを参照する。
  // 面（カード・シート）と下地（入力欄）で明度を分け、暗い配色でも段差が
  // 分かるようにしている。
  static const Color lightBackground = Color(0xFFF5F5FA);
  static const Color darkBackground = Color(0xFF121217);
  static const Color darkSurface = Color(0xFF1E1E26);
  static const Color darkField = Color(0xFF2A2A34);

  // 画面全体の背景
  Color get backgroundColor => isDarkMode ? darkBackground : lightBackground;
  // カード・シート・ダイアログの面
  Color get surfaceColor => isDarkMode ? darkSurface : Colors.white;
  // 入力欄やボタンの下地
  Color get fieldColor => isDarkMode ? darkField : lightBackground;
  // 本文の文字
  Color get primaryTextColor =>
      isDarkMode ? const Color(0xFFECECF1) : Colors.black87;
  // 補助的な文字
  Color get secondaryTextColor =>
      isDarkMode ? const Color(0xFFA8A8B4) : Colors.black54;
  // 未入力・無効を表す文字
  Color get hintTextColor =>
      isDarkMode ? const Color(0xFF80808C) : Colors.grey;
  // 区切り線
  Color get dividerColor =>
      isDarkMode ? const Color(0xFF32323C) : Colors.grey.shade200;
  // 枠線や、内容が無いことを示す大きなアイコン
  Color get outlineColor =>
      isDarkMode ? const Color(0xFF3D3D49) : Colors.grey.shade300;

  // カテゴリに対応するタグリストを返す（future かそれ以外かでグループが分かれる）
  List<String> tagsForCategory(String category) =>
      category == 'future' ? futureTaskTags : taskTags;

  Future<void> saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('appTitle', appTitle);
    await prefs.setBool('showDeleteConfirm', showDeleteConfirm);
    await prefs.setBool('enableSwipeDelete', enableSwipeDelete);
    await prefs.setInt('sortOrder', sortOrder.index);
    await prefs.setInt('themeMode', themeMode.index);
    await prefs.setInt('primaryColor', primaryColor.toARGB32());
    await prefs.setInt('accentColor', accentColor.toARGB32());
    await prefs.setInt('notificationTiming', notificationTiming.index);
    await prefs.setStringList(
      'notificationPresets',
      notificationPresets.map((e) => e.toString()).toList(),
    );
    await prefs.setStringList('taskTags', taskTags);
    await prefs.setStringList('futureTaskTags', futureTaskTags);
    // クラウド（Firestore）へも同期する
    if (onCloudSave != null) {
      await onCloudSave!(this);
    }
  }

  // Firestore 保存用のマップに変換する。
  Map<String, dynamic> toMap() => {
    'appTitle': appTitle,
    'showDeleteConfirm': showDeleteConfirm,
    'enableSwipeDelete': enableSwipeDelete,
    'sortOrder': sortOrder.index,
    'themeMode': themeMode.index,
    'primaryColor': primaryColor.toARGB32(),
    'accentColor': accentColor.toARGB32(),
    'notificationTiming': notificationTiming.index,
    'notificationPresets': notificationPresets,
    'taskTags': taskTags,
    'futureTaskTags': futureTaskTags,
  };

  // Firestore から取得したマップを反映する（クラウド優先で上書き）。
  void applyMap(Map<String, dynamic> data) {
    appTitle = data['appTitle'] as String? ?? appTitle;
    showDeleteConfirm = data['showDeleteConfirm'] as bool? ?? showDeleteConfirm;
    enableSwipeDelete = data['enableSwipeDelete'] as bool? ?? enableSwipeDelete;

    final sortIndex = data['sortOrder'];
    if (sortIndex is int && sortIndex >= 0 && sortIndex < SortOrder.values.length) {
      sortOrder = SortOrder.values[sortIndex];
    }
    final themeIndex = data['themeMode'];
    if (themeIndex is int &&
        themeIndex >= 0 &&
        themeIndex < ThemeMode.values.length) {
      themeMode = ThemeMode.values[themeIndex];
    }
    if (data['primaryColor'] is int) {
      primaryColor = Color(data['primaryColor'] as int);
    }
    if (data['accentColor'] is int) {
      accentColor = Color(data['accentColor'] as int);
    }
    final timingIndex = data['notificationTiming'];
    if (timingIndex is int &&
        timingIndex >= 0 &&
        timingIndex < NotificationTiming.values.length) {
      notificationTiming = NotificationTiming.values[timingIndex];
    }
    if (data['notificationPresets'] is List) {
      notificationPresets = _normalizeNotificationPresets(
        (data['notificationPresets'] as List)
            .map((e) => (e as num).toInt())
            .toList(),
      );
    }
    if (data['taskTags'] is List) {
      taskTags = _normalizeTaskTags(
        (data['taskTags'] as List).map((e) => e.toString()).toList(),
      );
    }
    if (data['futureTaskTags'] is List) {
      futureTaskTags = _normalizeTaskTags(
        (data['futureTaskTags'] as List).map((e) => e.toString()).toList(),
      );
    }
  }

  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    appTitle = prefs.getString('appTitle') ?? appTitle;
    showDeleteConfirm = prefs.getBool('showDeleteConfirm') ?? showDeleteConfirm;
    enableSwipeDelete = prefs.getBool('enableSwipeDelete') ?? enableSwipeDelete;

    if (prefs.containsKey('sortOrder')) {
      sortOrder = SortOrder.values[prefs.getInt('sortOrder')!];
    }
    final savedThemeMode = prefs.getInt('themeMode');
    if (savedThemeMode != null &&
        savedThemeMode >= 0 &&
        savedThemeMode < ThemeMode.values.length) {
      themeMode = ThemeMode.values[savedThemeMode];
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
