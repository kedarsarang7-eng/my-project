import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// GroqService - Direct Groq API calls from Flutter
/// Provides Text-to-SQL capability without a backend server.
class GroqService {
  static const String _baseUrl =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'llama-3.1-8b-instant';

  // SECURITY: API key MUST be provided via constructor from secure source.
  // Options:
  // 1. flutter_secure_storage (recommended for device-stored secrets)
  // 2. Firebase Remote Config (for server-managed keys)
  // 3. Environment variables via --dart-define at build time
  // NEVER hardcode API keys in source code for production.
  final String _apiKey;

  GroqService({required String apiKey}) : _apiKey = apiKey;

  /// Schema prompt for Text-to-SQL conversion
  static const String _schemaPrompt = '''
You are a SQL expert for DukanX, a business management app.
Convert natural language questions to SQLite queries.

DATABASE SCHEMA:
----------------
-- bills (Sales Invoices)
CREATE TABLE bills (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    invoice_number TEXT,
    customer_id TEXT,
    customer_name TEXT,
    bill_date INTEGER NOT NULL,  -- Unix timestamp
    subtotal REAL DEFAULT 0.0,
    tax_amount REAL DEFAULT 0.0,
    discount_amount REAL DEFAULT 0.0,
    grand_total REAL DEFAULT 0.0,
    paid_amount REAL DEFAULT 0.0,
    status TEXT DEFAULT 'DRAFT',
    deleted_at INTEGER
);

-- customers
CREATE TABLE customers (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    name TEXT NOT NULL,
    phone TEXT,
    total_billed REAL DEFAULT 0.0,
    total_paid REAL DEFAULT 0.0,
    total_dues REAL DEFAULT 0.0,
    deleted_at INTEGER
);

-- products
CREATE TABLE products (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    name TEXT NOT NULL,
    selling_price REAL NOT NULL,
    stock_quantity REAL DEFAULT 0.0,
    unit TEXT DEFAULT 'pcs',
    deleted_at INTEGER
);

RULES:
------
1. Output ONLY valid JSON: {"sql": "...", "explanation": "...", "intent": "query"}
2. Timestamps are Unix epoch. Use datetime() function for comparisons.
3. ALWAYS filter: user_id = '{user_uid}' AND deleted_at IS NULL
4. Limit to 20 rows max.
5. If not a database question, return: {"sql": null, "explanation": "...", "intent": "conversation"}

EXAMPLES:
---------
User: "आज की sale कितनी हुई?"
{"sql": "SELECT COALESCE(SUM(grand_total), 0) as total FROM bills WHERE user_id = '{user_uid}' AND deleted_at IS NULL AND datetime(bill_date, 'unixepoch') >= datetime('now', 'start of day')", "explanation": "Today's sales", "intent": "query"}

User: "Top 5 customers with dues"
{"sql": "SELECT name, total_dues FROM customers WHERE user_id = '{user_uid}' AND deleted_at IS NULL AND total_dues > 0 ORDER BY total_dues DESC LIMIT 5", "explanation": "Top customers by dues", "intent": "query"}

User: "Hello, how are you?"
{"sql": null, "explanation": "Hello! I'm your business assistant. Ask me about sales, customers, or inventory!", "intent": "conversation"}
''';

  /// Generate SQL from natural language question
  Future<GroqResponse> generateSQL({
    required String userId,
    required String question,
  }) async {
    final prompt = _schemaPrompt.replaceAll('{user_uid}', userId);

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {'role': 'system', 'content': prompt},
            {'role': 'user', 'content': question},
          ],
          'temperature': 0.0,
          'max_tokens': 512,
          'response_format': {'type': 'json_object'},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        final parsed = jsonDecode(content);

        return GroqResponse(
          sql: parsed['sql'],
          explanation: parsed['explanation'] ?? '',
          intent: parsed['intent'] ?? 'query',
          success: true,
        );
      } else {
        debugPrint('Groq API Error: ${response.statusCode} - ${response.body}');
        return GroqResponse(
          sql: null,
          explanation: 'API Error: ${response.statusCode}',
          intent: 'error',
          success: false,
        );
      }
    } catch (e) {
      debugPrint('Groq Service Error: $e');
      return GroqResponse(
        sql: null,
        explanation: 'Connection failed. Check internet.',
        intent: 'error',
        success: false,
      );
    }
  }

  /// Simple chat completion (for non-SQL queries)
  Future<String> chat({required String message, String? systemPrompt}) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            if (systemPrompt != null)
              {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': message},
          ],
          'temperature': 0.7,
          'max_tokens': 256,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'] ?? '';
      }
      return 'Sorry, I could not process that.';
    } catch (e) {
      return 'Connection error. Please try again.';
    }
  }
}

/// Response model for Groq SQL generation
class GroqResponse {
  final String? sql;
  final String explanation;
  final String intent;
  final bool success;

  GroqResponse({
    this.sql,
    required this.explanation,
    required this.intent,
    required this.success,
  });

  bool get isQuery => sql != null && intent == 'query';
  bool get isConversation => intent == 'conversation';
  bool get isError => intent == 'error';
}
