// Perspective Transformer
//
// Transforms a quadrilateral document region into a flat rectangle.
// Uses basic matrix transformations.

import 'dart:typed_data';
import 'dart:ui';
import 'package:image/image.dart' as img;

class PerspectiveTransformer {
  /// Transform an image given 4 source corners to a flat rectangle
  ///
  /// [imageBytes] - Raw image bytes
  /// [corners] - 4 corner points (normalized 0-1 or absolute pixels)
  /// [outputWidth] - Desired output width
  /// [outputHeight] - Desired output height
  static Future<Uint8List?> transform({
    required Uint8List imageBytes,
    required List<Offset> corners,
    int outputWidth = 1000,
    int? outputHeight,
  }) async {
    try {
      final srcImage = img.decodeImage(imageBytes);
      if (srcImage == null) return null;

      // Denormalize corners if they are in 0-1 range
      final denormalizedCorners = corners.map((c) {
        if (c.dx <= 1 && c.dy <= 1) {
          return Offset(c.dx * srcImage.width, c.dy * srcImage.height);
        }
        return c;
      }).toList();

      // Calculate aspect ratio from source quadrilateral
      final topWidth =
          (denormalizedCorners[1] - denormalizedCorners[0]).distance;
      final bottomWidth =
          (denormalizedCorners[2] - denormalizedCorners[3]).distance;
      final leftHeight =
          (denormalizedCorners[3] - denormalizedCorners[0]).distance;
      final rightHeight =
          (denormalizedCorners[2] - denormalizedCorners[1]).distance;

      final avgWidth = (topWidth + bottomWidth) / 2;
      final avgHeight = (leftHeight + rightHeight) / 2;
      final aspectRatio = avgWidth / avgHeight;

      final destWidth = outputWidth;
      final destHeight = outputHeight ?? (outputWidth / aspectRatio).round();

      // Create output image
      final destImage = img.Image(width: destWidth, height: destHeight);

      // Basic perspective mapping (simplified)
      for (int y = 0; y < destHeight; y++) {
        for (int x = 0; x < destWidth; x++) {
          final u = x / destWidth;
          final v = y / destHeight;

          // Bilinear interpolation of source position
          final top = _lerp(denormalizedCorners[0], denormalizedCorners[1], u);
          final bottom = _lerp(
            denormalizedCorners[3],
            denormalizedCorners[2],
            u,
          );
          final srcPoint = _lerp(top, bottom, v);

          final srcX = srcPoint.dx.round().clamp(0, srcImage.width - 1);
          final srcY = srcPoint.dy.round().clamp(0, srcImage.height - 1);

          final pixel = srcImage.getPixel(srcX, srcY);
          destImage.setPixel(x, y, pixel);
        }
      }

      return Uint8List.fromList(img.encodeJpg(destImage, quality: 95));
    } catch (e) {
      return null;
    }
  }

  static Offset _lerp(Offset a, Offset b, double t) {
    return Offset(a.dx + (b.dx - a.dx) * t, a.dy + (b.dy - a.dy) * t);
  }

  /// Auto-detect document corners using edge detection
  /// Returns 4 corners or null if detection fails
  static List<Offset>? autoDetectCorners(img.Image image) {
    // Simplified: return image corners
    // In production, use Canny edge detection + Hough transform
    return [
      const Offset(0.05, 0.05),
      Offset(0.95, 0.05),
      Offset(0.95, 0.95),
      const Offset(0.05, 0.95),
    ];
  }
}
