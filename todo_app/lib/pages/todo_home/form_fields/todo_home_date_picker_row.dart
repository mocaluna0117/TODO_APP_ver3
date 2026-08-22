part of '../../../main.dart';

extension _TodoHomeDatePickerRow on _TodoHomePageState {
  Widget _buildDatePickerRow({
    required DateTime? selectedDate,
    required ValueChanged<DateTime> onDateSelected,
    required VoidCallback onDateCleared,
  }) {
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        // 過去の日付も期限に設定できるようにする（記録漏れの後追い入力など）
        final firstDate = DateTime(now.year - 5, now.month, now.day);
        final lastDate = now.add(const Duration(days: 365 * 5));
        // 保存済みの期限が選択範囲外でも落ちないように範囲内へ丸めておく
        var initialDate = selectedDate ?? now;
        if (initialDate.isBefore(firstDate)) initialDate = firstDate;
        if (initialDate.isAfter(lastDate)) initialDate = lastDate;
        final pickedDate = await showDatePicker(
          context: context,
          initialDate: initialDate,
          firstDate: firstDate,
          lastDate: lastDate,
          locale: const Locale('ja'),
        );
        if (pickedDate != null) {
          if (!mounted) return;
          final pickedTime = await _pickDueTime(
            selectedDate != null
                ? TimeOfDay.fromDateTime(selectedDate)
                : const TimeOfDay(hour: 9, minute: 0),
          );
          if (pickedTime != null) {
            onDateSelected(
              DateTime(
                pickedDate.year,
                pickedDate.month,
                pickedDate.day,
                pickedTime.hour,
                pickedTime.minute,
              ),
            );
          }
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: s.fieldColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 18, color: s.primaryColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                selectedDate != null
                    ? DateFormat(
                        'yyyy/MM/dd (E) HH:mm',
                        'ja',
                      ).format(selectedDate)
                    : '期限を設定（任意）',
                style: TextStyle(
                  fontSize: 15,
                  color: selectedDate != null ? s.primaryTextColor : Colors.grey,
                ),
              ),
            ),
            if (selectedDate != null)
              GestureDetector(
                onTap: onDateCleared,
                child: Icon(Icons.close, size: 18, color: Colors.grey.shade400),
              ),
          ],
        ),
      ),
    );
  }
}
