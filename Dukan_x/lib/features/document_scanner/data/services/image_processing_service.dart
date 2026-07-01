import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import '../../domain/models/scanned_page.dart';

// Run heavy image tasks in isolate
Future<Uint8List> computeApplyFilter(Map<String, dynamic> args) async {
  final bytes = args['bytes'] as Uint8List;
  final filter = args['filter'] as PageFilter;

  img.Image? image = img.decodeImage(bytes);
  if (image == null) return bytes;

  switch (filter) {
    case PageFilter.grayScale:
      image = img.grayscale(image);
      break;
    case PageFilter.blackAndWhite:
      image = img.grayscale(image);
      // High contrast thresholding (simple binary)
      // For better B&W, we might need a custom kernel or threshold
      // brightness < 128 ? 0 : 255
      for (var pixel in image) {
        // Simple luminance check
        if (pixel.luminance < 128) {
          pixel.r = 0;
          pixel.g = 0;
          pixel.b = 0;
        } else {
          pixel.r = 255;
          pixel.g = 255;
          pixel.b = 255;
        }
      }
      break;
    case PageFilter.magicColor:
      // Simple saturation boost + normalize
      // Note: 'image' package contrast/saturation might be limited in free versions or require specific ops
      image = img.adjustColor(image, saturation: 1.5, brightness: 1.1);
      break;
    case PageFilter.original:
      break;
  }
  return Uint8List.fromList(img.encodeJpg(image));
}

class ImageProcessingService {
  Future<String> applyFilter(String imagePath, PageFilter filter) async {
    try {
      if (filter == PageFilter.original) return imagePath;

      final File originalFile = File(imagePath);
      final bytes = await originalFile.readAsBytes();

      final processedBytes = await compute(computeApplyFilter, {
        'bytes': bytes,
        'filter': filter,
      });

      final tempDir = await getTemporaryDirectory();
      final fileName = 'processed_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final processedFile = File('${tempDir.path}/$fileName');
      await processedFile.writeAsBytes(processedBytes);

      return processedFile.path;
    } catch (e) {
      throw Exception('Failed to apply filter: $e');
    }
  }

  // Placeholder for perspective crop - requires 'image' package mostly
  // Real perspective transform is complex on pure Dart.
  // We might use a plugin or simple crop for now.
  Future<String> cropImage(String imagePath, List<double> corners) async {
    // For MVP: Simple Rect Crop based on bounding box of corners
    // Real perspective correction would optimally use OpenCV or native plugin
    return imagePath;
  }
}
