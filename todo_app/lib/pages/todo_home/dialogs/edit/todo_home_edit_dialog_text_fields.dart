part of '../../../../main.dart';

extension _TodoHomeEditDialogTextFields on _TodoHomePageState {
  Widget _buildEditDialogTitleField(_EditTodoDraft draft) {
    return TextField(
      controller: draft.textController,
      autofocus: true,
      textInputAction: TextInputAction.next,
      decoration: _editDialogTextFieldDecoration('タスクを入力...'),
    );
  }

  Widget _buildEditDialogDescriptionField(_EditTodoDraft draft) {
    return TextField(
      controller: draft.descriptionController,
      keyboardType: TextInputType.multiline,
      // 改行キーは改行の挿入にする（submitしてモーダルを閉じない）
      textInputAction: TextInputAction.newline,
      minLines: 1,
      maxLines: 4,
      decoration: _editDialogTextFieldDecoration(
        '概要を入力（任意）',
        contentPadding: const EdgeInsets.all(16),
      ).copyWith(suffixIcon: _descriptionCopyButton(draft.descriptionController)),
    );
  }

  // 概要をワンタップでコピーするボタン（ドラッグ選択せずにコピーできる）
  Widget _descriptionCopyButton(TextEditingController controller) {
    return IconButton(
      icon: const Icon(Icons.copy_rounded, size: 18),
      color: s.primaryColor,
      tooltip: '概要をコピー',
      visualDensity: VisualDensity.compact,
      onPressed: () => _copyToClipboard(controller.text, '概要'),
    );
  }

  InputDecoration _editDialogTextFieldDecoration(
    String hintText, {
    EdgeInsetsGeometry contentPadding = const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 14,
    ),
  }) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: const Color(0xFFF5F5FA),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: contentPadding,
    );
  }
}
