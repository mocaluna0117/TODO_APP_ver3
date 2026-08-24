part of '../../../main.dart';

extension _TodoHomeTodoSubtitle on _TodoHomePageState {
  Widget? _buildTodoSubtitle(TodoItem item) {
    final images = _validImageEntries(item.imageBase64List);
    final description = item.description;
    final hasTaskPriority =
        item.category == 'future' && item.priority != TaskPriority.none;
    if (item.taskTag == null &&
        !item.isRecurring &&
        !hasTaskPriority &&
        description == null &&
        item.links.isEmpty &&
        item.dueDate == null &&
        item.attachments.isEmpty &&
        images.isEmpty) {
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
                  images.isNotEmpty))
            const SizedBox(height: 8),
          if (description != null) _buildCardDescription(item, description),
          if (description != null &&
              (item.dueDate != null || images.isNotEmpty))
            const SizedBox(height: 8),
          if (item.dueDate != null)
            Text(
              _formatTodoCardDueDate(item.dueDate!),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: TextStyle(
                fontSize: 12,
                color: item.isOverdue ? Colors.red : s.secondaryTextColor,
                fontWeight: item.isOverdue
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          for (final link in item.links) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _openLink(link),
              borderRadius: BorderRadius.circular(4),
              child: Row(
                children: [
                  Icon(Icons.link, size: 14, color: s.primaryColor),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      link,
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
          // 添付したPDF（タップで開く）
          for (final file in item.attachments) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _openLink(file.url),
              borderRadius: BorderRadius.circular(4),
              child: Row(
                children: [
                  Icon(
                    Icons.picture_as_pdf,
                    size: 14,
                    color: item.isDone ? Colors.grey.shade500 : s.primaryColor,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      file.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: TextStyle(
                        fontSize: 12,
                        color: item.isDone
                            ? Colors.grey.shade500
                            : s.primaryColor,
                        decoration: TextDecoration.underline,
                        decorationColor: s.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (images.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              child: PageView.builder(
                itemCount: images.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () =>
                        _showImagePreview(images, initialIndex: index),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Container(
                              color: s.fieldColor,
                              child: _buildImage(
                                images[index],
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          if (_uploadingImageItemIds.contains(item.id))
                            Positioned.fill(
                              child: _buildImageUploadingOverlay(),
                            ),
                          if (images.length > 1)
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
                                  '${index + 1}/${images.length}',
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

  // カードの概要は2行までなので、収まらない場合はホバー（長押し）で全文を出す。
  Widget _buildCardDescription(TodoItem item, String description) {
    final style = TextStyle(
      fontSize: 13,
      height: 1.4,
      color: item.isDone ? Colors.grey.shade500 : s.secondaryTextColor,
    );
    final text = Text(
      description,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: style,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // 2行に収まっているならツールチップは出さない（同じ内容の重複を避ける）
        final painter = TextPainter(
          text: TextSpan(text: description, style: style),
          maxLines: 2,
          textDirection: Directionality.of(context),
        )..layout(maxWidth: constraints.maxWidth);
        final isTruncated = painter.didExceedMaxLines;
        painter.dispose();
        if (!isTruncated) return text;
        return Tooltip(
          message: description,
          waitDuration: const Duration(milliseconds: 300),
          child: text,
        );
      },
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
