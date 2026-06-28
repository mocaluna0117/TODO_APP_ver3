part of '../../../main.dart';

extension _TodoHomeLinksField on _TodoHomePageState {
  // 複数のリンクを入力できるフィールド。各行に入力欄と削除ボタン、
  // 末尾に「リンクを追加」ボタンを表示する。
  Widget _buildLinksField({
    required List<TextEditingController> controllers,
    required VoidCallback onAdd,
    required ValueChanged<int> onRemove,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < controllers.length; i++)
            Padding(
              key: ObjectKey(controllers[i]),
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(Icons.link, size: 18, color: s.primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: controllers[i],
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.done,
                      hintLocales: const [Locale('ja', 'JP')],
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: 'https://...',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 18, color: Colors.grey.shade500),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'このリンクを削除',
                    onPressed: () => onRemove(i),
                  ),
                ],
              ),
            ),
          InkWell(
            onTap: onAdd,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Row(
                children: [
                  Icon(Icons.add, size: 20, color: s.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    controllers.isEmpty ? 'リンクを添付（任意）' : 'リンクを追加',
                    style: TextStyle(
                      fontSize: 15,
                      color: controllers.isEmpty ? Colors.grey : s.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
