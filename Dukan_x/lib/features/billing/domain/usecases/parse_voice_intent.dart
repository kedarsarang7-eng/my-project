import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/repository/products_repository.dart';
import '../../../../core/session/session_manager.dart';
import '../entities/bill_item.dart';
import '../entities/voice_bill_intent.dart';

class ParseVoiceIntent implements UseCase<VoiceBillIntent, String> {
  final ProductsRepository repository;
  final SessionManager sessionManager;

  ParseVoiceIntent(this.repository, this.sessionManager);

  @override
  Future<Either<Failure, VoiceBillIntent>> call(String command) async {
    try {
      if (!sessionManager.isAuthenticated) {
        return Left(InputFailure('User not authenticated'));
      }
      final userId = sessionManager.ownerId;
      if (userId == null) {
        return Left(InputFailure('Owner ID not found'));
      }

      final intent = await _parse(command, userId);
      return Right(intent);
    } catch (e) {
      return Left(InputFailure(e.toString()));
    }
  }

  Future<VoiceBillIntent> _parse(String rawText, String userId) async {
    String text = rawText.toLowerCase().trim();

    // 1. Detect High-Level Intents (Confirm/Cancel)
    if (_matches(text, ['confirm', 'save bill', 'sahi hai', 'done', 'lock'])) {
      return VoiceBillIntent(
        type: VoiceBillIntentType.confirmBill,
        rawText: rawText,
      );
    }
    if (_matches(text, ['cancel', 'delete', 'discard', 'hatao'])) {
      return VoiceBillIntent(
        type: VoiceBillIntentType.cancelBill,
        rawText: rawText,
      );
    }

    // Default Intent: Create/Update Bill
    String? customerName;
    VoicePaymentMode paymentMode = VoicePaymentMode.unknown;
    bool isGst = false;
    double? discount;

    // 2. Extract Customer Name
    // Pattern: "Rajesh ko..." or "Bill for Rajesh..."
    final customerRegexes = [
      RegExp(r'^(.*?)(\s+ko\b)'), // Hindi: "Rajesh ko"
      RegExp(
        r'^bill\s+(?:for|to)\s+(.*?)(?:\s+laga|\s+start|\s+add|\s|$)',
      ), // English: "Bill for Rajesh"
    ];

    for (var regex in customerRegexes) {
      final match = regex.firstMatch(text);
      if (match != null) {
        customerName = match.group(1)?.trim();
        // Remove the matched part from text to avoid confusing item parser
        text = text.replaceFirst(match.group(0)!, '').trim();
        break;
      }
    }

    // 3. Extract Payment Mode
    if (_contains(text, ['cash', 'nagad', 'rokda'])) {
      paymentMode = VoicePaymentMode.cash;
      text = _remove(text, ['cash payment', 'cash', 'nagad', 'rokda']);
    } else if (_contains(text, ['online', 'upi', 'gpay', 'phonepe', 'qr'])) {
      paymentMode = VoicePaymentMode.online;
      text = _remove(text, [
        'online payment',
        'online',
        'upi',
        'gpay',
        'phonepe',
        'qr',
      ]);
    } else if (_contains(text, [
      'udhari',
      'credit',
      'khata',
      'later',
      'baaki',
    ])) {
      paymentMode = VoicePaymentMode.credit;
      text = _remove(text, ['udhari', 'credit', 'khata', 'later', 'baaki']);
    }

    // 4. Extract Items
    // Use the logic similar to classic Parsing but enhanced with Repository matching
    List<BillItem> items = await _parseItems(text, userId);

    return VoiceBillIntent(
      type: VoiceBillIntentType.createBill,
      customerName: customerName != null ? _capitalize(customerName) : null,
      items: items,
      paymentMode: paymentMode,
      rawText: rawText,
      isGstApplicable: isGst,
      discount: discount,
    );
  }

  bool _matches(String text, List<String> keywords) {
    for (var k in keywords) {
      if (text == k || text.contains(k)) {
        return true; // Loose matching for full phrases
      }
    }
    return false;
  }

  bool _contains(String text, List<String> keywords) {
    for (var k in keywords) {
      if (text.contains(k)) return true;
    }
    return false;
  }

  String _remove(String text, List<String> keywords) {
    String temp = text;
    for (var k in keywords) {
      temp = temp.replaceAll(RegExp(r'\b' + RegExp.escape(k) + r'\b'), '');
    }
    return temp.trim();
  }

  Future<List<BillItem>> _parseItems(String cleanedText, String userId) async {
    // 1. Convert number words
    String processed = _convertNumberWords(cleanedText);

    // 2. Split by numbers to isolate items
    // Regex: (\d+(?:\.\d+)?)\s+([^\d]+)  -> captures "2" "kg sugar"
    final RegExp itemRegex = RegExp(
      r'(\d+(?:\.\d+)?)\s*([a-z\s\%\.]+)',
      caseSensitive: false,
    );
    final matches = itemRegex.allMatches(processed);

    List<BillItem> billItems = [];

    // 3. Process each match
    if (matches.isEmpty) {
      // Maybe the text starts without a number? "Sugar 2 kg"
      // Try reverse regex? Or just return empty for now.
      return [];
    }

    for (final match in matches) {
      double qty = double.tryParse(match.group(1) ?? '1') ?? 1;
      String rest = match.group(2)?.trim() ?? '';
      if (rest.isEmpty) continue;

      // Extract Unit & Name
      String unit = 'pcs';
      String name = rest;

      final unitMap = {
        'kg': 'kg',
        'kgs': 'kg',
        'kilo': 'kg',
        'g': 'g',
        'gm': 'g',
        'gram': 'g',
        'l': 'ltr',
        'ltr': 'ltr',
        'liter': 'ltr',
        'ml': 'ml',
        'doz': 'dozen',
        'dozen': 'dozen',
        'dz': 'dozen',
        'pkt': 'pkt',
        'packet': 'pkt',
        'pack': 'pkt',
        'pc': 'pcs',
        'pcs': 'pcs',
        'piece': 'pcs',
        'box': 'box',
      };

      // Check if 'rest' starts with a unit
      // Sort units by length descending to match 'litre' before 'l'
      var sortedUnits = unitMap.keys.toList()
        ..sort((a, b) => b.length.compareTo(a.length));

      for (final u in sortedUnits) {
        if (name.startsWith('$u ')) {
          unit = unitMap[u]!;
          name = name.substring(u.length).trim();
          break;
        } else if (name == u) {
          // just "2 kg" -> name is empty? invalid item
          unit = unitMap[u]!;
          name = "";
          break;
        }
      }

      if (name.isEmpty) continue;

      // Match with Repository (Fuzzy / Contains)
      final searchResult = await repository.search(name, userId: userId);

      Product? bestMatch;
      if (searchResult.isSuccess &&
          searchResult.data != null &&
          searchResult.data!.isNotEmpty) {
        // Find best match: Exact > StartsWith
        final products = searchResult.data!;

        bestMatch = products.firstWhere(
          (p) => p.name.toLowerCase() == name,
          orElse: () => products.firstWhere(
            (p) => p.name.toLowerCase().startsWith(name),
            orElse: () => products.first,
          ),
        );
      }

      if (bestMatch != null) {
        billItems.add(
          BillItem(
            productId: bestMatch.id,
            name: bestMatch.name, // Use canonical name
            quantity: qty,
            rate: bestMatch.sellingPrice,
            amount: qty * bestMatch.sellingPrice,
            unit: bestMatch.unit, // Use canonical unit
          ),
        );
      } else {
        // Unknown item
        _addRawItem(billItems, _capitalize(name), qty, unit);
      }
    }

    return billItems;
  }

  void _addRawItem(List<BillItem> items, String name, double qty, String unit) {
    items.add(
      BillItem(
        productId: '', // Empty ID indicates unknown/manual item
        name: name,
        quantity: qty,
        rate: 0,
        amount: 0,
        unit: unit,
      ),
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  String _convertNumberWords(String input) {
    final map = {
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
      'ek': '1',
      'do': '2',
      'teen': '3',
      'char': '4',
      'paanch': '5',
      'panch': '5',
      'che': '6',
      'saat': '7',
      'aath': '8',
      'nau': '9',
      'das': '10',
      'aadha': '0.5',
      'half': '0.5',
      'pav': '0.25',
    };

    String out = input;
    map.forEach((key, value) {
      out = out.replaceAll(RegExp(r'\b' + key + r'\b'), value);
    });
    return out;
  }
}
