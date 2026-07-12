part of '../../../main.dart';

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
}
