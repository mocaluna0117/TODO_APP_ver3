// 繰り返し設定（Recurrence）の単体テスト。
// 期限を完了するたびに「次回の期限」へ進む仕組みなので、ここでは
// nextRecurrenceDate を繰り返し呼んで実際の遷移列を検証する。
import 'package:flutter_test/flutter_test.dart';

import 'package:todo_app/main.dart';

// 期限を基準に、次回以降の期限を [times] 回ぶん並べる。
// 実際のアプリと同じく、進んだ先の期限を次の基準にする。
List<DateTime> _sequence(
  Recurrence recurrence,
  DateTime dueDate, {
  int times = 4,
  DateTime? now,
}) {
  final result = <DateTime>[];
  var current = dueDate;
  var reference = now ?? dueDate;
  for (var i = 0; i < times; i++) {
    final after = reference.isAfter(current) ? reference : current;
    final next = nextRecurrenceDate(recurrence, current, after);
    if (next == null) break;
    result.add(next);
    current = next;
    // 次回の期限の直前に完了した想定
    reference = next.subtract(const Duration(minutes: 1));
  }
  return result;
}

List<String> _iso(List<DateTime> dates) =>
    dates.map((d) => d.toIso8601String()).toList();

void main() {
  group('週単位', () {
    test('2週ごと 月・水 は隔週の位相を保つ', () {
      const recurrence = Recurrence(
        freq: RecurrenceFreq.weekly,
        interval: 2,
        weekdays: {1, 3},
      );
      // 2026-08-24 は月曜
      final dates = _sequence(
        recurrence,
        DateTime(2026, 8, 24, 9, 0),
        times: 5,
      );
      expect(_iso(dates), [
        DateTime(2026, 8, 26, 9, 0).toIso8601String(), // 同じ週の水曜
        DateTime(2026, 9, 7, 9, 0).toIso8601String(), // 1週飛ばして月曜
        DateTime(2026, 9, 9, 9, 0).toIso8601String(),
        DateTime(2026, 9, 21, 9, 0).toIso8601String(),
        DateTime(2026, 9, 23, 9, 0).toIso8601String(),
      ]);
    });

    test('平日（月〜金）は土日を飛ばす', () {
      const recurrence = Recurrence(
        freq: RecurrenceFreq.weekly,
        weekdays: {1, 2, 3, 4, 5},
      );
      final dates = _sequence(
        recurrence,
        DateTime(2026, 8, 27, 9, 0), // 木曜
        times: 3,
      );
      expect(_iso(dates), [
        DateTime(2026, 8, 28, 9, 0).toIso8601String(), // 金
        DateTime(2026, 8, 31, 9, 0).toIso8601String(), // 月（土日を飛ばす）
        DateTime(2026, 9, 1, 9, 0).toIso8601String(),
      ]);
    });

    test('曜日未指定なら期限の曜日を使う', () {
      const recurrence = Recurrence(freq: RecurrenceFreq.weekly);
      final dates = _sequence(recurrence, DateTime(2026, 8, 24, 9, 0), times: 2);
      expect(_iso(dates), [
        DateTime(2026, 8, 31, 9, 0).toIso8601String(),
        DateTime(2026, 9, 7, 9, 0).toIso8601String(),
      ]);
    });

    test('期限の曜日が対象外でも、指定した曜日にだけ発生する', () {
      // 期限は日曜だが、繰り返すのは火曜だけ
      const recurrence = Recurrence(
        freq: RecurrenceFreq.weekly,
        weekdays: {2},
      );
      final dates = _sequence(recurrence, DateTime(2026, 8, 23, 9, 0), times: 2);
      expect(_iso(dates), [
        DateTime(2026, 8, 25, 9, 0).toIso8601String(),
        DateTime(2026, 9, 1, 9, 0).toIso8601String(),
      ]);
    });
  });

  group('月単位（日付指定）', () {
    test('毎月31日は短い月で月末に丸めても基準がずれない', () {
      const recurrence = Recurrence(
        freq: RecurrenceFreq.monthly,
        monthDay: 31,
      );
      final dates = _sequence(
        recurrence,
        DateTime(2026, 8, 31, 9, 0),
        times: 6,
      );
      expect(_iso(dates), [
        DateTime(2026, 9, 30, 9, 0).toIso8601String(),
        DateTime(2026, 10, 31, 9, 0).toIso8601String(), // 31日に戻る
        DateTime(2026, 11, 30, 9, 0).toIso8601String(),
        DateTime(2026, 12, 31, 9, 0).toIso8601String(),
        DateTime(2027, 1, 31, 9, 0).toIso8601String(),
        DateTime(2027, 2, 28, 9, 0).toIso8601String(),
      ]);
    });

    test('2か月ごと15日（期限は同月の15日より前）', () {
      const recurrence = Recurrence(
        freq: RecurrenceFreq.monthly,
        interval: 2,
        monthDay: 15,
      );
      // 期限 8/3 の時点では同じ月の 8/15 がまだ先なので、それが次回になる
      final dates = _sequence(recurrence, DateTime(2026, 8, 3, 9, 0), times: 3);
      expect(_iso(dates), [
        DateTime(2026, 8, 15, 9, 0).toIso8601String(),
        DateTime(2026, 10, 15, 9, 0).toIso8601String(),
        DateTime(2026, 12, 15, 9, 0).toIso8601String(),
      ]);
    });

    test('日付未指定なら期限の日を使う', () {
      const recurrence = Recurrence(freq: RecurrenceFreq.monthly);
      final dates = _sequence(recurrence, DateTime(2026, 8, 11, 9, 0), times: 2);
      expect(_iso(dates), [
        DateTime(2026, 9, 11, 9, 0).toIso8601String(),
        DateTime(2026, 10, 11, 9, 0).toIso8601String(),
      ]);
    });
  });

  group('月単位（曜日指定）', () {
    test('3か月ごと第2火曜日', () {
      const recurrence = Recurrence(
        freq: RecurrenceFreq.monthly,
        interval: 3,
        monthlyMode: MonthlyMode.nthWeekday,
        weekOrdinal: 2,
        monthWeekday: 2,
      );
      final dates = _sequence(
        recurrence,
        DateTime(2026, 8, 11, 9, 0),
        times: 4,
      );
      expect(_iso(dates), [
        DateTime(2026, 11, 10, 9, 0).toIso8601String(),
        DateTime(2027, 2, 9, 9, 0).toIso8601String(),
        DateTime(2027, 5, 11, 9, 0).toIso8601String(),
        DateTime(2027, 8, 10, 9, 0).toIso8601String(),
      ]);
    });

    test('毎月最終金曜日', () {
      const recurrence = Recurrence(
        freq: RecurrenceFreq.monthly,
        monthlyMode: MonthlyMode.nthWeekday,
        weekOrdinal: lastWeekdayOrdinal,
        monthWeekday: 5,
      );
      final dates = _sequence(
        recurrence,
        DateTime(2026, 8, 28, 9, 0),
        times: 4,
      );
      expect(_iso(dates), [
        DateTime(2026, 9, 25, 9, 0).toIso8601String(),
        DateTime(2026, 10, 30, 9, 0).toIso8601String(),
        DateTime(2026, 11, 27, 9, 0).toIso8601String(),
        DateTime(2026, 12, 25, 9, 0).toIso8601String(),
      ]);
    });

    test('毎月第5月曜日は無い月だけ最後の月曜日に丸め、翌月は第5に戻る', () {
      const recurrence = Recurrence(
        freq: RecurrenceFreq.monthly,
        monthlyMode: MonthlyMode.nthWeekday,
        weekOrdinal: 5,
        monthWeekday: 1,
      );
      final dates = _sequence(
        recurrence,
        DateTime(2026, 8, 31, 9, 0),
        times: 4,
      );
      expect(_iso(dates), [
        DateTime(2026, 9, 28, 9, 0).toIso8601String(), // 9月は第4止まり
        DateTime(2026, 10, 26, 9, 0).toIso8601String(),
        DateTime(2026, 11, 30, 9, 0).toIso8601String(), // 11月は第5月曜あり
        DateTime(2026, 12, 28, 9, 0).toIso8601String(),
      ]);
    });
  });

  group('年単位', () {
    test('毎年は同じ月日で繰り返す', () {
      const recurrence = Recurrence(freq: RecurrenceFreq.yearly);
      final dates = _sequence(recurrence, DateTime(2026, 8, 11, 9, 0), times: 2);
      expect(_iso(dates), [
        DateTime(2027, 8, 11, 9, 0).toIso8601String(),
        DateTime(2028, 8, 11, 9, 0).toIso8601String(),
      ]);
    });

    test('2/29 はうるう年でない年に 2/28 へ丸める', () {
      const recurrence = Recurrence(freq: RecurrenceFreq.yearly);
      final next = nextRecurrenceDate(
        recurrence,
        DateTime(2028, 2, 29, 9, 0),
        DateTime(2028, 2, 29, 9, 0),
      );
      expect(next, DateTime(2029, 2, 28, 9, 0));
    });
  });

  group('期限が過去でも現在より後へ進む', () {
    final past = DateTime(2021, 8, 11, 9, 0);
    final now = DateTime(2026, 8, 23, 12, 0);

    test('毎日', () {
      final next = nextRecurrenceDate(
        const Recurrence(freq: RecurrenceFreq.daily),
        past,
        now,
      );
      expect(next, DateTime(2026, 8, 24, 9, 0));
    });

    test('3日ごとでも間隔の位相を保つ', () {
      final next = nextRecurrenceDate(
        const Recurrence(freq: RecurrenceFreq.daily, interval: 3),
        past,
        now,
      );
      expect(next, DateTime(2026, 8, 24, 9, 0));
      expect(next!.difference(past).inDays % 3, 0);
    });

    test('7日ごと', () {
      final next = nextRecurrenceDate(
        const Recurrence(freq: RecurrenceFreq.daily, interval: 7),
        past,
        now,
      );
      expect(next, DateTime(2026, 8, 26, 9, 0));
      expect(next!.difference(past).inDays % 7, 0);
    });

    test('毎週・毎月・毎年も現在より後になる', () {
      for (final recurrence in const [
        Recurrence(freq: RecurrenceFreq.weekly),
        Recurrence(freq: RecurrenceFreq.monthly),
        Recurrence(freq: RecurrenceFreq.yearly),
      ]) {
        final next = nextRecurrenceDate(recurrence, past, now);
        expect(next, isNotNull, reason: '${recurrence.freq} が算出できない');
        expect(next!.isAfter(now), isTrue, reason: '${recurrence.freq} が過去');
      }
    });
  });

  group('終了条件（終了日）', () {
    const recurrence = Recurrence(
      freq: RecurrenceFreq.weekly,
      weekdays: {1},
      end: RecurrenceEnd.until,
    );

    test('終了日と同じ日の回は繰り返す', () {
      final r = recurrence.copyWith(until: DateTime(2026, 10, 26, 23, 59));
      final next = nextRecurrenceDate(
        r,
        DateTime(2026, 10, 19, 9, 0),
        DateTime(2026, 10, 19, 9, 0),
      );
      expect(next, DateTime(2026, 10, 26, 9, 0));
    });

    test('終了日を過ぎる回は null（繰り返し終了）', () {
      final r = recurrence.copyWith(until: DateTime(2026, 10, 26, 23, 59));
      final next = nextRecurrenceDate(
        r,
        DateTime(2026, 10, 26, 9, 0),
        DateTime(2026, 10, 26, 9, 0),
      );
      expect(next, isNull);
    });
  });

  group('JSON', () {
    test('全項目が往復する', () {
      final original = Recurrence(
        freq: RecurrenceFreq.monthly,
        interval: 3,
        weekdays: const {2, 4},
        monthlyMode: MonthlyMode.nthWeekday,
        monthDay: 15,
        weekOrdinal: lastWeekdayOrdinal,
        monthWeekday: 6,
        end: RecurrenceEnd.count,
        count: 12,
        doneCount: 5,
      );
      final restored = Recurrence.fromJson(original.toJson());
      expect(restored, isNotNull);
      expect(restored!.hasSameConfig(original), isTrue);
      expect(restored.doneCount, 5);
      expect(restored.weekdays, original.weekdays);
      expect(restored.monthDay, 15);
      expect(restored.weekOrdinal, lastWeekdayOrdinal);
      expect(restored.monthWeekday, 6);
      expect(restored.count, 12);
    });

    test('終了日も往復する', () {
      final original = Recurrence(
        freq: RecurrenceFreq.weekly,
        end: RecurrenceEnd.until,
        until: DateTime(2026, 12, 31, 23, 59),
      );
      final restored = Recurrence.fromJson(original.toJson())!;
      expect(restored.until, DateTime(2026, 12, 31, 23, 59));
      expect(restored.end, RecurrenceEnd.until);
    });

    test('壊れた値は既定値に丸めて落ちない', () {
      final restored = Recurrence.fromJson({
        'freq': 'weekly',
        'interval': 0,
        'weekdays': [0, 3, 99, 'x'],
        'monthDay': 99,
        'weekOrdinal': 9,
        'monthWeekday': 0,
        'end': 'unknown',
        'count': 0,
      });
      expect(restored, isNotNull);
      expect(restored!.interval, 1);
      expect(restored.weekdays, {3});
      expect(restored.monthDay, isNull);
      expect(restored.weekOrdinal, isNull);
      expect(restored.monthWeekday, isNull);
      expect(restored.end, RecurrenceEnd.never);
      expect(restored.count, isNull);
    });

    test('freq が無い / Map でない値は null', () {
      expect(Recurrence.fromJson(null), isNull);
      expect(Recurrence.fromJson('weekly'), isNull);
      expect(Recurrence.fromJson({'interval': 2}), isNull);
    });
  });

  group('旧形式からの移行', () {
    test('旧 enum 名がすべて変換される', () {
      expect(recurrenceFromLegacyRule('none'), isNull);
      expect(recurrenceFromLegacyRule(null), isNull);
      expect(recurrenceFromLegacyRule('daily')!.freq, RecurrenceFreq.daily);

      final weekly = recurrenceFromLegacyRule('weekly')!;
      expect(weekly.freq, RecurrenceFreq.weekly);
      expect(weekly.interval, 1);
      expect(weekly.weekdays, isEmpty); // 期限の曜日に従う

      expect(recurrenceFromLegacyRule('biweekly')!.interval, 2);
      expect(recurrenceFromLegacyRule('every3Weeks')!.interval, 3);
      expect(recurrenceFromLegacyRule('every4Weeks')!.interval, 4);

      final monthly = recurrenceFromLegacyRule('monthly')!;
      expect(monthly.freq, RecurrenceFreq.monthly);
      expect(monthly.monthlyMode, MonthlyMode.dayOfMonth);
      expect(monthly.monthDay, isNull); // 期限の日に従う

      final nth = recurrenceFromLegacyRule('monthlyNthWeekday')!;
      expect(nth.monthlyMode, MonthlyMode.nthWeekday);
      expect(nth.weekOrdinal, isNull); // 期限から判定

      final last = recurrenceFromLegacyRule('monthlyLastWeekday')!;
      expect(last.monthlyMode, MonthlyMode.nthWeekday);
      expect(last.weekOrdinal, lastWeekdayOrdinal);
    });

    test('旧 index 表記も変換される', () {
      expect(recurrenceFromLegacyRule('0'), isNull);
      expect(recurrenceFromLegacyRule('1')!.freq, RecurrenceFreq.daily);
      expect(recurrenceFromLegacyRule('2')!.freq, RecurrenceFreq.weekly);
      expect(recurrenceFromLegacyRule('3')!.freq, RecurrenceFreq.monthly);
      expect(recurrenceFromLegacyRule('4')!.interval, 2);
      expect(recurrenceFromLegacyRule('8')!.weekOrdinal, lastWeekdayOrdinal);
    });

    test('旧形式で保存されたタスクは読み込み時に移行される', () {
      final item = TodoItem.fromJson(<String, dynamic>{
        'id': 1,
        'title': '旧データ',
        'isDone': false,
        'category': 'todo',
        'dueDate': DateTime(2026, 8, 11, 9, 0).toIso8601String(),
        'recurrenceRule': 'biweekly',
        'imageBase64List': <String>[],
        'priority': 'none',
      });
      expect(item.isRecurring, isTrue);
      expect(item.recurrence!.freq, RecurrenceFreq.weekly);
      expect(item.recurrence!.interval, 2);
      // 移行後は新形式のみを書き出す
      expect(item.toJson()['recurrence'], isA<Map<String, dynamic>>());
      expect(item.toJson().containsKey('recurrenceRule'), isFalse);
    });

    test('新形式があればそちらを優先する', () {
      final item = TodoItem.fromJson(<String, dynamic>{
        'id': 2,
        'title': '新データ',
        'isDone': false,
        'category': 'todo',
        'recurrenceRule': 'daily',
        'recurrence': {'freq': 'yearly', 'interval': 2},
        'imageBase64List': <String>[],
        'priority': 'none',
      });
      expect(item.recurrence!.freq, RecurrenceFreq.yearly);
      expect(item.recurrence!.interval, 2);
    });

    test('繰り返しなしのタスクは recurrence が null', () {
      final item = TodoItem.fromJson(<String, dynamic>{
        'id': 3,
        'title': '単発',
        'isDone': false,
        'category': 'todo',
        'recurrenceRule': 'none',
        'imageBase64List': <String>[],
        'priority': 'none',
      });
      expect(item.isRecurring, isFalse);
      expect(item.toJson()['recurrence'], isNull);
    });
  });

  group('基準の確定（resolvedFor）', () {
    test('日付未指定の毎月は最初の完了で基準を固定し、以降ずれない', () {
      // 旧形式から移行した「毎月」（monthDay 未指定）相当
      var recurrence = const Recurrence(freq: RecurrenceFreq.monthly);
      var current = DateTime(2027, 1, 31, 9, 0);
      final dates = <DateTime>[];
      // _toggleItem と同じ手順（確定 → 次回算出 → 確定後の設定を保存）
      for (var i = 0; i < 3; i++) {
        final resolved = recurrence.resolvedFor(current);
        final next = nextRecurrenceDate(resolved, current, current)!;
        dates.add(next);
        recurrence = resolved;
        current = next;
      }
      expect(_iso(dates), [
        DateTime(2027, 2, 28, 9, 0).toIso8601String(), // 2月は月末へ
        DateTime(2027, 3, 31, 9, 0).toIso8601String(), // 31日に戻る
        DateTime(2027, 4, 30, 9, 0).toIso8601String(),
      ]);
      expect(recurrence.monthDay, 31);
    });

    test('第n週も期限から確定される', () {
      final resolved = const Recurrence(
        freq: RecurrenceFreq.monthly,
        monthlyMode: MonthlyMode.nthWeekday,
      ).resolvedFor(DateTime(2026, 8, 31, 9, 0)); // 第5月曜
      expect(resolved.weekOrdinal, 5);
      expect(resolved.monthWeekday, 1);
    });

    test('関係のない項目は埋めない（プリセット判定を壊さない）', () {
      final due = DateTime(2026, 8, 11, 9, 0);
      final monthly = const Recurrence(
        freq: RecurrenceFreq.monthly,
      ).resolvedFor(due);
      expect(monthly.weekdays, isEmpty);
      expect(monthly.weekOrdinal, isNull);

      final weekly = const Recurrence(
        freq: RecurrenceFreq.weekly,
      ).resolvedFor(due);
      expect(weekly.weekdays, {2}); // 火曜
      expect(weekly.monthDay, isNull);
    });

    test('確定後は対応するプリセットとして認識される', () {
      final due = DateTime(2026, 8, 11, 9, 0); // 火曜・第2週
      final presets = recurrencePresets(due);
      for (final legacy in ['weekly', 'monthly', 'monthlyNthWeekday']) {
        final resolved = recurrenceFromLegacyRule(legacy)!.resolvedFor(due);
        expect(
          presets.any((preset) => preset.hasSameConfig(resolved)),
          isTrue,
          reason: '$legacy がプリセットと一致しない',
        );
      }
    });
  });

  group('表示ラベル', () {
    final due = DateTime(2026, 8, 11, 9, 0); // 火曜・第2週

    test('間隔と曜日が文言に出る', () {
      expect(
        recurrenceLabel(const Recurrence(freq: RecurrenceFreq.daily), due),
        '毎日',
      );
      expect(
        recurrenceLabel(
          const Recurrence(freq: RecurrenceFreq.daily, interval: 3),
          due,
        ),
        '3日ごと',
      );
      expect(
        recurrenceLabel(const Recurrence(freq: RecurrenceFreq.weekly), due),
        '毎週火曜日',
      );
      expect(
        recurrenceLabel(
          const Recurrence(
            freq: RecurrenceFreq.weekly,
            weekdays: {1, 3, 5},
          ),
          due,
        ),
        '毎週 月・水・金',
      );
      expect(
        recurrenceLabel(
          const Recurrence(freq: RecurrenceFreq.weekly, interval: 2),
          due,
        ),
        '2週ごと 火曜日',
      );
    });

    test('月・年の指定方法が文言に出る', () {
      expect(
        recurrenceLabel(const Recurrence(freq: RecurrenceFreq.monthly), due),
        '毎月11日',
      );
      expect(
        recurrenceLabel(
          const Recurrence(
            freq: RecurrenceFreq.monthly,
            monthlyMode: MonthlyMode.nthWeekday,
          ),
          due,
        ),
        '毎月第2火曜日',
      );
      expect(
        recurrenceLabel(
          const Recurrence(
            freq: RecurrenceFreq.monthly,
            monthlyMode: MonthlyMode.nthWeekday,
            weekOrdinal: lastWeekdayOrdinal,
          ),
          due,
        ),
        '毎月最終火曜日',
      );
      expect(
        recurrenceLabel(const Recurrence(freq: RecurrenceFreq.yearly), due),
        '毎年8月11日',
      );
    });

    test('終了条件が末尾に付く', () {
      expect(
        recurrenceLabel(
          Recurrence(
            freq: RecurrenceFreq.weekly,
            end: RecurrenceEnd.until,
            until: DateTime(2026, 12, 31, 23, 59),
          ),
          due,
        ),
        '毎週火曜日 〜2026/12/31',
      );
      expect(
        recurrenceLabel(
          const Recurrence(
            freq: RecurrenceFreq.weekly,
            end: RecurrenceEnd.count,
            count: 10,
            doneCount: 3,
          ),
          due,
        ),
        '毎週火曜日 あと7回',
      );
    });

    test('期限が未設定でも落ちない', () {
      for (final freq in RecurrenceFreq.values) {
        expect(recurrenceLabel(Recurrence(freq: freq), null), isNotEmpty);
      }
    });
  });

  group('プリセット', () {
    test('期限から具体化され、往復して一致する', () {
      final due = DateTime(2026, 8, 11, 9, 0); // 火曜・第2週
      final presets = recurrencePresets(due);
      expect(presets, isNotEmpty);
      for (final preset in presets) {
        // 保存して読み直しても同じプリセットとして認識される
        final restored = Recurrence.fromJson(preset.toJson())!;
        expect(
          restored.hasSameConfig(preset),
          isTrue,
          reason: '${recurrenceLabel(preset, due)} が往復しない',
        );
        // どのプリセットも次回の期限を算出できる
        expect(
          nextRecurrenceDate(preset, due, due),
          isNotNull,
          reason: '${recurrenceLabel(preset, due)} の次回が算出できない',
        );
      }
      expect(
        presets.map((p) => recurrenceLabel(p, due)).toList(),
        containsAll(<String>['毎日', '毎週火曜日', '毎月11日', '毎月第2火曜日']),
      );
    });

    test('期限が未設定でもプリセットを作れ、ラベルが重複しない', () {
      final presets = recurrencePresets(null);
      expect(presets, isNotEmpty);
      final labels = presets.map((p) => recurrenceLabel(p, null)).toList();
      for (final label in labels) {
        expect(label, isNotEmpty);
      }
      // 「毎月」が2行並ぶなど、見分けの付かない選択肢にならないこと
      expect(labels.toSet().length, labels.length, reason: '$labels');
    });
  });
}
