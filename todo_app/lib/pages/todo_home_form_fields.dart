part of '../main.dart';

extension _TodoHomeFormFields on _TodoHomePageState {
  Widget _buildDatePickerRow({
    required DateTime? selectedDate,
    required ValueChanged<DateTime> onDateSelected,
    required VoidCallback onDateCleared,
  }) {
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final pickedDate = await showDatePicker(
          context: context,
          initialDate: selectedDate != null && selectedDate.isAfter(now)
              ? selectedDate
              : now,
          firstDate: DateTime(now.year, now.month, now.day),
          lastDate: now.add(const Duration(days: 365 * 5)),
          locale: const Locale('ja'),
        );
        if (pickedDate != null) {
          if (!mounted) return;
          final isToday =
              pickedDate.year == now.year &&
              pickedDate.month == now.month &&
              pickedDate.day == now.day;
          final pickedTime = await _pickDueTime(
            selectedDate != null
                ? TimeOfDay.fromDateTime(selectedDate)
                : const TimeOfDay(hour: 9, minute: 0),
            minimumDateTime: isToday ? now : null,
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
          color: const Color(0xFFF5F5FA),
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
                  color: selectedDate != null ? Colors.black87 : Colors.grey,
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

  Future<TimeOfDay?> _pickDueTime(
    TimeOfDay initialTime, {
    DateTime? minimumDateTime,
  }) {
    // When a minimum exists, snap the initial time forward if it's already past
    TimeOfDay effectiveInitial = initialTime;
    if (minimumDateTime != null) {
      final minMins = minimumDateTime.hour * 60 + minimumDateTime.minute + 1;
      final initMins = initialTime.hour * 60 + initialTime.minute;
      if (initMins < minMins) {
        effectiveInitial = TimeOfDay(
          hour: (minMins ~/ 60) % 24,
          minute: minMins % 60,
        );
      }
    }

    final initialDateTime = DateTime(
      2000,
      1,
      1,
      effectiveInitial.hour,
      effectiveInitial.minute,
    );
    var selectedDateTime = initialDateTime;

    bool isValidTime(DateTime dt) {
      if (minimumDateTime == null) return true;
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
                      mode: CupertinoDatePickerMode.time,
                      initialDateTime: initialDateTime,
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

  Widget _buildImagePickerRow({
    required List<String> imageBase64List,
    required ValueChanged<List<String>> onImagesChanged,
  }) {
    final imageBytesList = _decodeImages(imageBase64List);

    return InkWell(
      onTap: () async {
        try {
          final pickedImageBase64List = await _pickImageBase64List();
          if (pickedImageBase64List.isNotEmpty) {
            onImagesChanged([...imageBase64List, ...pickedImageBase64List]);
          }
        } catch (_) {
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('画像を選択できませんでした')));
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5FA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (imageBytesList.isNotEmpty) ...[
              SizedBox(
                height: 320,
                child: PageView.builder(
                  itemCount: imageBytesList.length,
                  itemBuilder: (context, index) {
                    final imageBytes = imageBytesList[index];
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: GestureDetector(
                            onTap: () => _showImagePreview(
                              imageBytesList,
                              initialIndex: index,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                imageBytes,
                                width: double.infinity,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints.tightFor(
                                width: 34,
                                height: 34,
                              ),
                              padding: EdgeInsets.zero,
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 18,
                              ),
                              tooltip: 'この画像を削除',
                              onPressed: () {
                                final nextImages = [...imageBase64List]
                                  ..removeAt(index);
                                onImagesChanged(nextImages);
                              },
                            ),
                          ),
                        ),
                        if (imageBytesList.length > 1)
                          Positioned(
                            left: 8,
                            bottom: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${index + 1}/${imageBytesList.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Icon(Icons.image_outlined, size: 20, color: s.primaryColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    imageBytesList.isNotEmpty
                        ? '画像を追加（${imageBytesList.length}枚）'
                        : '画像を添付（任意）',
                    style: TextStyle(
                      fontSize: 15,
                      color: imageBytesList.isNotEmpty
                          ? Colors.black87
                          : Colors.grey,
                    ),
                  ),
                ),
                if (imageBytesList.isNotEmpty)
                  GestureDetector(
                    onTap: () => onImagesChanged([]),
                    child: Icon(
                      Icons.close,
                      size: 18,
                      color: Colors.grey.shade400,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskTagPicker({
    required String? selectedTaskTag,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: selectedTaskTag ?? noTaskTagLabel,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'タグ',
        prefixIcon: Icon(Icons.label_outline, color: s.primaryColor),
        filled: true,
        fillColor: const Color(0xFFF5F5FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      items: [
        noTaskTagLabel,
        ...s.taskTags,
      ].map((tag) => DropdownMenuItem(value: tag, child: Text(tag))).toList(),
      onChanged: (tag) {
        if (tag != null) {
          onChanged(tag == noTaskTagLabel ? null : tag);
        }
      },
    );
  }

  Widget _buildRecurrencePicker({
    required RecurrenceRule selectedRecurrenceRule,
    required ValueChanged<RecurrenceRule> onChanged,
  }) {
    return DropdownButtonFormField<RecurrenceRule>(
      initialValue: selectedRecurrenceRule,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: '繰り返し',
        prefixIcon: Icon(Icons.repeat, color: s.primaryColor),
        filled: true,
        fillColor: const Color(0xFFF5F5FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      items: RecurrenceRule.values
          .map((rule) => DropdownMenuItem(value: rule, child: Text(rule.label)))
          .toList(),
      onChanged: (rule) {
        if (rule != null) {
          onChanged(rule);
        }
      },
    );
  }

  Widget _buildTaskPriorityPicker({
    required TaskPriority selectedTaskPriority,
    required ValueChanged<TaskPriority> onChanged,
  }) {
    final selectedStars = priorityStarCount(selectedTaskPriority);

    return Container(
      padding: const EdgeInsets.only(left: 16, right: 8, top: 8, bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.star_outline_rounded, color: s.primaryColor),
          const SizedBox(width: 10),
          const Text(
            '優先度',
            style: TextStyle(fontSize: 15, color: Colors.black87),
          ),
          const Spacer(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (index) {
              final starNumber = index + 1;
              final isSelected = selectedStars >= starNumber;

              return IconButton(
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(
                  width: 36,
                  height: 36,
                ),
                padding: EdgeInsets.zero,
                tooltip: '$starNumberつ星',
                icon: Icon(
                  isSelected ? Icons.star_rounded : Icons.star_border_rounded,
                  color: isSelected
                      ? priorityColor(selectedTaskPriority)
                      : Colors.grey.shade400,
                  size: 26,
                ),
                onPressed: () => onChanged(priorityFromStarCount(starNumber)),
              );
            }),
          ),
          if (selectedTaskPriority != TaskPriority.none)
            IconButton(
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 32, height: 36),
              padding: EdgeInsets.zero,
              tooltip: '優先度を解除',
              icon: Icon(Icons.close, size: 18, color: Colors.grey.shade500),
              onPressed: () => onChanged(TaskPriority.none),
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildPriorityStars(
    TaskPriority priority, {
    double size = 14,
    Color? color,
  }) {
    final selectedStars = priorityStarCount(priority);
    final activeColor = color ?? priorityColor(priority);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        final isSelected = index < selectedStars;
        return Icon(
          isSelected ? Icons.star_rounded : Icons.star_border_rounded,
          size: size,
          color: isSelected ? activeColor : Colors.grey.shade400,
        );
      }),
    );
  }
}
