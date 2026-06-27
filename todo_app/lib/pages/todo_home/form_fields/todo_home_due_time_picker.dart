part of '../../../main.dart';

extension _TodoHomeDueTimePicker on _TodoHomePageState {
  Future<TimeOfDay?> _pickDueTime(
    TimeOfDay initialTime, {
    DateTime? minimumDateTime,
    DateTime? maximumDateTime,
  }) {
    // 下限・上限の両方が指定された場合は、ホイール自体を範囲内に物理的に制限する
    // （日付+時刻モード）。それ以外は従来どおり時刻のみのホイール＋手動チェック。
    final bool bounded = minimumDateTime != null && maximumDateTime != null;

    // 時刻のみモード用：下限より前なら初期値を繰り上げる
    TimeOfDay effectiveInitial = initialTime;
    if (minimumDateTime != null && !bounded) {
      final minMins = minimumDateTime.hour * 60 + minimumDateTime.minute + 1;
      final initMins = initialTime.hour * 60 + initialTime.minute;
      if (initMins < minMins) {
        effectiveInitial = TimeOfDay(
          hour: (minMins ~/ 60) % 24,
          minute: minMins % 60,
        );
      }
    }

    // 範囲制限モード用の下限（分単位に丸める）・上限・初期値（範囲内にクランプ）
    DateTime? minDate;
    DateTime? maxDate;
    final DateTime initialDateTime;
    if (bounded) {
      minDate = DateTime(
        minimumDateTime.year,
        minimumDateTime.month,
        minimumDateTime.day,
        minimumDateTime.hour,
        minimumDateTime.minute,
      );
      maxDate = maximumDateTime;
      var initial = DateTime(
        minimumDateTime.year,
        minimumDateTime.month,
        minimumDateTime.day,
        initialTime.hour,
        initialTime.minute,
      );
      if (initial.isBefore(minDate)) initial = minDate;
      if (initial.isAfter(maxDate)) initial = maxDate;
      initialDateTime = initial;
    } else {
      initialDateTime = DateTime(
        2000,
        1,
        1,
        effectiveInitial.hour,
        effectiveInitial.minute,
      );
    }
    var selectedDateTime = initialDateTime;

    bool isValidTime(DateTime dt) {
      // 範囲制限モードではホイールが物理的に制限されるため常に有効
      if (bounded || minimumDateTime == null) return true;
      final selMins = dt.hour * 60 + dt.minute;
      final minMins = minimumDateTime.hour * 60 + minimumDateTime.minute + 1;
      return selMins >= minMins;
    }

    return showModalBottomSheet<TimeOfDay>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setPickerState) {
            final isValid = isValidTime(selectedDateTime);
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 56,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
                          '時刻を選択',
                          style: TextStyle(
                            color: s.primaryColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            CupertinoButton(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              onPressed: () => Navigator.pop(context),
                              child: const Text(
                                'キャンセル',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                            CupertinoButton(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              onPressed: isValid
                                  ? () => Navigator.pop(
                                      context,
                                      TimeOfDay.fromDateTime(selectedDateTime),
                                    )
                                  : null,
                              child: Text(
                                '決定',
                                style: TextStyle(
                                  color: isValid ? s.primaryColor : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!isValid)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '現在時刻より前の時刻は設定できません',
                        style: TextStyle(
                          color: Colors.red.shade400,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  Divider(height: 1, color: Colors.grey.shade200),
                  SizedBox(
                    height: 216,
                    child: CupertinoDatePicker(
                      mode: bounded
                          ? CupertinoDatePickerMode.dateAndTime
                          : CupertinoDatePickerMode.time,
                      initialDateTime: initialDateTime,
                      minimumDate: minDate,
                      maximumDate: maxDate,
                      use24hFormat: true,
                      minuteInterval: 1,
                      onDateTimeChanged: (dateTime) {
                        selectedDateTime = dateTime;
                        setPickerState(() {});
                      },
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
