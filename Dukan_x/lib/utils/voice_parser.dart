import '../models/bill.dart';

class VoiceParser {
  /// Parses a spoken string into a list of BillItems
  /// Format examples:
  /// "1 kg sugar 40"
  /// "2 dozen eggs 60"
  /// "3 packets milk 25 each"
  /// "1 kg rice 50 and 2 kg wheat 30"
  static List<BillItem> parse(String text) {
    if (text.trim().isEmpty) {
      return [];
    }

    // Normalize text
    text = text.toLowerCase();

    // Replace number words with digits (Use word boundaries!)
    final numbers = {
      'one': '1',
      'two': '2',
      'three': '3',
      'four': '4',
      'five': '5',
      'six': '6',
      'seven': '7',
      'eight': '8',
      'nine': '9',
      'ten': '10',
      'half': '0.5',
    };

    numbers.forEach((key, value) {
      text = text.replaceAll(RegExp(r'\b' + key + r'\b'), value);
    });

    // Remove filler words safely
    final fillers = [
      'rupees',
      'rs',
      'per kg',
      'each',
      'at',
      '@',
      'for',
      'please add',
      'add',
    ];
    for (var f in fillers) {
      text = text.replaceAll(RegExp(r'\b' + RegExp.escape(f) + r'\b'), '');
    }

    final items = <BillItem>[];

    // Split by common separators
    final segments = text.split(RegExp(r'\s+(and|&|,)\s+'));

    for (final segment in segments) {
      final item = _parseSegment(segment.trim());
      if (item != null) {
        items.add(item);
      }
    }

    return items;
  }

  static BillItem? _parseSegment(String segment) {
    // We try to extract Price, Quantity, Unit, GST, Discount, and Name.
    // Enhanced Logic for:
    // "1 kg sugar 40 gst 5%"
    // "Sugar 1kg 40 discount 5"

    double? price;
    double? qty;
    double gstRate = 0.0;
    double discount = 0.0;
    String unit = 'pcs';
    String name = segment;

    // 1. Extract GST (Look for 'gst 5%', 'tax 18', '5% gst')
    final gstRegex = RegExp(
      r'(?:gst|tax)\s*(\d+(\.\d+)?)%?|(\d+(\.\d+)?)%\s*(?:gst|tax)?',
    );
    final gstMatch = gstRegex.firstMatch(name);
    if (gstMatch != null) {
      String? val =
          gstMatch.group(1) ??
          gstMatch.group(3); // Group 1 for 'gst 5', Group 3 for '5% gst'
      if (val != null) {
        gstRate = double.tryParse(val) ?? 0.0;
        name = name.replaceAll(gstMatch.group(0)!, '');
      }
    }

    // 2. Extract Discount (Look for 'discount 10', 'off 5')
    final discountRegex = RegExp(r'(?:discount|off|less)\s*(\d+(\.\d+)?)');
    final discountMatch = discountRegex.firstMatch(name);
    if (discountMatch != null) {
      discount = double.tryParse(discountMatch.group(1)!) ?? 0.0;
      name = name.replaceAll(discountMatch.group(0)!, '');
    }

    // 3. Extract Price
    // Look for price patterns like '40', '40.5', explicitly at the end or standalone if high logic applies
    final priceRegex = RegExp(r'(?:at|@|price|rs|rate)?\s*(\d+(\.\d+)?)\s*$');
    final priceMatch = priceRegex.firstMatch(name);

    if (priceMatch != null) {
      bool isExplicitPrice = name.contains(RegExp(r'(at|@|price|rs|rate)'));

      if (isExplicitPrice) {
        price = double.tryParse(priceMatch.group(1)!);
        name = name.replaceAll(priceMatch.group(0)!, '');
      } else {
        // Heuristic: If we have another number, this end one is likely price
        // Only if extracting this doesn't leave us with NO number for Qty (unless Qty has unit)
        final otherNumberHelper = RegExp(r'\d');
        String tempName = name.replaceAll(priceMatch.group(0)!, '');
        if (otherNumberHelper.hasMatch(tempName)) {
          price = double.tryParse(priceMatch.group(1)!);
          name = tempName;
        }
      }
    }

    // 4. Extract Quantity and Unit
    // Map of variations to standard units
    final unitMap = {
      'kg': 'kg',
      'kgs': 'kg',
      'kilo': 'kg',
      'kilogram': 'kg',
      'g': 'g',
      'gms': 'g',
      'gm': 'g',
      'gram': 'g',
      'ltr': 'ltr',
      'liter': 'ltr',
      'litre': 'ltr',
      'ml': 'ml',
      'pc': 'pcs',
      'pcs': 'pcs',
      'piece': 'pcs',
      'pieces': 'pcs',
      'pkt': 'pkt',
      'packet': 'pkt',
      'packets': 'pkt',
      'box': 'box',
      'boxes': 'box',
      'dozen': 'dozen',
      'dozens': 'dozen',
      'strip': 'strips',
      'strips': 'strips',
      'm': 'm',
      'meter': 'm',
    };

    final unitsRegexStr = unitMap.keys.join('|');
    final qtyUnitRegex = RegExp(
      r'(\d+(\.\d+)?)\s*\b(' + unitsRegexStr + r')\b',
    );
    final qtyUnitMatch = qtyUnitRegex.firstMatch(name);

    if (qtyUnitMatch != null) {
      qty = double.tryParse(qtyUnitMatch.group(1)!);
      String uStr = qtyUnitMatch.group(3)!;
      unit = unitMap[uStr] ?? 'pcs';
      name = name.replaceAll(qtyUnitMatch.group(0)!, '');
    } else {
      // No explicit unit, separate number check at START
      final startQtyRegex = RegExp(r'^(\d+(\.\d+)?)\s+');
      final startMatch = startQtyRegex.firstMatch(name);
      if (startMatch != null) {
        qty = double.tryParse(startMatch.group(1)!);
        name = name.substring(startMatch.end);
      } else {
        // Check for standalone number at END if price wasn't found there
        if (price == null) {
          final endQtyRegex = RegExp(r'\s+(\d+(\.\d+)?)\s*$');
          final endMatch = endQtyRegex.firstMatch(name);
          if (endMatch != null) {
            qty = double.tryParse(endMatch.group(1)!);
            name = name.replaceAll(endMatch.group(0)!, '');
          }
        }
      }
    }

    name = name.trim();
    if (name.isEmpty) return null;

    return BillItem(
      productId: DateTime.now().microsecondsSinceEpoch.toString(),
      productName: _capitalize(
        name.replaceAll(RegExp(r'\s+'), ' '),
      ), // Clean whitespace
      qty: qty ?? 1.0,
      price: price ?? 0.0,
      unit: unit,
      gstRate: gstRate,
      discount: discount,
    );
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
