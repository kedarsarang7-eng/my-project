import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class GalleryImportView extends StatelessWidget {
  final Function(List<XFile>) onImagesImported;

  const GalleryImportView({super.key, required this.onImagesImported});

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();
    if (images.isNotEmpty) {
      onImagesImported(images);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.photo_library_outlined,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            "Import from Gallery",
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _pickImages(),
            icon: const Icon(Icons.add_photo_alternate),
            label: const Text("Select Photos"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
