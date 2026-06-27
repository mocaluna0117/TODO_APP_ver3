part of '../../../main.dart';

extension _TodoHomeTodoSubtitle on _TodoHomePageState {
  Widget? _buildTodoSubtitle(TodoItem item) {
    final imageBytesList = _decodeImages(item.imageBase64List);
    final description = item.description;
    final hasTaskPriority =
        item.category == 'future' && item.priority != TaskPriority.none;
    if (item.taskTag == null &&
        !item.isRecurring &&
        !hasTaskPriority &&
        description == null &&
        item.link == null &&
        item.dueDate == null &&
        imageBytesList.isEmpty) {
      return null;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.taskTag != null || item.isRecurring || hasTaskPriority)
            _buildTaskLabels(item, hasTaskPriority: hasTaskPriority),
          if ((item.taskTag != null || item.isRecurring || hasTaskPriority) &&
              (description != null ||
                  item.dueDate != null ||
                  imageBytesList.isNotEmpty))
            const SizedBox(height: 8),
          if (description != null)
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: item.isDone ? Colors.grey.shade500 : Colors.black54,
              ),
            ),
          if (description != null &&
              (item.dueDate != null || imageBytesList.isNotEmpty))
            const SizedBox(height: 8),
          if (item.dueDate != null)
            Text(
              _formatTodoCardDueDate(item.dueDate!),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: TextStyle(
                fontSize: 12,
                color: item.isOverdue ? Colors.red : Colors.grey.shade700,
                fontWeight: item.isOverdue
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          if (item.link != null) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _openLink(item.link!),
              borderRadius: BorderRadius.circular(4),
              child: Row(
                children: [
                  Icon(Icons.link, size: 14, color: s.primaryColor),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      item.link!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: TextStyle(
                        fontSize: 12,
                        color: s.primaryColor,
                        decoration: TextDecoration.underline,
                        decorationColor: s.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (imageBytesList.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              child: PageView.builder(
                itemCount: imageBytesList.length,
                itemBuilder: (context, index) {
                  final imageBytes = imageBytesList[index];
                  return GestureDetector(
                    onTap: () =>
                        _showImagePreview(imageBytesList, initialIndex: index),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Container(
                              color: const Color(0xFFF5F5FA),
                              child: Image.memory(
                                imageBytes,
                                fit: BoxFit.contain,
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
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  // タスクのリンクを外部ブラウザで開く。スキームが無ければ https:// を補う。
  Future<void> _openLink(String rawUrl) async {
    var url = rawUrl.trim();
    if (url.isEmpty) return;
    if (!url.contains('://')) {
      url = 'https://$url';
    }
    final uri = Uri.tryParse(url);
    var opened = false;
    if (uri != null) {
      try {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        opened = false;
      }
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('リンクを開けませんでした: $rawUrl')));
    }
  }
}
