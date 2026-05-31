part of '../../../../main.dart';

extension _TodoHomeAddDialogTextFields on _TodoHomePageState {
  Widget _buildAddDialogTitleField(_AddTodoDraft draft) {
    return TextField(
      controller: draft.textController,
      autofocus: true,
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.next,
      hintLocales: const [Locale('ja', 'JP')],
      decoration: _addDialogTextFieldDecoration('タスクを入力...'),
    );
  }

  Widget _buildAddDialogDescriptionField(
    _AddTodoDraft draft,
    VoidCallback submit,
  ) {
    return TextField(
      controller: draft.descriptionController,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.done,
      hintLocales: const [Locale('ja', 'JP')],
      minLines: 1,
      maxLines: 4,
      onSubmitted: (_) => submit(),
      decoration: _addDialogTextFieldDecoration(
        '概要を入力（任意）',
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }

  InputDecoration _addDialogTextFieldDecoration(
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
