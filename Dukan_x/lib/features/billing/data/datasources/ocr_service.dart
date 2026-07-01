import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
// import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart'; // Kept as reference if needed

class OcrService {
  final TextRecognizer _recognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  ); // Or .devanagari if needed for Indian langs

  Future<String> scanImage(String imagePath) async {
    // On-device ML Kit is not available on web. Fail honestly with a typed
    // exception so callers can show an empty/unsupported state — never a
    // fabricated bill string (data-integrity rule: no mock values).
    if (kIsWeb) {
      throw OcrUnsupportedException(
        'On-device OCR is not supported on web. Scan from a native (mobile/desktop) client.',
      );
    } else {
      try {
        debugPrint("Starting Google ML Kit OCR on: $imagePath");
        final inputImage = InputImage.fromFilePath(imagePath);
        final recognizedText = await _recognizer.processImage(inputImage);

        final text = recognizedText.text;
        debugPrint(
          "ML Kit Result: ${text.substring(0, text.length > 100 ? 100 : text.length)}...",
        );
        return text;
      } catch (e) {
        debugPrint("ML Kit Error: $e");
        return "Failed to scan image.";
      }
    }
  }

  Future<void> dispose() async {
    await _recognizer.close();
  }
}

/// Thrown when on-device OCR cannot run (e.g. on web, where ML Kit is
/// unavailable). Callers should surface an unsupported/empty state rather
/// than a fabricated bill string.
class OcrUnsupportedException implements Exception {
  final String message;
  OcrUnsupportedException(this.message);

  @override
  String toString() => 'OcrUnsupportedException: $message';
}
