part of '../../../main.dart';

extension _TodoHomeMedia on _TodoHomePageState {
  Future<List<String>> _pickImageBase64List() async {
    final pickedImages = await _imagePicker.pickMultiImage(
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (pickedImages.isEmpty) return [];

    final encodedImages = <String>[];
    for (final pickedImage in pickedImages) {
      final bytes = await pickedImage.readAsBytes();
      encodedImages.add(base64Encode(bytes));
    }
    return encodedImages;
  }

  Uint8List? _decodeImage(String? imageBase64) {
    if (imageBase64 == null || imageBase64.isEmpty) return null;
    try {
      return base64Decode(imageBase64);
    } on FormatException {
      return null;
    }
  }

  List<Uint8List> _decodeImages(List<String> imageBase64List) {
    return imageBase64List
        .map(_decodeImage)
        .whereType<Uint8List>()
        .toList(growable: false);
  }

  void _showImagePreview(
    List<Uint8List> imageBytesList, {
    int initialIndex = 0,
  }) {
    if (imageBytesList.isEmpty) return;
    final pageController = PageController(initialPage: initialIndex);
    var currentIndex = initialIndex;

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => StatefulBuilder(
        builder: (context, setPreviewState) {
          return Dialog.fullscreen(
            backgroundColor: Colors.black,
            child: SafeArea(
              child: Dismissible(
                key: const ValueKey('image-preview'),
                direction: DismissDirection.vertical,
                onDismissed: (_) => Navigator.pop(context),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.pop(context),
                        child: PageView.builder(
                          controller: pageController,
                          itemCount: imageBytesList.length,
                          onPageChanged: (index) {
                            currentIndex = index;
                            setPreviewState(() {});
                          },
                          itemBuilder: (context, index) {
                            final imageBytes = imageBytesList[index];
                            return Center(
                              child: InteractiveViewer(
                                minScale: 0.8,
                                maxScale: 4,
                                child: GestureDetector(
                                  onTap: () {},
                                  child: Image.memory(
                                    imageBytes,
                                    fit: BoxFit.contain,
                                    width: double.infinity,
                                    height: double.infinity,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    if (imageBytesList.length > 1)
                      Positioned(
                        top: 16,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Text(
                              '${currentIndex + 1}/${imageBytesList.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          tooltip: '閉じる',
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 20,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: s.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                            side: const BorderSide(color: Colors.white24),
                          ),
                          elevation: 4,
                        ),
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.keyboard_arrow_down),
                        label: const Text('閉じる'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
