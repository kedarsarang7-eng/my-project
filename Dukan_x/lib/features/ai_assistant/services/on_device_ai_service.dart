import 'package:flutter/foundation.dart';
import 'groq_service.dart';
import 'query_executor.dart';

/// OnDeviceAIService - Orchestrates Groq + Local Query Execution
/// Provides a complete AI assistant without needing a backend server.
class OnDeviceAIService {
  final GroqService _groqService;
  final QueryExecutor _queryExecutor;

  // Conversation history for context
  final List<Map<String, String>> _conversationHistory = [];
  static const int _maxHistoryLength = 10;

  OnDeviceAIService({required String groqApiKey})
    : _groqService = GroqService(apiKey: groqApiKey),
      _queryExecutor = QueryExecutor();

  /// Process a user query (voice or text)
  /// Returns a natural language response
  Future<AIResponse> processQuery({
    required String userId,
    required String userInput,
  }) async {
    debugPrint('🤖 Processing: $userInput');

    // 1. Send to Groq for intent detection and SQL generation
    final groqResponse = await _groqService.generateSQL(
      userId: userId,
      question: userInput,
    );

    // 2. Handle different intents
    if (groqResponse.isConversation) {
      // Simple conversation - no database query needed
      _addToHistory('user', userInput);
      _addToHistory('assistant', groqResponse.explanation);

      return AIResponse(
        text: groqResponse.explanation,
        intent: 'conversation',
        success: true,
      );
    }

    if (groqResponse.isError) {
      return AIResponse(
        text: groqResponse.explanation,
        intent: 'error',
        success: false,
      );
    }

    if (groqResponse.isQuery && groqResponse.sql != null) {
      // 3. Execute SQL against local database
      final queryResult = await _queryExecutor.execute(groqResponse.sql!);

      if (queryResult.success) {
        final responseText = queryResult.formattedText;

        _addToHistory('user', userInput);
        _addToHistory('assistant', responseText);

        return AIResponse(
          text: responseText,
          intent: 'query_result',
          success: true,
          data: {
            'rows': queryResult.rows,
            'count': queryResult.rowCount,
            'sql': groqResponse.sql,
            'explanation': groqResponse.explanation,
          },
        );
      } else {
        return AIResponse(
          text:
              'Sorry, I couldn\'t fetch that data. ${queryResult.error ?? ''}',
          intent: 'query_failed',
          success: false,
        );
      }
    }

    // Fallback
    return AIResponse(
      text:
          'I\'m not sure how to help with that. Try asking about sales, customers, or inventory.',
      intent: 'unknown',
      success: false,
    );
  }

  /// Simple chat without database queries
  Future<String> chat(String message) async {
    return await _groqService.chat(
      message: message,
      systemPrompt:
          'You are Mahiru, a friendly business assistant for DukanX app. '
          'Keep responses brief and helpful. You help with billing, inventory, and customer management.',
    );
  }

  void _addToHistory(String role, String content) {
    _conversationHistory.add({'role': role, 'content': content});
    if (_conversationHistory.length > _maxHistoryLength * 2) {
      _conversationHistory.removeRange(0, 2);
    }
  }

  void clearHistory() {
    _conversationHistory.clear();
  }
}

/// Response model for AI processing
class AIResponse {
  final String text;
  final String intent;
  final bool success;
  final Map<String, dynamic>? data;

  AIResponse({
    required this.text,
    required this.intent,
    required this.success,
    this.data,
  });

  bool get hasData =>
      data != null && (data!['rows'] as List?)?.isNotEmpty == true;
  int get rowCount => data?['count'] ?? 0;
}
