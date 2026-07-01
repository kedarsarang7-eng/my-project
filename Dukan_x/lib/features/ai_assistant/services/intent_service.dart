import '../../../../core/di/service_locator.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/repository/products_repository.dart';
import '../../../../core/repository/bills_repository.dart';
import '../../../../core/repository/customers_repository.dart';
import 'package:intl/intl.dart';

enum IntentType {
  stock,
  sales,
  customer,
  navigate,
  billCreate,
  unknown,
  conversation,
}

class AiResponse {
  final String speech;
  final String text;
  final IntentType type;
  final dynamic data;

  AiResponse({
    required this.speech,
    String? text,
    required this.type,
    this.data,
  }) : text = text ?? speech;
}

class IntentService {
  final _productsRepository = sl<ProductsRepository>();
  final _billsRepository = sl<BillsRepository>();
  final _customersRepository = sl<CustomersRepository>();
  final _session = sl<SessionManager>();

  // Assistant Identity
  final String _name = "Mahiru";
  final String _creator = "Sarang Kedar Sir";

  // Keywords
  final Map<String, List<String>> _navigationKeywords = {
    'home': ['dashboard', 'home', 'main', 'ghar'],
    'insights': [
      'insights',
      'analytics',
      'profit',
      'loss',
      'performance',
      'analysis',
    ],
    'stock': ['stock', 'inventory', 'items', 'saman', 'mal'],
    'settings': ['settings', 'menu', 'options', 'profile'],
  };

  final Map<String, List<String>> _actionKeywords = {
    'bill': ['bill', 'invoice', 'sale', 'bech', 'new sale', 'create bill'],
    'scan': ['scan', 'camera', 'barcode'],
  };

  // Emotion Analysis
  String _detectEmotion(String text) {
    final t = text.toLowerCase();
    if (t.contains('worry') ||
        t.contains('bad') ||
        t.contains('problem') ||
        t.contains('fail') ||
        t.contains('error') ||
        t.contains('slow') ||
        t.contains('not working') ||
        t.contains('hard') ||
        t.contains('loss') ||
        t.contains('sad') ||
        t.contains('unhappy') ||
        t.contains('stress')) {
      return 'stressed';
    }
    if (t.contains('good') ||
        t.contains('great') ||
        t.contains('best') ||
        t.contains('profit') ||
        t.contains('happy') ||
        t.contains('success') ||
        t.contains('wow') ||
        t.contains('excellent')) {
      return 'happy';
    }
    if (t.contains('fast') ||
        t.contains('urgent') ||
        t.contains('quick') ||
        t.contains('now') ||
        t.contains('immediately')) {
      return 'urgent';
    }
    if (t.contains('help') ||
        t.contains('how') ||
        t.contains('what') ||
        t.contains('confused') ||
        t.contains('don\'t know')) {
      return 'confused';
    }
    return 'neutral';
  }

  Future<AiResponse> processIntent(String text, String languageCode) async {
    final lowerText = text.toLowerCase();
    final ownerId = _session.ownerId ?? '';
    final emotion = _detectEmotion(text);

    // 1. Identity Check
    if (lowerText.contains('who made you') ||
        lowerText.contains('who created you') ||
        lowerText.contains('tumala koni banavle') ||
        lowerText.contains('kisne banaya')) {
      return AiResponse(
        speech: "I was created by $_creator.",
        type: IntentType.conversation,
      );
    }

    if (lowerText.contains('your name') || lowerText.contains('who are you')) {
      return AiResponse(
        speech: _wrapWithEmotion(
          "Hello! I am $_name. How can I help you today?",
          emotion,
        ),
        type: IntentType.conversation,
      );
    }

    // 2. Navigation
    int? navIndex = _checkNavigation(lowerText);
    if (navIndex != null) {
      String dest = "Dashboard";
      if (navIndex == 1) dest = "Insights";
      if (navIndex == 2) dest = "Stock";
      if (navIndex == 4) dest = "Settings";
      String response = "Opening $dest for you.";
      if (emotion == 'urgent') response = "Opening $dest right away.";
      if (emotion == 'happy') response = "Sure! Let's check the $dest.";
      return AiResponse(
        speech: response,
        type: IntentType.navigate,
        data: navIndex,
      );
    }

    // 3. Actions
    if (_matches(lowerText, _actionKeywords['bill']!)) {
      return AiResponse(
        speech: _wrapWithEmotion("Opening the bill creation screen.", emotion),
        type: IntentType.billCreate,
      );
    }

    // 4. Stock
    if (lowerText.contains('stock') ||
        lowerText.contains('hav') ||
        lowerText.contains('left') ||
        lowerText.contains('quantity')) {
      return _handleStockIntent(lowerText, ownerId, emotion);
    }

    // 5. Sales
    if (lowerText.contains('sale') ||
        lowerText.contains('revenue') ||
        lowerText.contains('profit') ||
        lowerText.contains('sold')) {
      return _handleSalesIntent(lowerText, ownerId, emotion);
    }

    // 6. Customer
    if (lowerText.contains('customer') ||
        lowerText.contains('owe') ||
        lowerText.contains('pending') ||
        lowerText.contains('due')) {
      return _handleCustomerIntent(lowerText, ownerId, emotion);
    }

    // 7. Conversation
    if (lowerText.contains('hello') ||
        lowerText.contains('hi') ||
        lowerText.contains('namaste')) {
      return AiResponse(
        speech:
            "Hello! I am $_name. I'm here to help you manage your business.",
        type: IntentType.conversation,
      );
    }

    if (lowerText.contains('thank')) {
      return AiResponse(
        speech: "You're clearly welcome! I'm happy to help.",
        type: IntentType.conversation,
      );
    }

    return AiResponse(
      speech: _getFallbackMessage(languageCode, emotion),
      type: IntentType.unknown,
    );
  }

  // Helper
  String _wrapWithEmotion(String base, String emotion) {
    if (emotion == 'stressed') return "Don't worry, I'm here. $base";
    if (emotion == 'happy') return "That's great! $base";
    if (emotion == 'urgent') return "On it. $base";
    if (emotion == 'confused') return "Let me help you. $base";
    return base;
  }

  int? _checkNavigation(String text) {
    if (_matches(text, _navigationKeywords['home']!)) return 0;
    if (_matches(text, _navigationKeywords['insights']!)) return 1;
    if (_matches(text, _navigationKeywords['stock']!)) return 2;
    if (_matches(text, _navigationKeywords['settings']!)) return 4;
    return null;
  }

  bool _matches(String text, List<String> keywords) {
    for (var word in keywords) {
      if (text.contains(word)) return true;
    }
    return false;
  }

  String _getFallbackMessage(String lang, String emotion) {
    if (lang.contains('mr')) return "मला समजले नाही, कृपया पुन्हा बोला.";
    if (lang.contains('hi')) return "मुझे समझ नहीं आया, कृपया फिर से बोलें.";
    if (emotion == 'stressed') {
      return "I'm listening, please take your time. You can ask about stock or sales.";
    }
    return "I didn't quite catch that. You can ask me about stock, sales, or customers.";
  }

  Future<AiResponse> _handleStockIntent(
    String text,
    String ownerId,
    String emotion,
  ) async {
    final result = await _productsRepository.getAll(userId: ownerId);
    final stockList = result.data ?? [];

    if (text.contains('low') ||
        text.contains('alert') ||
        text.contains('refill')) {
      final lowStock = stockList
          .where((i) => i.stockQuantity < i.lowStockThreshold)
          .toList();
      if (lowStock.isEmpty) {
        return AiResponse(
          speech: "Good news! All your stock levels are healthy.",
          type: IntentType.stock,
        );
      }
      final names = lowStock.map((e) => e.name).join(", ");
      return AiResponse(
        speech:
            "I'm concerned about a few items. ${lowStock.length} items are running low: $names. Should we order more?",
        type: IntentType.stock,
        data: lowStock,
      );
    }

    for (var item in stockList) {
      if (text.contains(item.name.toLowerCase())) {
        String resp =
            "${item.name} has ${item.stockQuantity} ${item.unit} remaining.";
        if (item.stockQuantity < item.lowStockThreshold) {
          resp =
              "Careful, ${item.name} is low. Only ${item.stockQuantity} ${item.unit} left.";
        }
        return AiResponse(speech: resp, type: IntentType.stock, data: [item]);
      }
    }

    return AiResponse(
      speech: "You currently have ${stockList.length} items in your inventory.",
      type: IntentType.stock,
      data: stockList,
    );
  }

  Future<AiResponse> _handleSalesIntent(
    String text,
    String ownerId,
    String emotion,
  ) async {
    final billsResult = await _billsRepository.getAll(userId: ownerId);
    final bills = billsResult.data ?? [];
    DateTime now = DateTime.now();
    DateTime start = DateTime(now.year, now.month, now.day);
    String label = "Today";

    if (text.contains('yesterday') ||
        text.contains('cal') ||
        text.contains('gaya')) {
      start = start.subtract(const Duration(days: 1));
      label = "Yesterday";
    }

    final periodBills = bills
        .where(
          (b) =>
              b.date.isAfter(start) &&
              b.date.isBefore(start.add(const Duration(days: 1))),
        )
        .toList();
    double total = periodBills.fold(0, (sum, b) => sum + b.grandTotal);
    String formatted = NumberFormat.currency(
      symbol: sl<CurrencyService>().symbol,
      locale: 'en_IN',
    ).format(total);
    String speech = "$label's total sales are $formatted.";

    if (total == 0) {
      speech =
          "No sales recorded for $label yet. Don't worry, things will pick up!";
    } else if (total > 5000 && label == 'Today') {
      speech = "Great job! $label's sales are $formatted so far.";
    } else if (emotion == 'stressed') {
      speech = "Here is the report: $label's sales are $formatted.";
    }

    return AiResponse(
      speech: speech,
      type: IntentType.sales,
      data: periodBills,
    );
  }

  Future<AiResponse> _handleCustomerIntent(
    String text,
    String ownerId,
    String emotion,
  ) async {
    final result = await _customersRepository.getAll(userId: ownerId);
    final customers = result.data ?? [];

    if (text.contains('who') || text.contains('top') || text.contains('list')) {
      final dues = customers.where((c) => c.totalDues > 0).toList();
      dues.sort((a, b) => b.totalDues.compareTo(a.totalDues));

      if (dues.isEmpty) {
        return AiResponse(
          speech: "Everything looks good! No pending payments from customers.",
          type: IntentType.customer,
        );
      }

      final top = dues
          .take(3)
          .map((e) => "${e.name} (${e.totalDues.toInt()})")
          .join(", ");
      return AiResponse(
        speech:
            "There are ${dues.length} customers with pending dues. The top ones are: $top",
        type: IntentType.customer,
        data: dues,
      );
    }

    for (var c in customers) {
      if (text.contains(c.name.toLowerCase())) {
        return AiResponse(
          speech: "${c.name} has a pending amount of ₹${c.totalDues}.",
          type: IntentType.customer,
          data: [c],
        );
      }
    }

    return AiResponse(
      speech: "Which customer would you like to know about?",
      type: IntentType.customer,
    );
  }
}
