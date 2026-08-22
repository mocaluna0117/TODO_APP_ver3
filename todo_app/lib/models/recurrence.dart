part of '../main.dart';

// ─────────────────────────────────────────────
// 繰り返し設定
//
// 「2週ごとの月・水」「毎月第2火曜日」「毎月15日」「毎年」のように、
// 間隔・曜日・月内の位置・終了条件をユーザーが自由に組み合わせられるようにする。
//
// 曜日や日を指定しなかった項目（null / 空）は期限の日付から補う。こうすると
// プリセット（「毎週○曜日」など）は期限を変えるとそれに追従し、カスタム設定で
// 明示的に選んだ値はそのまま保持される。
// ─────────────────────────────────────────────

// 繰り返しの単位
enum RecurrenceFreq {
  daily('日'),
  weekly('週'),
  monthly('か月'),
  yearly('年');

  // 「2週ごと」の「週」に当たる部分
  final String unitLabel;
  const RecurrenceFreq(this.unitLabel);
}

// 月単位の繰り返しを「日付で」か「曜日で」のどちらで決めるか
enum MonthlyMode { dayOfMonth, nthWeekday }

// 繰り返しの終わり方
enum RecurrenceEnd { never, until, count }

// weekOrdinal に入れると「最終○曜日」を表す値
const int lastWeekdayOrdinal = -1;

// DateTime.weekday は月曜=1、日曜=7
const List<String> weekdayNames = ['月', '火', '水', '木', '金', '土', '日'];

// 期限がその月の「第何週目の同曜日」かを返す（1〜5）
int recurrenceWeekdayOrdinal(DateTime date) => (date.day - 1) ~/ 7 + 1;

class Recurrence {
  const Recurrence({
    required this.freq,
    this.interval = 1,
    this.weekdays = const {},
    this.monthlyMode = MonthlyMode.dayOfMonth,
    this.monthDay,
    this.weekOrdinal,
    this.monthWeekday,
    this.end = RecurrenceEnd.never,
    this.until,
    this.count,
    this.doneCount = 0,
  });

  final RecurrenceFreq freq;
  // 「n日ごと」「n週ごと」の n（1以上）
  final int interval;
  // 週単位のとき繰り返す曜日（1〜7）。空なら期限の曜日を使う。
  final Set<int> weekdays;
  final MonthlyMode monthlyMode;
  // 月単位・日付指定のときの日（1〜31）。null なら期限の日を使う。
  final int? monthDay;
  // 月単位・曜日指定のときの第n週（1〜5、lastWeekdayOrdinal は最終）。
  // null なら期限の日付から判定する。
  final int? weekOrdinal;
  // 月単位・曜日指定のときの曜日（1〜7）。null なら期限の曜日を使う。
  final int? monthWeekday;
  final RecurrenceEnd end;
  // end == until のときの終了日。この日を過ぎる回は繰り返さない。
  final DateTime? until;
  // end == count のときの繰り返し回数（今の期限を1回目として数える）
  final int? count;
  // これまでに繰り返した回数。設定ではなく進捗で、count の判定に使う。
  final int doneCount;

  Recurrence copyWith({
    RecurrenceFreq? freq,
    int? interval,
    Set<int>? weekdays,
    MonthlyMode? monthlyMode,
    int? monthDay,
    int? weekOrdinal,
    int? monthWeekday,
    RecurrenceEnd? end,
    DateTime? until,
    int? count,
    int? doneCount,
  }) {
    return Recurrence(
      freq: freq ?? this.freq,
      interval: interval ?? this.interval,
      weekdays: weekdays ?? this.weekdays,
      monthlyMode: monthlyMode ?? this.monthlyMode,
      monthDay: monthDay ?? this.monthDay,
      weekOrdinal: weekOrdinal ?? this.weekOrdinal,
      monthWeekday: monthWeekday ?? this.monthWeekday,
      end: end ?? this.end,
      until: until ?? this.until,
      count: count ?? this.count,
      doneCount: doneCount ?? this.doneCount,
    );
  }

  // 曜日・日を省略している項目を [dueDate] の値で確定させた設定を返す。
  // 完了のたびに「その時点の期限」から導出すると、月末や第5週で丸めが起きた
  // 月以降ずっと日付がずれてしまうため、繰り返す前に基準を固定する。
  Recurrence resolvedFor(DateTime dueDate) {
    final isWeekly = freq == RecurrenceFreq.weekly;
    final isMonthly = freq == RecurrenceFreq.monthly;
    final byWeekday = isMonthly && monthlyMode == MonthlyMode.nthWeekday;
    return Recurrence(
      freq: freq,
      interval: interval,
      weekdays: isWeekly && weekdays.isEmpty
          ? <int>{dueDate.weekday}
          : weekdays,
      monthlyMode: monthlyMode,
      monthDay: isMonthly && !byWeekday ? (monthDay ?? dueDate.day) : monthDay,
      weekOrdinal: byWeekday
          ? (weekOrdinal ?? recurrenceWeekdayOrdinal(dueDate))
          : weekOrdinal,
      monthWeekday: byWeekday ? (monthWeekday ?? dueDate.weekday) : monthWeekday,
      end: end,
      until: until,
      count: count,
      doneCount: doneCount,
    );
  }

  // 進捗（doneCount）を除いた「設定」が同じかどうか。
  // プリセットと現在の設定を突き合わせるのに使う。
  bool hasSameConfig(Recurrence other) {
    return freq == other.freq &&
        interval == other.interval &&
        _sameWeekdaySet(weekdays, other.weekdays) &&
        monthlyMode == other.monthlyMode &&
        monthDay == other.monthDay &&
        weekOrdinal == other.weekOrdinal &&
        monthWeekday == other.monthWeekday &&
        end == other.end &&
        until == other.until &&
        count == other.count;
  }

  Map<String, dynamic> toJson() => {
    'freq': freq.name,
    'interval': interval,
    if (weekdays.isNotEmpty) 'weekdays': (weekdays.toList()..sort()),
    'monthlyMode': monthlyMode.name,
    if (monthDay != null) 'monthDay': monthDay,
    if (weekOrdinal != null) 'weekOrdinal': weekOrdinal,
    if (monthWeekday != null) 'monthWeekday': monthWeekday,
    'end': end.name,
    if (until != null) 'until': until!.toIso8601String(),
    if (count != null) 'count': count,
    if (doneCount != 0) 'doneCount': doneCount,
  };

  // 壊れた値が入っていても落ちないよう、範囲外は丸めるか無視する。
  static Recurrence? fromJson(Object? value) {
    if (value is! Map) return null;
    final freq = _recurrenceEnumByName(RecurrenceFreq.values, value['freq']);
    if (freq == null) return null;

    final weekdays = <int>{};
    final rawWeekdays = value['weekdays'];
    if (rawWeekdays is List) {
      for (final raw in rawWeekdays) {
        final weekday = _recurrenceInt(raw);
        if (weekday != null && weekday >= 1 && weekday <= 7) {
          weekdays.add(weekday);
        }
      }
    }

    final monthDay = _recurrenceInt(value['monthDay']);
    final weekOrdinal = _recurrenceInt(value['weekOrdinal']);
    final monthWeekday = _recurrenceInt(value['monthWeekday']);
    final count = _recurrenceInt(value['count']);
    final rawUntil = value['until']?.toString();

    return Recurrence(
      freq: freq,
      interval: (_recurrenceInt(value['interval']) ?? 1).clamp(1, 999).toInt(),
      weekdays: weekdays,
      monthlyMode:
          _recurrenceEnumByName(MonthlyMode.values, value['monthlyMode']) ??
          MonthlyMode.dayOfMonth,
      monthDay: (monthDay != null && monthDay >= 1 && monthDay <= 31)
          ? monthDay
          : null,
      weekOrdinal:
          (weekOrdinal == lastWeekdayOrdinal ||
              (weekOrdinal != null && weekOrdinal >= 1 && weekOrdinal <= 5))
          ? weekOrdinal
          : null,
      monthWeekday: (monthWeekday != null &&
              monthWeekday >= 1 &&
              monthWeekday <= 7)
          ? monthWeekday
          : null,
      end:
          _recurrenceEnumByName(RecurrenceEnd.values, value['end']) ??
          RecurrenceEnd.never,
      until: rawUntil != null ? DateTime.tryParse(rawUntil) : null,
      count: (count != null && count >= 1) ? count : null,
      doneCount: _recurrenceInt(value['doneCount']) ?? 0,
    );
  }
}

// 曜日の集合が同じかどうか（setEquals は material 経由では見えないため自前で持つ）
bool _sameWeekdaySet(Set<int> a, Set<int> b) =>
    a.length == b.length && a.every(b.contains);

T? _recurrenceEnumByName<T extends Enum>(List<T> values, Object? raw) {
  final name = raw?.toString();
  if (name == null || name.isEmpty) return null;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}

int? _recurrenceInt(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  final text = raw?.toString();
  return text == null ? null : int.tryParse(text);
}

// 旧形式（recurrenceRule の enum 名 or index）を新形式へ変換する。
// 曜日・日は指定せず期限から補う形にして、以前と同じ挙動を保つ。
Recurrence? recurrenceFromLegacyRule(Object? value) {
  final raw = value?.toString();
  if (raw == null || raw.isEmpty) return null;
  switch (raw) {
    case 'daily':
    case '1':
      return const Recurrence(freq: RecurrenceFreq.daily);
    case 'weekly':
    case '2':
      return const Recurrence(freq: RecurrenceFreq.weekly);
    case 'monthly':
    case '3':
      return const Recurrence(freq: RecurrenceFreq.monthly);
    case 'biweekly':
    case '4':
      return const Recurrence(freq: RecurrenceFreq.weekly, interval: 2);
    case 'every3Weeks':
    case '5':
      return const Recurrence(freq: RecurrenceFreq.weekly, interval: 3);
    case 'every4Weeks':
    case '6':
      return const Recurrence(freq: RecurrenceFreq.weekly, interval: 4);
    case 'monthlyNthWeekday':
    case '7':
      return const Recurrence(
        freq: RecurrenceFreq.monthly,
        monthlyMode: MonthlyMode.nthWeekday,
      );
    case 'monthlyLastWeekday':
    case '8':
      return const Recurrence(
        freq: RecurrenceFreq.monthly,
        monthlyMode: MonthlyMode.nthWeekday,
        weekOrdinal: lastWeekdayOrdinal,
      );
    // 'none' / '0' / 未知の値は繰り返しなし
    default:
      return null;
  }
}

// ─────────────────────────────────────────────
// 次回の期限の算出
// ─────────────────────────────────────────────

// 期限 [dueDate] を基準に、[after] より後の最初の繰り返し日時を返す。
// 終了日を過ぎている場合や算出できなかった場合は null（繰り返し終了）。
DateTime? nextRecurrenceDate(
  Recurrence recurrence,
  DateTime dueDate,
  DateTime after,
) {
  final next = _rawNextRecurrenceDate(recurrence, dueDate, after);
  if (next == null) return null;
  final until = recurrence.until;
  if (recurrence.end == RecurrenceEnd.until &&
      until != null &&
      next.isAfter(until)) {
    return null;
  }
  return next;
}

// 探索の上限。期限が数年前でも到達できるだけの余裕を取り、
// 万一条件を満たす日が見つからない場合は無限ループさせず打ち切る。
const int _recurrenceSearchLimit = 600;

DateTime? _rawNextRecurrenceDate(
  Recurrence recurrence,
  DateTime dueDate,
  DateTime after,
) {
  final interval = recurrence.interval < 1 ? 1 : recurrence.interval;
  switch (recurrence.freq) {
    case RecurrenceFreq.daily:
      // 期限が何年も前のこともあるので、必要な回数をまとめて足す
      var next = dueDate.add(Duration(days: interval));
      if (!next.isAfter(after)) {
        final elapsedDays = after.difference(next).inDays;
        next = next.add(
          Duration(days: (elapsedDays ~/ interval + 1) * interval),
        );
      }
      while (!next.isAfter(after)) {
        next = next.add(Duration(days: interval));
      }
      return next;

    case RecurrenceFreq.weekly:
      final weekdays =
          (recurrence.weekdays.isEmpty
                ? <int>{dueDate.weekday}
                : recurrence.weekdays).toList()
            ..sort();
      // 期限の週の月曜日を起点にする。期限自身が発生日なので、ここを基準に
      // interval 週ずつ進めれば「隔週」などの位相がずれない。
      final weekStart = DateTime(
        dueDate.year,
        dueDate.month,
        dueDate.day - (dueDate.weekday - 1),
      );
      for (var step = 0; step < _recurrenceSearchLimit; step++) {
        for (final weekday in weekdays) {
          final candidate = DateTime(
            weekStart.year,
            weekStart.month,
            weekStart.day + 7 * interval * step + (weekday - 1),
            dueDate.hour,
            dueDate.minute,
            dueDate.second,
            dueDate.millisecond,
            dueDate.microsecond,
          );
          if (candidate.isAfter(after)) return candidate;
        }
      }
      return null;

    case RecurrenceFreq.monthly:
      // step 0（期限と同じ月）も候補に含める。「毎月15日」で期限が3日の
      // ような場合、同じ月の15日が次回になる。
      for (var step = 0; step < _recurrenceSearchLimit; step++) {
        final candidate = _monthlyOccurrence(
          recurrence,
          dueDate,
          interval * step,
        );
        if (candidate.isAfter(after)) return candidate;
      }
      return null;

    case RecurrenceFreq.yearly:
      for (var step = 0; step < _recurrenceSearchLimit; step++) {
        final year = dueDate.year + interval * step;
        final daysInMonth = DateUtils.getDaysInMonth(year, dueDate.month);
        // 2/29 が無い年は 2/28 に丸める
        final day = dueDate.day > daysInMonth ? daysInMonth : dueDate.day;
        final candidate = DateTime(
          year,
          dueDate.month,
          day,
          dueDate.hour,
          dueDate.minute,
          dueDate.second,
          dueDate.millisecond,
          dueDate.microsecond,
        );
        if (candidate.isAfter(after)) return candidate;
      }
      return null;
  }
}

// 期限の [monthsAhead] か月後の月における発生日。時刻は期限のものを引き継ぐ。
DateTime _monthlyOccurrence(
  Recurrence recurrence,
  DateTime dueDate,
  int monthsAhead,
) {
  final monthIndex = dueDate.month - 1 + monthsAhead;
  final year = dueDate.year + monthIndex ~/ 12;
  final month = monthIndex % 12 + 1;
  final daysInMonth = DateUtils.getDaysInMonth(year, month);

  int day;
  if (recurrence.monthlyMode == MonthlyMode.dayOfMonth) {
    final target = recurrence.monthDay ?? dueDate.day;
    // 「31日」を指定した2月などは、その月の末日にする
    day = target > daysInMonth ? daysInMonth : target;
  } else {
    final weekday = recurrence.monthWeekday ?? dueDate.weekday;
    final ordinal =
        recurrence.weekOrdinal ?? recurrenceWeekdayOrdinal(dueDate);
    if (ordinal == lastWeekdayOrdinal) {
      final lastWeekday = DateTime(year, month, daysInMonth).weekday;
      day = daysInMonth - (lastWeekday - weekday + 7) % 7;
    } else {
      final firstWeekday = DateTime(year, month, 1).weekday;
      day = 1 + (weekday - firstWeekday + 7) % 7 + (ordinal - 1) * 7;
      // 第5○曜日が無い月は、その月で最後に来る同曜日に丸める
      while (day > daysInMonth) {
        day -= 7;
      }
    }
  }

  return DateTime(
    year,
    month,
    day,
    dueDate.hour,
    dueDate.minute,
    dueDate.second,
    dueDate.millisecond,
    dueDate.microsecond,
  );
}

// ─────────────────────────────────────────────
// 表示ラベル
// ─────────────────────────────────────────────

// 「2週ごと 月・水」「毎月第2火曜日 あと3回」のような表示用の文字列。
// 曜日・日を省略している設定は [dueDate] から補って具体的に表示する。
String recurrenceLabel(Recurrence recurrence, DateTime? dueDate) {
  final base = _recurrenceBaseLabel(recurrence, dueDate);
  final end = _recurrenceEndLabel(recurrence);
  return end == null ? base : '$base $end';
}

String _recurrenceBaseLabel(Recurrence recurrence, DateTime? dueDate) {
  final isEvery = recurrence.interval <= 1;
  switch (recurrence.freq) {
    case RecurrenceFreq.daily:
      return isEvery ? '毎日' : '${recurrence.interval}日ごと';

    case RecurrenceFreq.weekly:
      final head = isEvery ? '毎週' : '${recurrence.interval}週ごと';
      final weekdays =
          (recurrence.weekdays.isEmpty
                ? (dueDate != null ? <int>{dueDate.weekday} : <int>{})
                : recurrence.weekdays).toList()
            ..sort();
      // 期限が未設定で曜日が決まらないときは、他のプリセットと
      // 見分けが付くように補足を付ける
      if (weekdays.isEmpty) return '$head（期限の曜日）';
      final names = weekdays.map((w) => weekdayNames[w - 1]).join('・');
      // 1曜日だけなら「毎週火曜日」、複数なら「毎週 月・水・金」
      if (weekdays.length == 1) {
        return isEvery ? '$head$names曜日' : '$head $names曜日';
      }
      return '$head $names';

    case RecurrenceFreq.monthly:
      final head = isEvery ? '毎月' : '${recurrence.interval}か月ごと';
      final sep = isEvery ? '' : ' ';
      if (recurrence.monthlyMode == MonthlyMode.dayOfMonth) {
        final day = recurrence.monthDay ?? dueDate?.day;
        return day == null ? '$head（期限の日）' : '$head$sep$day日';
      }
      final weekday = recurrence.monthWeekday ?? dueDate?.weekday;
      final ordinal =
          recurrence.weekOrdinal ??
          (dueDate != null ? recurrenceWeekdayOrdinal(dueDate) : null);
      if (weekday == null || ordinal == null) return '$head（期限の曜日）';
      final name = weekdayNames[weekday - 1];
      return ordinal == lastWeekdayOrdinal
          ? '$head$sep最終$name曜日'
          : '$head$sep第$ordinal$name曜日';

    case RecurrenceFreq.yearly:
      final head = isEvery ? '毎年' : '${recurrence.interval}年ごと';
      if (dueDate == null) return head;
      final sep = isEvery ? '' : ' ';
      return '$head$sep${dueDate.month}月${dueDate.day}日';
  }
}

String? _recurrenceEndLabel(Recurrence recurrence) {
  switch (recurrence.end) {
    case RecurrenceEnd.never:
      return null;
    case RecurrenceEnd.until:
      final until = recurrence.until;
      return until == null ? null : '〜${DateFormat('yyyy/M/d').format(until)}';
    case RecurrenceEnd.count:
      final count = recurrence.count;
      if (count == null) return null;
      final left = count - recurrence.doneCount;
      return left <= 0 ? '(繰り返し終了)' : 'あと$left回';
  }
}

// ─────────────────────────────────────────────
// プリセット
// ─────────────────────────────────────────────

// 繰り返しの選択肢に並べるプリセット。期限の日付から具体化する。
List<Recurrence> recurrencePresets(DateTime? dueDate) {
  final weekday = dueDate?.weekday;
  return [
    const Recurrence(freq: RecurrenceFreq.daily),
    Recurrence(
      freq: RecurrenceFreq.weekly,
      weekdays: weekday == null ? const <int>{} : <int>{weekday},
    ),
    // 平日（月〜金）
    const Recurrence(
      freq: RecurrenceFreq.weekly,
      weekdays: <int>{1, 2, 3, 4, 5},
    ),
    Recurrence(freq: RecurrenceFreq.monthly, monthDay: dueDate?.day),
    Recurrence(
      freq: RecurrenceFreq.monthly,
      monthlyMode: MonthlyMode.nthWeekday,
      weekOrdinal: dueDate == null ? null : recurrenceWeekdayOrdinal(dueDate),
      monthWeekday: weekday,
    ),
    const Recurrence(freq: RecurrenceFreq.yearly),
  ];
}
