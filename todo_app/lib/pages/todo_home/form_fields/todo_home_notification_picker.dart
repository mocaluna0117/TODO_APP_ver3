part of '../../../main.dart';

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

  // 通知時刻（期限 - オフセット）が現在時刻以降なら設定可能。
  bool _isOffsetSelectable(DateTime dueDate, int minutes) =>
      !dueDate.subtract(Duration(minutes: minutes)).isBefore(DateTime.now());

  // Googleカレンダー風に、通知を1件ずつ行で並べて表示する。
  // 各行はドロップダウンでタイミングを変更でき、末尾の行から件数を追加できる。
  // 通知時刻が現在時刻より前になるオフセットは選べないようにする。
  Widget _buildNotificationTimingPicker({
    required DateTime dueDate,
    required List<int> selectedOffsets,
    required ValueChanged<List<int>> onChanged,
  }) {
    // 通知時刻が現在より前になるものは除外（例: 今日タスクの「1日前」）
    final valid = ([...selectedOffsets]..sort())
        .where((m) => _isOffsetSelectable(dueDate, m))
        .toList();

    // 期限変更などで無効になったオフセットは保存データからも取り除く
    if (valid.length != selectedOffsets.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onChanged(valid));
    }

    List<int> withReplaced(int index, int minutes) {
      final next = [...valid];
      next[index] = minutes;
      return next.toSet().toList()..sort();
    }

    List<int> withRemoved(int index) {
      return [...valid]..removeAt(index);
    }

    List<int> withAdded(int minutes) {
      if (valid.contains(minutes)) return valid;
      return [...valid, minutes]..sort();
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
          if (valid.isEmpty)
            _buildNotificationRow(
              dueDate: dueDate,
              showLeadingIcon: true,
              label: '通知を追加',
              isPlaceholder: true,
              currentMinutes: null,
              onSelected: (minutes) => onChanged(withAdded(minutes)),
            )
          else ...[
            for (var i = 0; i < valid.length; i++)
              _buildNotificationRow(
                dueDate: dueDate,
                showLeadingIcon: i == 0,
                label: notificationOffsetLabel(valid[i]),
                isPlaceholder: false,
                currentMinutes: valid[i],
                onSelected: (minutes) => onChanged(withReplaced(i, minutes)),
                onRemove: () => onChanged(withRemoved(i)),
              ),
            _buildNotificationRow(
              dueDate: dueDate,
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
    required DateTime dueDate,
    required bool showLeadingIcon,
    required String label,
    required bool isPlaceholder,
    required int? currentMinutes,
    required ValueChanged<int> onSelected,
    VoidCallback? onRemove,
  }) {
    // 「期限の時間」(0) と設定でカスタマイズしたプリセット + 現在のカスタム値を
    // 選択肢にする。通知時刻が現在より前になるものは除外。
    final optionMinutes =
        {0, ...s.notificationPresets, ?currentMinutes}
            .where((m) => _isOffsetSelectable(dueDate, m))
            .toList()
          ..sort();

    // 期限までの残り分数（これを超えるカスタム値は過去になるため設定不可）
    final maxOffsetMinutes = dueDate.difference(DateTime.now()).inMinutes;

    return PopupMenuButton<int>(
      tooltip: '通知タイミングを選択',
      position: PopupMenuPosition.under,
      constraints: const BoxConstraints(minWidth: 200),
      onSelected: (value) async {
        if (value == _customNotificationAction) {
          final minutes = await showCustomNotificationOffsetSheet(
            context,
            accentColor: s.primaryColor,
            maxOffsetMinutes: maxOffsetMinutes,
          );
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
}
