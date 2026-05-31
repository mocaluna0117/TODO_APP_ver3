part of '../main.dart';

extension _TodoHomeTimePickerRow on _TodoHomePageState {
  Widget _buildTimeOnlyPickerRow({
    required DateTime? selectedDate,
    required ValueChanged<DateTime> onTimeSelected,
    required VoidCallback onTimeCleared,
  }) {
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final pickedTime = await _pickDueTime(
          selectedDate != null
              ? TimeOfDay.fromDateTime(selectedDate)
              : const TimeOfDay(hour: 9, minute: 0),
          minimumDateTime: now,
        );
        if (pickedTime != null) {
          final today = now;
          onTimeSelected(
            DateTime(
              today.year,
              today.month,
              today.day,
              pickedTime.hour,
              pickedTime.minute,
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5FA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time, size: 18, color: s.primaryColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                selectedDate != null
                    ? DateFormat('HH:mm').format(selectedDate)
                    : '時間を設定（任意）',
                style: TextStyle(
                  fontSize: 15,
                  color: selectedDate != null ? Colors.black87 : Colors.grey,
                ),
              ),
            ),
            if (selectedDate != null)
              GestureDetector(
                onTap: onTimeCleared,
                child: Icon(Icons.close, size: 18, color: Colors.grey.shade400),
              ),
          ],
        ),
      ),
    );
  }
}
