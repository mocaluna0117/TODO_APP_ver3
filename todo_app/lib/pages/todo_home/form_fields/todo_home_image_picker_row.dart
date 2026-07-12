part of '../../../main.dart';

extension _TodoHomeImagePickerRow on _TodoHomePageState {
  Widget _buildImagePickerRow({
    required List<String> imageBase64List,
    required ValueChanged<List<String>> onImagesChanged,
  }) {
    return InkWell(
      onTap: () async {
        try {
          final pickedImageBase64List = await _pickImageBase64List();
          if (pickedImageBase64List.isNotEmpty) {
            onImagesChanged([...imageBase64List, ...pickedImageBase64List]);
          }
        } catch (_) {
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('画像を選択できませんでした')));
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5FA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (imageBase64List.isNotEmpty) ...[
              SizedBox(
                height: 320,
                child: PageView.builder(
                  itemCount: imageBase64List.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: GestureDetector(
                            onTap: () => _showImagePreview(
                              imageBase64List,
                              initialIndex: index,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: _buildImage(
                                imageBase64List[index],
                                width: double.infinity,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints.tightFor(
                                width: 34,
                                height: 34,
                              ),
                              padding: EdgeInsets.zero,
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 18,
                              ),
                              tooltip: 'この画像を削除',
                              onPressed: () {
                                final nextImages = [...imageBase64List]
                                  ..removeAt(index);
                                onImagesChanged(nextImages);
                              },
                            ),
                          ),
                        ),
                        if (imageBase64List.length > 1)
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
                                '${index + 1}/${imageBase64List.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Icon(Icons.image_outlined, size: 20, color: s.primaryColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    imageBase64List.isNotEmpty
                        ? '画像を追加（${imageBase64List.length}枚）'
                        : '画像を添付（任意）',
                    style: TextStyle(
                      fontSize: 15,
                      color: imageBase64List.isNotEmpty
                          ? Colors.black87
                          : Colors.grey,
                    ),
                  ),
                ),
                if (imageBase64List.isNotEmpty)
                  GestureDetector(
                    onTap: () => onImagesChanged([]),
                    child: Icon(
                      Icons.close,
                      size: 18,
                      color: Colors.grey.shade400,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
