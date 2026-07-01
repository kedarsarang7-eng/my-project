import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceService {
  final SpeechToText _speech = SpeechToText();
  bool _isAvailable = false;
  bool get isListening => _speech.isListening;

  Future<bool> init() async {
    try {
      _isAvailable = await _speech.initialize(
        onError: (e) => debugPrint('Voice error: $e'),
        onStatus: (s) => debugPrint('Voice status: $s'),
      );
    } catch (e) {
      debugPrint('Voice init failed: $e');
      _isAvailable = false;
    }
    return _isAvailable;
  }

  Future<void> startListening({
    required Function(String) onResult,
    required VoidCallback onDone,
  }) async {
    if (!_isAvailable) {
      bool available = await init();
      if (!available) return;
    }

    await _speech.listen(
      onResult: (result) {
        onResult(result.recognizedWords);
        if (result.finalResult) {
          onDone();
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 5),
    );
  }

  Future<void> stop() async {
    await _speech.stop();
  }

  /// Parses natural language input into structured bill data
  /// Example: "Add Paracetamol 10 tablets at 2 rupees each"
  /// Returns map with keys: name, qty, price, unit
  Map<String, dynamic> parseBillCommand(String text) {
    if (text.isEmpty) return {};

    text = text.toLowerCase();
    String name = text;
    double? qty;
    double? price;
    String unit = 'pcs';

    // 1. Extract Price (keywords: at, price, rupees, rs)
    // Regex for "at 50", "price 50", "50 rupees", "50 rs"
    final priceRegex = RegExp(r'(?:at|price|rupees|rs)\s*(\d+(\.\d+)?)');
    final priceMatch = priceRegex.firstMatch(text);
    if (priceMatch != null) {
      price = double.tryParse(priceMatch.group(1) ?? '');
      // Remove the matched price string from text to clean up name
      name = name.replaceAll(priceMatch.group(0)!, '');
    }

    // 2. Extract Quantity with Unit (keywords: kg, g, l, ml, box, packet, pcs, tablets)
    final qtyUnitRegex = RegExp(
      r'(\d+(\.\d+)?)\s*(kg|g|l|ml|box|packet|pcs|tablets|strips)',
    );
    final qtyUnitMatch = qtyUnitRegex.firstMatch(
      name,
    ); // Search in remaining text
    if (qtyUnitMatch != null) {
      qty = double.tryParse(qtyUnitMatch.group(1) ?? '');
      unit = qtyUnitMatch.group(3) ?? 'pcs';
      name = name.replaceAll(qtyUnitMatch.group(0)!, '');
    } else {
      // 3. Fallback: Extract pure number as Quantity if not found above
      // But be careful not to pick up numbers that might be part of the name if possible,
      // though usually numbers in name are rare or specific.
      // We'll assume solitary numbers are quantity if we haven't found a price yet (or if clearly separate).
      final numberRegex = RegExp(r'\b(\d+(\.\d+)?)\b');
      final matches = numberRegex.allMatches(name).toList();

      // If we found a price via regex, any other number is likely qty
      // If we didn't find price, we might have 2 numbers: 10 qty 50 price

      if (matches.isNotEmpty) {
        // Simple heuristic: First number is qty
        qty = double.tryParse(matches.first.group(1) ?? '');
        name = name.replaceAll(matches.first.group(0)!, '');
      }
    }

    // 4. Cleanup Name
    // Remove "add", "insert", common filler words
    name = name.replaceAll(RegExp(r'\b(add|insert|bill|item)\b'), '');
    name = name.replaceAll(RegExp(r'\s+'), ' ').trim();

    return {
      'name': name.isEmpty ? 'Unknown Item' : _capitalize(name),
      'quantity': qty ?? 1.0,
      'unit': unit,
      'price': price ?? 0.0,
    };
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
