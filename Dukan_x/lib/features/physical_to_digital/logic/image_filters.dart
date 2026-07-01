// Image Filters
//
// GPU-optimized image filters for document enhancement.
// Each filter is a color matrix transformation.

import 'dart:typed_data';
import 'package:image/image.dart' as img;

enum ImageFilter { reality, digitalClean, ultraBW, receiptBoost, sharpPro }

class ImageFilters {
  /// Apply filter to image bytes
  static Future<Uint8List?> apply(
    Uint8List imageBytes,
    ImageFilter filter,
  ) async {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) return null;

      img.Image processed;

      switch (filter) {
        case ImageFilter.reality:
          processed = image; // No processing
          break;

        case ImageFilter.digitalClean:
          processed = _applyDigitalClean(image);
          break;

        case ImageFilter.ultraBW:
          processed = _applyUltraBW(image);
          break;

        case ImageFilter.receiptBoost:
          processed = _applyReceiptBoost(image);
          break;

        case ImageFilter.sharpPro:
          processed = _applySharpPro(image);
          break;
      }

      return Uint8List.fromList(img.encodeJpg(processed, quality: 95));
    } catch (e) {
      return null;
    }
  }

  /// Digital Clean: Slightly enhanced contrast, clean white background
  static img.Image _applyDigitalClean(img.Image src) {
    // Increase contrast and brightness
    var result = img.adjustColor(src, contrast: 1.2, brightness: 1.05);

    // Slight sharpening
    result = img.convolution(
      result,
      filter: [0, -0.5, 0, -0.5, 3, -0.5, 0, -0.5, 0],
    );

    return result;
  }

  /// Ultra B/W: High contrast black and white
  static img.Image _applyUltraBW(img.Image src) {
    // Convert to grayscale
    var result = img.grayscale(src);

    // High contrast
    result = img.adjustColor(result, contrast: 1.5);

    // Apply threshold for pure B/W look
    for (int y = 0; y < result.height; y++) {
      for (int x = 0; x < result.width; x++) {
        final pixel = result.getPixel(x, y);
        final luminance = img.getLuminance(pixel);
        final newValue = luminance > 140 ? 255 : 0;
        result.setPixel(
          x,
          y,
          img.ColorRgba8(newValue, newValue, newValue, 255),
        );
      }
    }

    return result;
  }

  /// Receipt Boost: Optimized for thermal paper receipts
  static img.Image _applyReceiptBoost(img.Image src) {
    // Increase contrast significantly
    var result = img.adjustColor(src, contrast: 1.4, brightness: 1.1);

    // Convert to grayscale for better text readability
    result = img.grayscale(result);

    // Sharpen
    result = img.convolution(result, filter: [0, -1, 0, -1, 5, -1, 0, -1, 0]);

    return result;
  }

  /// Sharp Pro: Maximum sharpness with balanced colors
  static img.Image _applySharpPro(img.Image src) {
    // Strong sharpening
    var result = img.convolution(
      src,
      filter: [-1, -1, -1, -1, 9, -1, -1, -1, -1],
    );

    // Slight contrast boost
    result = img.adjustColor(result, contrast: 1.15);

    return result;
  }
}
