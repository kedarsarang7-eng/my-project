// ML Kit OCR Service
//
// Production-ready on-device text recognition service.
// Supports multiple scripts including Latin and Devanagari.
//
// Features:
// - Lazy initialization of recognizers
// - Multi-script support
// - Confidence scoring
// - Proper resource disposal

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../ml_models/ocr_result.dart';
import '../ml_models/scanned_item.dart';

/// Supported text recognition scripts
enum OcrScript {
  /// Latin script (English, etc.)
  latin,

  /// Devanagari script (Hindi, Marathi, etc.)
  devanagiri,
}

/// On-device OCR service using Google ML Kit
class MLKitOcrService {
  /// Lazy-initialized recognizers for each script
  final Map<OcrScript, TextRecognizer> _recognizers = {};

  /// Get or create recognizer for a script
  TextRecognizer _getRecognizer(OcrScript script) {
    if (!_recognizers.containsKey(script)) {
      final mlkitScript = switch (script) {
        OcrScript.latin => TextRecognitionScript.latin,
        OcrScript.devanagiri => TextRecognitionScript.devanagiri,
      };
      _recognizers[script] = TextRecognizer(script: mlkitScript);
      debugPrint('MLKitOcrService: Created recognizer for ${script.name}');
    }
    return _recognizers[script]!;
  }

  /// Recognize text from image file
  ///
  /// [imagePath] - Absolute path to image file
  /// [script] - Text script to recognize (defaults to Latin)
  ///
  /// Returns [OcrResult] with parsed items and confidence scores
  Future<OcrResult> recognizeText(
    String imagePath, {
    OcrScript script = OcrScript.latin,
  }) async {
    if (kIsWeb) {
      throw OcrUnsupportedException(
        'On-device OCR is not supported on web. Scan from a native (mobile/desktop) client.',
      );
    }

    try {
      debugPrint(
        'MLKitOcrService: Processing image with ${script.name} script',
      );
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizer = _getRecognizer(script);
      final recognizedText = await recognizer.processImage(inputImage);

      debugPrint(
        'MLKitOcrService: Found ${recognizedText.blocks.length} text blocks',
      );

      return _parseRecognizedText(recognizedText, script);
    } catch (e, stack) {
      debugPrint('MLKitOcrService Error: $e');
      debugPrint('Stack: $stack');
      return OcrResult.empty();
    }
  }

  /// Recognize text with automatic script detection
  ///
  /// Tries Latin first, then Devanagari if result is poor
  Future<OcrResult> recognizeTextAutoDetect(String imagePath) async {
    // Try Latin first (faster)
    final latinResult = await recognizeText(imagePath, script: OcrScript.latin);

    // If result is good, return it
    if (latinResult.items.isNotEmpty && latinResult.overallConfidence > 0.7) {
      return latinResult;
    }

    // Try Devanagari for potentially better results
    final devanagariResult = await recognizeText(
      imagePath,
      script: OcrScript.devanagiri,
    );

    // Return whichever has more items or better confidence
    if (devanagariResult.items.length > latinResult.items.length) {
      return devanagariResult;
    }
    if (devanagariResult.overallConfidence > latinResult.overallConfidence) {
      return devanagariResult;
    }

    return latinResult;
  }

  /// Parse ML Kit RecognizedText into structured OcrResult
  OcrResult _parseRecognizedText(RecognizedText text, OcrScript script) {
    // Collect all lines sorted by vertical position
    final allLines = <TextLine>[];
    for (final block in text.blocks) {
      allLines.addAll(block.lines);
    }
    allLines.sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));

    String shopName = '';
    DateTime? billDate;
    double totalAmount = 0.0;
    double gstAmount = 0.0;
    final List<ScannedItem> items = [];

    // Keywords for total detection
    const totalKeywords = [
      'total',
      'grand total',
      'payable',
      'amount',
      'net',
      'sum',
    ];
    const gstKeywords = ['gst', 'tax', 'cgst', 'sgst', 'igst', 'vat'];

    // 1. Extract shop name (first valid line)
    for (int i = 0; i < allLines.take(5).length; i++) {
      final lineText = allLines[i].text.trim();
      if (_isValidShopName(lineText)) {
        shopName = lineText;
        break;
      }
    }

    // 2. Extract date
    for (final line in allLines) {
      final date = _extractDate(line.text);
      if (date != null) {
        billDate = date;
        break;
      }
    }

    // 3. Extract GST/Tax
    for (final line in allLines) {
      final text = line.text.toLowerCase();
      if (gstKeywords.any((k) => text.contains(k))) {
        final numbers = _extractNumbers(line.text);
        if (numbers.isNotEmpty) {
          gstAmount = numbers.last;
        }
      }
    }

    // 4. Extract total (search from bottom)
    for (int i = allLines.length - 1; i >= 0; i--) {
      final text = allLines[i].text.toLowerCase();
      if (totalKeywords.any((k) => text.contains(k))) {
        final numbers = _extractNumbers(allLines[i].text);
        if (numbers.isNotEmpty) {
          totalAmount = numbers.last;
          break;
        }
      }
    }

    // 5. Extract items with confidence
    for (final line in allLines) {
      final lineText = line.text.trim();
      if (lineText.length < 5) continue;

      final numbers = _extractNumbers(lineText);
      if (numbers.isEmpty) continue;

      // Skip shop name and total lines
      if (lineText == shopName) continue;
      if (totalKeywords.any((k) => lineText.toLowerCase().contains(k))) {
        continue;
      }
      if (gstKeywords.any((k) => lineText.toLowerCase().contains(k))) continue;

      // Calculate confidence based on element confidence scores
      double confidence = 0.0;
      int elementCount = 0;
      for (final element in line.elements) {
        // ML Kit doesn't provide per-element confidence, estimate based on text quality
        confidence += _estimateConfidence(element.text);
        elementCount++;
      }
      confidence = elementCount > 0 ? confidence / elementCount : 0.5;

      // Parse item name (remove numbers)
      final name = lineText.replaceAll(RegExp(r'[0-9.,â‚¹$xÃ—]'), '').trim();
      if (name.length < 2) continue;

      // Parse quantity and price
      double quantity = 1.0;
      double price = numbers.last;

      // Try to detect quantity patterns like "2 x Item" or "Item x 2"
      if (numbers.length >= 2) {
        final possibleQty = numbers.first;
        if (possibleQty <= 100 && possibleQty > 0) {
          quantity = possibleQty;
          price = numbers.last;
        }
      }

      items.add(
        ScannedItem(
          name: name,
          quantity: quantity,
          price: price,
          amount: quantity * price,
          confidence: confidence,
          rawLine: lineText,
        ),
      );
    }

    // Calculate overall confidence
    final overallConfidence = items.isEmpty
        ? 0.0
        : items.map((i) => i.confidence).reduce((a, b) => a + b) / items.length;

    // Determine detected language based on script
    final detectedLanguage = switch (script) {
      OcrScript.latin => 'en',
      OcrScript.devanagiri => 'hi', // Could be Hindi, Marathi, etc.
    };

    return OcrResult(
      rawText: text.text,
      items: items,
      gst: gstAmount,
      totalAmount: totalAmount == 0
          ? items.fold(0.0, (sum, item) => sum + item.amount)
          : totalAmount,
      shopName: shopName.isNotEmpty ? shopName : 'Scanned Vendor',
      billDate: billDate,
      detectedLanguage: detectedLanguage,
      needsReview: items.any((i) => i.confidence < kConfidenceThreshold),
      overallConfidence: overallConfidence,
    );
  }

  /// Estimate confidence based on text quality
  double _estimateConfidence(String text) {
    if (text.isEmpty) return 0.0;

    // Confidence factors
    double score = 0.8; // Base confidence

    // Penalize very short text
    if (text.length < 3) score -= 0.2;

    // Penalize unusual characters (indicates poor OCR)
    final unusualChars = RegExp(r'[|\\~`]');
    if (unusualChars.hasMatch(text)) score -= 0.3;

    // Penalize too many numbers mixed with letters (potential misread)
    final mixedPattern = RegExp(r'[a-zA-Z]\d|\d[a-zA-Z]');
    if (mixedPattern.allMatches(text).length > 2) score -= 0.1;

    return score.clamp(0.0, 1.0);
  }

  /// Check if text is a valid shop name
  bool _isValidShopName(String text) {
    if (text.length < 3) return false;
    // Shop names typically don't start with numbers
    if (RegExp(r'^[0-9]').hasMatch(text)) return false;
    // Avoid date-like patterns
    if (RegExp(r'\d{1,4}[-/]\d{1,2}').hasMatch(text)) return false;
    return true;
  }

  /// Extract date from text
  DateTime? _extractDate(String text) {
    final regex = RegExp(r'(\d{1,4}[./-]\d{1,2}[./-]\d{1,4})');
    final match = regex.firstMatch(text);
    if (match != null) {
      try {
        final dateStr = match.group(0)!.replaceAll(RegExp(r'[./]'), '-');
        return DateTime.parse(dateStr);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Extract numbers from text
  List<double> _extractNumbers(String text) {
    final regex = RegExp(r'\d+(?:\.\d+)?');
    return regex
        .allMatches(text)
        .map((m) => double.tryParse(m.group(0)!) ?? 0.0)
        .where((n) => n > 0)
        .toList();
  }

  /// Dispose all recognizers
  Future<void> dispose() async {
    for (final recognizer in _recognizers.values) {
      await recognizer.close();
    }
    _recognizers.clear();
    debugPrint('MLKitOcrService: All recognizers disposed');
  }
}

/// Thrown when on-device OCR cannot run (e.g. on web, where ML Kit is
/// unavailable). Callers should surface an unsupported/empty state rather
/// than a fabricated OCR result (data-integrity rule: no mock values).
class OcrUnsupportedException implements Exception {
  final String message;
  OcrUnsupportedException(this.message);

  @override
  String toString() => 'OcrUnsupportedException: $message';
}
