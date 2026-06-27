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
      ),
    );
  }

  Widget _buildEditDialogLinkField(_EditTodoDraft draft) {
    return TextField(
      controller: draft.linkController,
      keyboardType: TextInputType.url,
      textInputAction: TextInputAction.done,
      hintLocales: const [Locale('ja', 'JP')],
      decoration: _editDialogTextFieldDecoration('リンク（任意）').copyWith(
        prefixIcon: Icon(Icons.link, color: s.primaryColor),
      ),
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
