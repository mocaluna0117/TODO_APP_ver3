part of '../../../main.dart';

// 繰り返し選択メニューのアクション用センチネル（プリセットは 0 以上の添字）
const int _recurrenceNoneAction = -1;
const int _recurrenceCustomAction = -2;

extension _TodoHomeSelectFields on _TodoHomePageState {
  Widget _buildTaskTagPicker({
    required String category,
    required String? selectedTaskTag,
    required ValueChanged<String?> onChanged,
  }) {
    // 選択肢を組み立てる。設定が未同期などで現在のタグが一覧に無い場合も
    // 選択肢に含める（DropdownButtonFormField の「該当1件」assert を回避）。
    final tags = <String>[noTaskTagLabel, ...s.tagsForCategory(category)];
    if (selectedTaskTag != null && !tags.contains(selectedTaskTag)) {
      tags.add(selectedTaskTag);
    }

    return DropdownButtonFormField<String>(
      initialValue: selectedTaskTag ?? noTaskTagLabel,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'タグ',
        prefixIcon: Icon(Icons.label_outline, color: s.primaryColor),
        filled: true,
        fillColor: s.fieldColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      items: tags
          .map((tag) => DropdownMenuItem(value: tag, child: Text(tag)))
          .toList(),
      onChanged: (tag) {
        if (tag != null) {
          onChanged(tag == noTaskTagLabel ? null : tag);
        }
      },
    );
  }

  // 繰り返しの選択行。プリセットから選ぶか「カスタム...」で詳細シートを開く。
  // 曜日・第n週・日は期限の日付から補うため [dueDate] を受け取る。
  Widget _buildRecurrencePicker({
    required Recurrence? selectedRecurrence,
    required DateTime? dueDate,
    required ValueChanged<Recurrence?> onChanged,
  }) {
    final presets = recurrencePresets(dueDate);
    final selected = selectedRecurrence;
    // 現在の設定がプリセットのどれかと一致するか（一致しなければカスタム扱い）
    final matchedIndex = selected == null
        ? -1
        : presets.indexWhere((preset) => preset.hasSameConfig(selected));
    final isCustom = selected != null && matchedIndex < 0;

    return PopupMenuButton<int>(
      tooltip: '繰り返しを選択',
      position: PopupMenuPosition.under,
      constraints: const BoxConstraints(minWidth: 260),
      onSelected: (value) async {
        if (value == _recurrenceNoneAction) {
          onChanged(null);
          return;
        }
        if (value == _recurrenceCustomAction) {
          final result = await showRecurrenceSheet(
            context,
            initial: selected,
            dueDate: dueDate,
            accentColor: s.primaryColor,
          );
          // キャンセル時（null）は今の設定を保つ
          if (result != null) onChanged(result);
          return;
        }
        onChanged(presets[value]);
      },
      itemBuilder: (context) => [
        _buildRecurrenceMenuItem(
          value: _recurrenceNoneAction,
          label: 'なし',
          isSelected: selected == null,
        ),
        for (var i = 0; i < presets.length; i++)
          _buildRecurrenceMenuItem(
            value: i,
            label: recurrenceLabel(presets[i], dueDate),
            isSelected: i == matchedIndex,
          ),
        const PopupMenuDivider(),
        _buildRecurrenceMenuItem(
          value: _recurrenceCustomAction,
          // カスタム設定中はその内容も添えて、何が選ばれているか分かるようにする
          label: isCustom
              ? 'カスタム...（${recurrenceLabel(selected, dueDate)}）'
              : 'カスタム...',
          isSelected: isCustom,
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: s.fieldColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.repeat, size: 18, color: s.primaryColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                selected == null
                    ? '繰り返しを設定（任意）'
                    : recurrenceLabel(selected, dueDate),
                style: TextStyle(
                  fontSize: 15,
                  color: selected == null ? Colors.grey : s.primaryTextColor,
                ),
              ),
            ),
            Icon(Icons.unfold_more, size: 20, color: s.secondaryTextColor),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<int> _buildRecurrenceMenuItem({
    required int value,
    required String label,
    required bool isSelected,
  }) {
    return PopupMenuItem<int>(
      value: value,
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: isSelected
                ? Icon(Icons.check, size: 18, color: s.primaryColor)
                : null,
          ),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}
