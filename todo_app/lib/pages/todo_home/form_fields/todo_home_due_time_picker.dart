part of '../../../main.dart';

extension _TodoHomeDueTimePicker on _TodoHomePageState {
  // 期限の時刻を選ぶホイールシート。
  // 過去の期限も設定できるようにしているため、選択できる時刻に制限は設けない。
  Future<TimeOfDay?> _pickDueTime(TimeOfDay initialTime) {
    // 時刻だけを扱うので日付部分は固定のダミー値を使う
    final initialDateTime = DateTime(
      2000,
      1,
      1,
      initialTime.hour,
      initialTime.minute,
    );
    var selectedDateTime = initialDateTime;

    return showModalBottomSheet<TimeOfDay>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: s.surfaceColor,
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
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'キャンセル',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          onPressed: () => Navigator.pop(
                            context,
                            TimeOfDay.fromDateTime(selectedDateTime),
                          ),
                          child: Text(
                            '決定',
                            style: TextStyle(
                              color: s.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: s.dividerColor),
              SizedBox(
                height: 216,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  initialDateTime: initialDateTime,
                  use24hFormat: true,
                  minuteInterval: 1,
                  onDateTimeChanged: (dateTime) => selectedDateTime = dateTime,
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        );
      },
    );
  }
}
