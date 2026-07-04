import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

// カスタム通知で使う時間の単位
enum NotificationUnit {
  minutes('分', 1),
  hours('時間', 60),
  days('日', 1440),
  weeks('週', 10080);

  final String label;
  final int minutesPerUnit;
  const NotificationUnit(this.label, this.minutesPerUnit);
}

// 期限までの分数を「1日2時間前」のような表示ラベルに変換する。
String notificationOffsetLabel(int minutes) {
  if (minutes <= 0) return '期限の時間';
  // ちょうど週単位なら「○週前」と表示する
  if (minutes % 10080 == 0) return '${minutes ~/ 10080}週前';
  final days = minutes ~/ 1440;
  final hours = (minutes % 1440) ~/ 60;
  final mins = minutes % 60;
  final buffer = StringBuffer();
  if (days > 0) buffer.write('$days日');
  if (hours > 0) buffer.write('$hours時間');
  if (mins > 0) buffer.write('$mins分');
  buffer.write('前');
  return buffer.toString();
}

// カスタムの通知タイミング（期限までの分数）をホイールで選ぶシートを開く。
// [maxOffsetMinutes] を超える値（通知時刻が現在より前になる）は設定不可。
// 期限に依らない用途（設定でのプリセット編集など）では制限なしの既定値を使う。
Future<int?> showCustomNotificationOffsetSheet(
  BuildContext context, {
  required Color accentColor,
  int maxOffsetMinutes = 1 << 30,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _CustomNotificationSheet(
      accentColor: accentColor,
      maxOffsetMinutes: maxOffsetMinutes,
    ),
  );
}

// Googleカレンダー風のホイールピッカーでカスタム通知時間を選ぶボトムシート。
// 「数値」列と「単位（分／時間／日）」列の2連ホイールで構成する。
class _CustomNotificationSheet extends StatefulWidget {
  const _CustomNotificationSheet({
    required this.accentColor,
    required this.maxOffsetMinutes,
  });

  final Color accentColor;
  // これを超える値は通知時刻が現在より前になるため設定不可
  final int maxOffsetMinutes;

  @override
  State<_CustomNotificationSheet> createState() =>
      _CustomNotificationSheetState();
}

class _CustomNotificationSheetState extends State<_CustomNotificationSheet> {
  static const double _itemExtent = 44;

  int _number = 30;
  NotificationUnit _unit = NotificationUnit.minutes;
  late final FixedExtentScrollController _numberController;
  late final FixedExtentScrollController _unitController;
  // 期限までに「1単位ぶん」が収まる単位だけを選べるようにする
  // （例: 今日タスクは残りが1日未満なので「日」「週」は表示しない）
  late final List<NotificationUnit> _allowedUnits;

  @override
  void initState() {
    super.initState();
    final allowed = NotificationUnit.values
        .where((u) => u.minutesPerUnit <= widget.maxOffsetMinutes)
        .toList();
    _allowedUnits = allowed.isEmpty ? [NotificationUnit.minutes] : allowed;
    if (!_allowedUnits.contains(_unit)) {
      _unit = _allowedUnits.first;
    }
    _numberController = FixedExtentScrollController(initialItem: _number - 1);
    _unitController = FixedExtentScrollController(
      initialItem: _allowedUnits.indexOf(_unit),
    );
  }

  @override
  void dispose() {
    _numberController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  // 数値ホイールに並べる項目数。分は60、時間は24まで（最後の値は上位単位へ繰り上がる）。
  int _wheelCount(NotificationUnit unit) {
    switch (unit) {
      case NotificationUnit.minutes:
        return 60;
      case NotificationUnit.hours:
        return 24;
      case NotificationUnit.days:
        return 28;
      case NotificationUnit.weeks:
        return 4;
    }
  }

  void _onNumberChanged(int index) {
    setState(() => _number = index + 1);
  }

  void _onUnitChanged(int index) {
    final newUnit = _allowedUnits[index];
    final maxValue = _wheelCount(newUnit);
    final clamped = _number > maxValue ? maxValue : _number;
    // 数値が新しい上限を超える場合は、リスト縮小前に位置を補正しておく
    if (clamped != _number) {
      _numberController.jumpToItem(clamped - 1);
    }
    setState(() {
      _unit = newUnit;
      _number = clamped;
    });
  }

  // 完了時に正規化した「期限までの分数」を返す。
  // 60分 → 1時間、24時間 → 1日 のように、確定したタイミングで繰り上がる。
  int get _resultMinutes => _number * _unit.minutesPerUnit;

  @override
  Widget build(BuildContext context) {
    final wheelCount = _wheelCount(_unit);
    final accent = widget.accentColor;
    // 通知時刻が現在より前になる値は確定できない
    final isValid = _resultMinutes <= widget.maxOffsetMinutes;

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ヘッダー（× / タイトル / 完了）
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close),
                color: accent,
                onPressed: () => Navigator.pop(context),
              ),
              const Expanded(
                child: Text(
                  'カスタム通知',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed: isValid
                    ? () => Navigator.pop(context, _resultMinutes)
                    : null,
                child: Text(
                  '完了',
                  style: TextStyle(
                    color: isValid ? accent : Colors.grey,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 1),
          // 選択中のサマリ
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Icon(Icons.notifications_active, color: accent),
                const SizedBox(width: 16),
                Text(
                  '$_number${_unit.label}前',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
          if (!isValid)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '通知時刻が現在時刻より前になるため設定できません',
                style: TextStyle(color: Colors.red.shade400, fontSize: 12),
              ),
            ),
          const Divider(height: 1),
          // 2連ホイール
          SizedBox(
            height: 220,
            child: Stack(
              children: [
                // 中央の選択ハイライト帯
                Center(
                  child: Container(
                    height: _itemExtent,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: _numberController,
                        itemExtent: _itemExtent,
                        selectionOverlay: const SizedBox.shrink(),
                        onSelectedItemChanged: _onNumberChanged,
                        children: [
                          for (var n = 1; n <= wheelCount; n++)
                            Center(
                              child: Text(
                                '$n',
                                style: const TextStyle(fontSize: 20),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: _unitController,
                        itemExtent: _itemExtent,
                        selectionOverlay: const SizedBox.shrink(),
                        onSelectedItemChanged: _onUnitChanged,
                        children: [
                          for (final u in _allowedUnits)
                            Center(
                              child: Text(
                                u.label,
                                style: const TextStyle(fontSize: 20),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
