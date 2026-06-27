part of '../../../main.dart';

// カスタム通知ダイアログで使う時間の単位
enum _NotificationUnit {
  minutes('分', 1),
  hours('時間', 60),
  days('日', 1440),
  weeks('週', 10080);

  final String label;
  final int minutesPerUnit;
  const _NotificationUnit(this.label, this.minutesPerUnit);
}

// 通知ドロップダウンのアクション用センチネル値（オフセット分数は常に 0 以上なので衝突しない）
const int _customNotificationAction = -1;
const int _removeNotificationAction = -2;

extension _TodoHomeNotificationPicker on _TodoHomePageState {
  // 新規タスクや未設定タスクに使う既定の通知タイミング（期限までの分数）。
  // 設定画面の通知タイミングを初期値として用いる。
  List<int> _defaultNotificationOffsets() =>
      s.notificationTiming == NotificationTiming.none
      ? <int>[]
      : [notificationTimingToMinutes(s.notificationTiming)];

  // Googleカレンダー風に、通知を1件ずつ行で並べて表示する。
  // 各行はドロップダウンでタイミングを変更でき、末尾の行から件数を追加できる。
  Widget _buildNotificationTimingPicker({
    required List<int> selectedOffsets,
    required ValueChanged<List<int>> onChanged,
  }) {
    final sorted = [...selectedOffsets]..sort();

    List<int> withReplaced(int index, int minutes) {
      final next = [...sorted];
      next[index] = minutes;
      return next.toSet().toList()..sort();
    }

    List<int> withRemoved(int index) {
      return [...sorted]..removeAt(index);
    }

    List<int> withAdded(int minutes) {
      if (sorted.contains(minutes)) return sorted;
      return [...sorted, minutes]..sort();
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (sorted.isEmpty)
            _buildNotificationRow(
              showLeadingIcon: true,
              label: '通知を追加',
              isPlaceholder: true,
              currentMinutes: null,
              onSelected: (minutes) => onChanged(withAdded(minutes)),
            )
          else ...[
            for (var i = 0; i < sorted.length; i++)
              _buildNotificationRow(
                showLeadingIcon: i == 0,
                label: notificationOffsetLabel(sorted[i]),
                isPlaceholder: false,
                currentMinutes: sorted[i],
                onSelected: (minutes) => onChanged(withReplaced(i, minutes)),
                onRemove: () => onChanged(withRemoved(i)),
              ),
            _buildNotificationRow(
              showLeadingIcon: false,
              label: '別の通知を追加',
              isPlaceholder: true,
              currentMinutes: null,
              onSelected: (minutes) => onChanged(withAdded(minutes)),
            ),
          ],
        ],
      ),
    );
  }

  // 通知1件分の行。タップするとタイミング選択のドロップダウンを開く。
  Widget _buildNotificationRow({
    required bool showLeadingIcon,
    required String label,
    required bool isPlaceholder,
    required int? currentMinutes,
    required ValueChanged<int> onSelected,
    VoidCallback? onRemove,
  }) {
    // プリセット + 現在のカスタム値を統合した選択肢
    final optionMinutes =
        {...presetNotificationOffsets, ?currentMinutes}.toList()..sort();

    return PopupMenuButton<int>(
      tooltip: '通知タイミングを選択',
      position: PopupMenuPosition.under,
      constraints: const BoxConstraints(minWidth: 200),
      onSelected: (value) async {
        if (value == _customNotificationAction) {
          final minutes = await _showCustomNotificationOffsetDialog();
          if (minutes != null) onSelected(minutes);
        } else if (value == _removeNotificationAction) {
          onRemove?.call();
        } else {
          onSelected(value);
        }
      },
      itemBuilder: (context) => [
        ...optionMinutes.map((minutes) {
          final isSelected = minutes == currentMinutes;
          return PopupMenuItem<int>(
            value: minutes,
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: isSelected
                      ? Icon(Icons.check, size: 18, color: s.primaryColor)
                      : null,
                ),
                Text(notificationOffsetLabel(minutes)),
              ],
            ),
          );
        }),
        const PopupMenuItem<int>(
          value: _customNotificationAction,
          child: Padding(
            padding: EdgeInsets.only(left: 24),
            child: Text('カスタム...'),
          ),
        ),
        if (onRemove != null) ...[
          const PopupMenuDivider(),
          PopupMenuItem<int>(
            value: _removeNotificationAction,
            child: Padding(
              padding: const EdgeInsets.only(left: 24),
              child: Text('削除', style: TextStyle(color: Colors.red.shade400)),
            ),
          ),
        ],
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: showLeadingIcon
                  ? Icon(Icons.notifications_active, color: s.primaryColor)
                  : null,
            ),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  color: isPlaceholder ? Colors.grey.shade600 : Colors.black87,
                ),
              ),
            ),
            Icon(Icons.unfold_more, size: 20, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }

  // カスタムの通知タイミング（期限までの分数）をホイールで選ぶシート。
  Future<int?> _showCustomNotificationOffsetDialog() {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) =>
          _CustomNotificationSheet(accentColor: s.primaryColor),
    );
  }
}

// Googleカレンダー風のホイールピッカーでカスタム通知時間を選ぶボトムシート。
// 「数値」列と「単位（分／時間／日）」列の2連ホイールで構成する。
class _CustomNotificationSheet extends StatefulWidget {
  const _CustomNotificationSheet({required this.accentColor});

  final Color accentColor;

  @override
  State<_CustomNotificationSheet> createState() =>
      _CustomNotificationSheetState();
}

class _CustomNotificationSheetState extends State<_CustomNotificationSheet> {
  static const double _itemExtent = 44;

  int _number = 30;
  _NotificationUnit _unit = _NotificationUnit.minutes;
  late final FixedExtentScrollController _numberController;
  late final FixedExtentScrollController _unitController;

  @override
  void initState() {
    super.initState();
    _numberController = FixedExtentScrollController(initialItem: _number - 1);
    _unitController = FixedExtentScrollController(initialItem: _unit.index);
  }

  @override
  void dispose() {
    _numberController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  // 数値ホイールに並べる項目数。分は60、時間は24まで（最後の値は上位単位へ繰り上がる）。
  int _wheelCount(_NotificationUnit unit) {
    switch (unit) {
      case _NotificationUnit.minutes:
        return 60;
      case _NotificationUnit.hours:
        return 24;
      case _NotificationUnit.days:
        return 28;
      case _NotificationUnit.weeks:
        return 4;
    }
  }

  void _onNumberChanged(int index) {
    setState(() => _number = index + 1);
  }

  void _onUnitChanged(int index) {
    final newUnit = _NotificationUnit.values[index];
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
                onPressed: () => Navigator.pop(context, _resultMinutes),
                child: Text(
                  '完了',
                  style: TextStyle(color: accent, fontSize: 16),
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
                          for (final u in _NotificationUnit.values)
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
