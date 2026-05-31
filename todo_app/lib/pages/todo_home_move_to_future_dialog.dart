part of '../main.dart';

extension _TodoHomeMoveToFutureDialog on _TodoHomePageState {
  void _showMoveToFutureDialog(TodoItem item) {
    final textController = TextEditingController(text: item.title);
    final descriptionController = TextEditingController(
      text: item.description ?? '',
    );
    var selectedTaskPriority = item.priority;

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 16,
                  right: 16,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.85,
                    ),
                    child: Container(
                      padding: const EdgeInsets.only(
                        left: 24,
                        right: 24,
                        top: 24,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '「${s.futureTabName}」に移動',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: s.primaryColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: textController,
                              autofocus: true,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                hintText: 'タスクを入力...',
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
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: descriptionController,
                              textInputAction: TextInputAction.done,
                              minLines: 1,
                              maxLines: 4,
                              decoration: InputDecoration(
                                hintText: '概要を入力（任意）',
                                filled: true,
                                fillColor: const Color(0xFFF5F5FA),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.all(16),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildTaskPriorityPicker(
                              selectedTaskPriority: selectedTaskPriority,
                              onChanged: (p) =>
                                  setSheetState(() => selectedTaskPriority = p),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () {
                                final trimmed = textController.text.trim();
                                if (trimmed.isEmpty) return;
                                _updateState(() {
                                  item.title = trimmed;
                                  item.description = _normalizeOptionalText(
                                    descriptionController.text,
                                  );
                                  item.category = 'future';
                                  item.priority = selectedTaskPriority;
                                });
                                _saveData();
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: s.primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                '「${s.futureTabName}」に移動',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
