part of '../../../main.dart';

// 添付できるPDF1件あたりの上限サイズ。
// 選択時にいったんメモリへ読み込むため、無制限にはしない。
const int kMaxAttachmentBytes = 20 * 1024 * 1024;

extension _TodoHomeFilePickerRow on _TodoHomePageState {
  // PDFの添付行。
  // [attachments] はアップロード済み、[pendingFiles] は保存時に送るぶん。
  Widget _buildFilePickerRow({
    required List<TaskFile> attachments,
    required List<PendingTaskFile> pendingFiles,
    required ValueChanged<List<TaskFile>> onAttachmentsChanged,
    required ValueChanged<List<PendingTaskFile>> onPendingFilesChanged,
  }) {
    final total = attachments.length + pendingFiles.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: s.fieldColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < attachments.length; i++)
            _buildAttachedFileRow(
              name: attachments[i].name,
              // 保存済みのファイルはタップで開ける
              onOpen: () => _openLink(attachments[i].url),
              onRemove: () {
                final next = [...attachments]..removeAt(i);
                onAttachmentsChanged(next);
              },
            ),
          for (var i = 0; i < pendingFiles.length; i++)
            _buildAttachedFileRow(
              name: pendingFiles[i].name,
              // まだアップロードしていないので開けない
              pendingLabel: '保存するとアップロードされます',
              onRemove: () {
                final next = [...pendingFiles]..removeAt(i);
                onPendingFilesChanged(next);
              },
            ),
          InkWell(
            onTap: () => _pickAttachmentFiles(
              pendingFiles: pendingFiles,
              onPendingFilesChanged: onPendingFilesChanged,
            ),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.picture_as_pdf_outlined,
                    size: 20,
                    color: s.primaryColor,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      total > 0 ? 'PDFを追加（$total件）' : 'PDFを添付（任意）',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        color: total > 0 ? s.primaryTextColor : Colors.grey,
                      ),
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

  Widget _buildAttachedFileRow({
    required String name,
    required VoidCallback onRemove,
    VoidCallback? onOpen,
    String? pendingLabel,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            Icons.picture_as_pdf,
            size: 18,
            color: onOpen == null ? Colors.grey : s.primaryColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: onOpen,
              borderRadius: BorderRadius.circular(4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: onOpen == null ? Colors.grey : s.primaryColor,
                      decoration: onOpen == null
                          ? null
                          : TextDecoration.underline,
                      decorationColor: s.primaryColor,
                    ),
                  ),
                  if (pendingLabel != null)
                    Text(
                      pendingLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: s.secondaryTextColor,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close, size: 18, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAttachmentFiles({
    required List<PendingTaskFile> pendingFiles,
    required ValueChanged<List<PendingTaskFile>> onPendingFilesChanged,
  }) async {
    // 他のファイル選択と同時に開くと PlatformException(multiple_request) になる
    if (_isPickingBackup) return;
    _isPickingBackup = true;
    final FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
        withData: true,
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to pick attachment: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ファイルを選択できませんでした')));
      return;
    } finally {
      _isPickingBackup = false;
    }
    if (picked == null || picked.files.isEmpty) return;

    final added = <PendingTaskFile>[];
    var hasTooLarge = false;
    for (final file in picked.files) {
      final bytes = file.bytes;
      if (bytes == null) continue;
      if (bytes.length > kMaxAttachmentBytes) {
        hasTooLarge = true;
        continue;
      }
      added.add(PendingTaskFile(name: file.name, bytes: bytes));
    }

    if (added.isNotEmpty) {
      onPendingFilesChanged([...pendingFiles, ...added]);
    }
    if (!mounted) return;
    if (hasTooLarge) {
      final limitMb = kMaxAttachmentBytes ~/ (1024 * 1024);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${limitMb}MBを超えるファイルは添付できません')),
      );
    } else if (added.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ファイルを読み込めませんでした')));
    }
  }
}
