part of '../../../../main.dart';

extension _TodoHomeTaskTagActionsSheet on _TodoHomePageState {
  void _showTaskTagActions(String tag) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        // 白い背景を外側に置き、セーフエリア分の下部まできちんと白くする
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.edit, color: s.primaryColor),
                  title: const Text('タグ名を変更'),
                  subtitle: Text(tag),
                  onTap: () {
                    Navigator.pop(context);
                    _showRenameTaskTagDialog(tag);
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: Colors.red.shade300,
                  ),
                  title: const Text('タグを削除'),
                  subtitle: const Text('このタグが付いたタスクはタグなしになります'),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDeleteTaskTagFromHome(tag);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
