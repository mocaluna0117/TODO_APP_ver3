part of '../../../main.dart';

// カスタムの繰り返しを組み立てるボトムシート。
// 「なし」は選択メニュー側で選ぶので、ここではキャンセル（null）か設定を返す。
Future<Recurrence?> showRecurrenceSheet(
  BuildContext context, {
  required Recurrence? initial,
  required DateTime? dueDate,
  required Color accentColor,
}) {
  return showModalBottomSheet<Recurrence>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _RecurrenceSheet(
      initial: initial,
      dueDate: dueDate,
      accentColor: accentColor,
    ),
  );
}

class _RecurrenceSheet extends StatefulWidget {
  const _RecurrenceSheet({
    required this.initial,
    required this.dueDate,
    required this.accentColor,
  });

  final Recurrence? initial;
  final DateTime? dueDate;
  final Color accentColor;

  @override
  State<_RecurrenceSheet> createState() => _RecurrenceSheetState();
}

class _RecurrenceSheetState extends State<_RecurrenceSheet> {
  // 間隔として選べる上限（日/週/月/年のどれでも十分な範囲）
  static const int _maxInterval = 30;
  // 「n回繰り返したら終了」で選べる上限
  static const int _maxCount = 50;

  late RecurrenceFreq _freq;
  late int _interval;
  late Set<int> _weekdays;
  late MonthlyMode _monthlyMode;
  late int _monthDay;
  late int _weekOrdinal;
  late int _monthWeekday;
  late RecurrenceEnd _end;
  late DateTime _until;
  late int _count;

  // 曜日・日を省略している設定を具体化するときの基準日
  DateTime get _base => widget.dueDate ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    final base = _base;

    _freq = initial?.freq ?? RecurrenceFreq.weekly;
    _interval = (initial?.interval ?? 1).clamp(1, _maxInterval).toInt();
    _weekdays = {...?initial?.weekdays};
    if (_weekdays.isEmpty) _weekdays.add(base.weekday);
    _monthlyMode = initial?.monthlyMode ?? MonthlyMode.dayOfMonth;
    _monthDay = initial?.monthDay ?? base.day;
    _weekOrdinal = initial?.weekOrdinal ?? recurrenceWeekdayOrdinal(base);
    _monthWeekday = initial?.monthWeekday ?? base.weekday;
    _end = initial?.end ?? RecurrenceEnd.never;
    _until =
        initial?.until ??
        DateTime(base.year + 1, base.month, base.day, 23, 59);
    _count = (initial?.count ?? 10).clamp(1, _maxCount).toInt();
  }

  // 曜日を1つも選んでいない週次設定は日付が決まらないため確定させない
  bool get _isValid => _freq != RecurrenceFreq.weekly || _weekdays.isNotEmpty;

  Recurrence _buildResult() {
    final isWeekly = _freq == RecurrenceFreq.weekly;
    final isMonthly = _freq == RecurrenceFreq.monthly;
    final byWeekday = isMonthly && _monthlyMode == MonthlyMode.nthWeekday;
    return Recurrence(
      freq: _freq,
      interval: _interval,
      weekdays: isWeekly ? {..._weekdays} : const <int>{},
      monthlyMode: _monthlyMode,
      monthDay: isMonthly && !byWeekday ? _monthDay : null,
      weekOrdinal: byWeekday ? _weekOrdinal : null,
      monthWeekday: byWeekday ? _monthWeekday : null,
      end: _end,
      until: _end == RecurrenceEnd.until ? _until : null,
      count: _end == RecurrenceEnd.count ? _count : null,
      // 設定を編集しても「これまでに繰り返した回数」は引き継ぐ
      doneCount: widget.initial?.doneCount ?? 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(accent),
            Divider(height: 1, color: Colors.grey.shade200),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildIntervalRow(),
                    if (_freq == RecurrenceFreq.weekly) ...[
                      const SizedBox(height: 20),
                      _buildSectionTitle('繰り返す曜日'),
                      const SizedBox(height: 8),
                      _buildWeekdayChips(accent),
                      if (!_isValid)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '曜日を1つ以上選んでください',
                            style: TextStyle(
                              color: Colors.red.shade400,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                    if (_freq == RecurrenceFreq.monthly) ...[
                      const SizedBox(height: 20),
                      _buildSectionTitle('繰り返し方'),
                      const SizedBox(height: 4),
                      _buildMonthlyOptions(accent),
                    ],
                    if (_freq == RecurrenceFreq.yearly) ...[
                      const SizedBox(height: 16),
                      Text(
                        '期限の月日（${_base.month}月${_base.day}日）で繰り返します',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    _buildSectionTitle('終了'),
                    const SizedBox(height: 4),
                    _buildEndOptions(accent),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color accent) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 8),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close),
                color: accent,
                onPressed: () => Navigator.pop(context),
              ),
              const Expanded(
                child: Text(
                  'カスタムの繰り返し',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed: _isValid
                    ? () => Navigator.pop(context, _buildResult())
                    : null,
                child: Text(
                  '完了',
                  style: TextStyle(
                    color: _isValid ? accent : Colors.grey,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          // 今の設定がどう解釈されるかをそのまま見せる
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              _isValid
                  ? recurrenceLabel(_buildResult(), widget.dueDate)
                  : '—',
              style: TextStyle(
                fontSize: 13,
                color: accent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade700,
      ),
    );
  }

  Widget _buildIntervalRow() {
    return Row(
      children: [
        Expanded(child: _buildSectionTitle('間隔')),
        _buildDropdown<int>(
          value: _interval,
          items: [
            for (var i = 1; i <= _maxInterval; i++)
              DropdownMenuItem(value: i, child: Text('$i')),
          ],
          onChanged: (value) => setState(() => _interval = value),
        ),
        const SizedBox(width: 8),
        _buildDropdown<RecurrenceFreq>(
          value: _freq,
          items: [
            for (final freq in RecurrenceFreq.values)
              DropdownMenuItem(value: freq, child: Text('${freq.unitLabel}ごと')),
          ],
          onChanged: (value) => setState(() => _freq = value),
        ),
      ],
    );
  }

  Widget _buildWeekdayChips(Color accent) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var weekday = 1; weekday <= 7; weekday++)
          _buildWeekdayChip(weekday, accent),
      ],
    );
  }

  Widget _buildWeekdayChip(int weekday, Color accent) {
    final selected = _weekdays.contains(weekday);
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: () => setState(() {
        if (selected) {
          _weekdays.remove(weekday);
        } else {
          _weekdays.add(weekday);
        }
      }),
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? accent : const Color(0xFFF5F5FA),
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? accent : Colors.grey.shade300,
          ),
        ),
        child: Text(
          weekdayNames[weekday - 1],
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: selected ? Colors.white : Colors.black54,
          ),
        ),
      ),
    );
  }

  Widget _buildMonthlyOptions(Color accent) {
    final byWeekday = _monthlyMode == MonthlyMode.nthWeekday;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildChoiceRow(
          accent: accent,
          selected: !byWeekday,
          onTap: () =>
              setState(() => _monthlyMode = MonthlyMode.dayOfMonth),
          child: Row(
            children: [
              const Text('日付で指定', style: TextStyle(fontSize: 14)),
              const Spacer(),
              _buildDropdown<int>(
                value: _monthDay,
                enabled: !byWeekday,
                items: [
                  for (var day = 1; day <= 31; day++)
                    DropdownMenuItem(value: day, child: Text('$day日')),
                ],
                onChanged: (value) => setState(() => _monthDay = value),
              ),
            ],
          ),
        ),
        if (!byWeekday && _monthDay > 28)
          Padding(
            padding: const EdgeInsets.only(left: 30, bottom: 4),
            child: Text(
              '$_monthDay日が無い月は月末になります',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ),
        _buildChoiceRow(
          accent: accent,
          selected: byWeekday,
          onTap: () =>
              setState(() => _monthlyMode = MonthlyMode.nthWeekday),
          child: Row(
            children: [
              const Text('曜日で指定', style: TextStyle(fontSize: 14)),
              const Spacer(),
              _buildDropdown<int>(
                value: _weekOrdinal,
                enabled: byWeekday,
                items: [
                  for (var ordinal = 1; ordinal <= 5; ordinal++)
                    DropdownMenuItem(
                      value: ordinal,
                      child: Text('第$ordinal'),
                    ),
                  const DropdownMenuItem(
                    value: lastWeekdayOrdinal,
                    child: Text('最終'),
                  ),
                ],
                onChanged: (value) => setState(() => _weekOrdinal = value),
              ),
              const SizedBox(width: 6),
              _buildDropdown<int>(
                value: _monthWeekday,
                enabled: byWeekday,
                items: [
                  for (var weekday = 1; weekday <= 7; weekday++)
                    DropdownMenuItem(
                      value: weekday,
                      child: Text('${weekdayNames[weekday - 1]}曜日'),
                    ),
                ],
                onChanged: (value) => setState(() => _monthWeekday = value),
              ),
            ],
          ),
        ),
        if (byWeekday && _weekOrdinal == 5)
          Padding(
            padding: const EdgeInsets.only(left: 30),
            child: Text(
              '第5週が無い月は、その月で最後の同じ曜日になります',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ),
      ],
    );
  }

  Widget _buildEndOptions(Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildChoiceRow(
          accent: accent,
          selected: _end == RecurrenceEnd.never,
          onTap: () => setState(() => _end = RecurrenceEnd.never),
          child: const Text('なし（ずっと繰り返す）',
              style: TextStyle(fontSize: 14)),
        ),
        _buildChoiceRow(
          accent: accent,
          selected: _end == RecurrenceEnd.until,
          onTap: () => setState(() => _end = RecurrenceEnd.until),
          child: Row(
            children: [
              const Text('日付', style: TextStyle(fontSize: 14)),
              const Spacer(),
              TextButton(
                onPressed: _end == RecurrenceEnd.until ? _pickUntil : null,
                child: Text(
                  '${DateFormat('yyyy/M/d').format(_until)} まで',
                  style: TextStyle(
                    fontSize: 14,
                    color: _end == RecurrenceEnd.until
                        ? accent
                        : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        _buildChoiceRow(
          accent: accent,
          selected: _end == RecurrenceEnd.count,
          onTap: () => setState(() => _end = RecurrenceEnd.count),
          child: Row(
            children: [
              const Text('回数', style: TextStyle(fontSize: 14)),
              const Spacer(),
              _buildDropdown<int>(
                value: _count,
                enabled: _end == RecurrenceEnd.count,
                items: [
                  for (var count = 1; count <= _maxCount; count++)
                    DropdownMenuItem(value: count, child: Text('$count回')),
                ],
                onChanged: (value) => setState(() => _count = value),
              ),
            ],
          ),
        ),
        if (_end == RecurrenceEnd.count)
          Padding(
            padding: const EdgeInsets.only(left: 30),
            child: Text(
              '今の期限を1回目として数えます',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ),
      ],
    );
  }

  Future<void> _pickUntil() async {
    final base = _base;
    // 終了日は期限より前にできない（1回も繰り返さない設定を防ぐ）
    final firstDate = DateTime(base.year, base.month, base.day);
    var initialDate = _until;
    if (initialDate.isBefore(firstDate)) initialDate = firstDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime(base.year + 10, base.month, base.day),
      locale: const Locale('ja'),
    );
    if (picked == null || !mounted) return;
    setState(() {
      // その日いっぱいを含めるため、終了日は 23:59 として扱う
      _until = DateTime(picked.year, picked.month, picked.day, 23, 59);
    });
  }

  // ラジオボタン風の選択行（Radio ウィジェットを使わず見た目を揃える）
  Widget _buildChoiceRow({
    required Color accent,
    required bool selected,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 20,
              color: selected ? accent : Colors.grey.shade500,
            ),
            const SizedBox(width: 10),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T> onChanged,
    bool enabled = true,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5FA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<T>(
        value: value,
        items: items,
        onChanged: enabled
            ? (selected) {
                if (selected != null) onChanged(selected);
              }
            : null,
        underline: const SizedBox.shrink(),
        isDense: true,
        style: const TextStyle(fontSize: 14, color: Colors.black87),
      ),
    );
  }
}
