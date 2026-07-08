// ============================================================================
// OpenWA REST API Client — Typed HTTP wrapper for OpenWA endpoints
// ============================================================================
// Wraps all Phase-1 OpenWA REST API calls (Session, Message, Template, Contact).
// Automatically injects per-business API key from secure storage.
// Does NOT use the DukanX ApiClient — OpenWA has its own auth (X-API-Key).
//
// All calls are scoped to the current business via OpenWATenantService.
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'openwa_config.dart';
import 'openwa_models.dart';

/// HTTP client for the OpenWA REST API.
///
/// Usage:
/// ```dart
/// final client = OpenWAClient(apiKey: 'owk_abc123...');
/// final sessions = await client.listSessions();
/// await client.sendText(sessionId, chatId, 'Hello!');
/// ```
class OpenWAClient {
  final String _apiKey;
  final http.Client _httpClient;
  final String _baseUrl;

  OpenWAClient({
    required String apiKey,
    http.Client? httpClient,
    String? baseUrl,
  })  : _apiKey = apiKey,
        _httpClient = httpClient ?? http.Client(),
        _baseUrl = baseUrl ?? OpenWAConfig.baseUrl;

  // ── Sessions ──────────────────────────────────────────────────────────────

  /// List all sessions visible to this API key.
  Future<List<WASession>> listSessions() async {
    final data = await _get<List<dynamic>>('/sessions');
    return data.map((e) => WASession.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Get a single session by ID.
  Future<WASession> getSession(String sessionId) async {
    final data = await _get<Map<String, dynamic>>('/sessions/$sessionId');
    return WASession.fromJson(data);
  }

  /// Create a new WhatsApp session.
  Future<WASession> createSession(String name) async {
    final data = await _post<Map<String, dynamic>>(
      '/sessions',
      body: {'name': name},
    );
    return WASession.fromJson(data);
  }

  /// Start a session (initiates WhatsApp connection).
  Future<WASession> startSession(String sessionId) async {
    final data = await _post<Map<String, dynamic>>(
      '/sessions/$sessionId/start',
    );
    return WASession.fromJson(data);
  }

  /// Stop a session.
  Future<WASession> stopSession(String sessionId) async {
    final data = await _post<Map<String, dynamic>>(
      '/sessions/$sessionId/stop',
    );
    return WASession.fromJson(data);
  }

  /// Delete a session.
  Future<void> deleteSession(String sessionId) async {
    await _delete('/sessions/$sessionId');
  }

  /// Get QR code for session authentication.
  Future<WAQRCode> getQRCode(String sessionId) async {
    final data = await _get<Map<String, dynamic>>('/sessions/$sessionId/qr');
    return WAQRCode.fromJson(data);
  }

  /// Request pairing code (alternative to QR).
  Future<WAPairingCode> requestPairingCode(
    String sessionId,
    String phoneNumber,
  ) async {
    final data = await _post<Map<String, dynamic>>(
      '/sessions/$sessionId/pairing-code',
      body: {'phoneNumber': phoneNumber},
    );
    return WAPairingCode.fromJson(data);
  }

  /// Get session statistics.
  Future<WASessionStats> getStats() async {
    final data = await _get<Map<String, dynamic>>('/sessions/stats/overview');
    return WASessionStats.fromJson(data);
  }

  /// Get active chats for a session.
  Future<List<WAChat>> getChats(String sessionId, {int? limit}) async {
    final query = limit != null ? '?limit=$limit' : '';
    final data = await _get<List<dynamic>>('/sessions/$sessionId/chats$query');
    return data.map((e) => WAChat.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── Messages ──────────────────────────────────────────────────────────────

  /// Send a text message.
  Future<WAMessageResponse> sendText(
    String sessionId,
    String chatId,
    String text,
  ) async {
    final data = await _post<Map<String, dynamic>>(
      '/sessions/$sessionId/messages/send-text',
      body: {'chatId': chatId, 'text': text},
    );
    return WAMessageResponse.fromJson(data);
  }

  /// Send an image.
  Future<WAMessageResponse> sendImage(
    String sessionId,
    String chatId, {
    String? url,
    String? base64Data,
    String? caption,
  }) async {
    final body = <String, dynamic>{'chatId': chatId};
    if (url != null) body['url'] = url;
    if (base64Data != null) body['base64'] = base64Data;
    if (caption != null) body['caption'] = caption;

    final data = await _post<Map<String, dynamic>>(
      '/sessions/$sessionId/messages/send-image',
      body: body,
    );
    return WAMessageResponse.fromJson(data);
  }

  /// Send a document (PDF, etc.).
  Future<WAMessageResponse> sendDocument(
    String sessionId,
    String chatId, {
    String? url,
    String? base64Data,
    String? filename,
    String? caption,
  }) async {
    final body = <String, dynamic>{'chatId': chatId};
    if (url != null) body['url'] = url;
    if (base64Data != null) body['base64'] = base64Data;
    if (filename != null) body['filename'] = filename;
    if (caption != null) body['caption'] = caption;

    final data = await _post<Map<String, dynamic>>(
      '/sessions/$sessionId/messages/send-document',
      body: body,
    );
    return WAMessageResponse.fromJson(data);
  }

  /// Send a template message.
  Future<WAMessageResponse> sendTemplate(
    String sessionId,
    String chatId, {
    String? templateId,
    String? templateName,
    Map<String, String>? variables,
  }) async {
    final body = <String, dynamic>{'chatId': chatId};
    if (templateId != null) body['templateId'] = templateId;
    if (templateName != null) body['templateName'] = templateName;
    if (variables != null) body['variables'] = variables;

    final data = await _post<Map<String, dynamic>>(
      '/sessions/$sessionId/messages/send-template',
      body: body,
    );
    return WAMessageResponse.fromJson(data);
  }

  /// Get chat messages.
  Future<WAMessageList> getChatMessages(
    String sessionId,
    String chatId, {
    int limit = 100,
  }) async {
    final data = await _get<Map<String, dynamic>>(
      '/sessions/$sessionId/messages?chatId=${Uri.encodeComponent(chatId)}&limit=$limit',
    );
    return WAMessageList.fromJson(data);
  }

  // ── Templates ─────────────────────────────────────────────────────────────

  /// List message templates for a session.
  Future<List<WATemplate>> listTemplates(String sessionId) async {
    final data = await _get<List<dynamic>>(
      '/sessions/$sessionId/templates',
    );
    return data
        .map((e) => WATemplate.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Create a message template.
  Future<WATemplate> createTemplate(
    String sessionId, {
    required String name,
    required String body,
    String? header,
    String? footer,
  }) async {
    final data = await _post<Map<String, dynamic>>(
      '/sessions/$sessionId/templates',
      body: {
        'name': name,
        'body': body,
        'header': ?header,
        'footer': ?footer,
      },
    );
    return WATemplate.fromJson(data);
  }

  /// Update a message template.
  Future<WATemplate> updateTemplate(
    String sessionId,
    String templateId, {
    String? name,
    String? body,
    String? header,
    String? footer,
  }) async {
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (body != null) payload['body'] = body;
    if (header != null) payload['header'] = header;
    if (footer != null) payload['footer'] = footer;

    final data = await _put<Map<String, dynamic>>(
      '/sessions/$sessionId/templates/$templateId',
      body: payload,
    );
    return WATemplate.fromJson(data);
  }

  /// Delete a message template.
  Future<void> deleteTemplate(String sessionId, String templateId) async {
    await _delete('/sessions/$sessionId/templates/$templateId');
  }

  // ── Contacts ──────────────────────────────────────────────────────────────

  /// Check if a phone number is registered on WhatsApp.
  Future<WACheckNumber> checkNumber(String sessionId, String number) async {
    final data = await _get<Map<String, dynamic>>(
      '/sessions/$sessionId/contacts/check/${Uri.encodeComponent(number)}',
    );
    return WACheckNumber.fromJson(data);
  }

  // ── Health ────────────────────────────────────────────────────────────────

  /// Check OpenWA backend health.
  Future<WAHealthStatus> checkHealth() async {
    final data = await _get<Map<String, dynamic>>('/health');
    return WAHealthStatus.fromJson(data);
  }

  // ── HTTP Internals ────────────────────────────────────────────────────────

  Future<T> _get<T>(String endpoint) async {
    final response = await _request('GET', endpoint);
    return _parseBody<T>(response);
  }

  Future<T> _post<T>(String endpoint, {Map<String, dynamic>? body}) async {
    final response = await _request('POST', endpoint, body: body);
    return _parseBody<T>(response);
  }

  Future<T> _put<T>(String endpoint, {Map<String, dynamic>? body}) async {
    final response = await _request('PUT', endpoint, body: body);
    return _parseBody<T>(response);
  }

  Future<void> _delete(String endpoint) async {
    await _request('DELETE', endpoint);
  }

  Future<http.Response> _request(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    final url = '$_baseUrl$endpoint';
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'X-API-Key': _apiKey,
    };

    late http.Response response;
    try {
      switch (method) {
        case 'GET':
          response = await _httpClient
              .get(Uri.parse(url), headers: headers)
              .timeout(OpenWAConfig.requestTimeout);
        case 'POST':
          response = await _httpClient
              .post(
                Uri.parse(url),
                headers: headers,
                body: body != null ? jsonEncode(body) : null,
              )
              .timeout(OpenWAConfig.requestTimeout);
        case 'PUT':
          response = await _httpClient
              .put(
                Uri.parse(url),
                headers: headers,
                body: body != null ? jsonEncode(body) : null,
              )
              .timeout(OpenWAConfig.requestTimeout);
        case 'DELETE':
          response = await _httpClient
              .delete(Uri.parse(url), headers: headers)
              .timeout(OpenWAConfig.requestTimeout);
        default:
          throw OpenWAException(message: 'Unsupported method: $method');
      }
    } on SocketException catch (e) {
      throw OpenWAException(
        message: 'Network error connecting to OpenWA: ${e.message}',
        code: 'NETWORK_ERROR',
      );
    } on TimeoutException {
      throw OpenWAException(
        message: 'OpenWA request timed out',
        code: 'TIMEOUT',
      );
    }

    if (response.statusCode == 401) {
      throw OpenWAException(
        message: 'Invalid OpenWA API key',
        statusCode: 401,
        code: 'UNAUTHORIZED',
      );
    }

    if (response.statusCode == 404) {
      throw OpenWAException(
        message: 'Resource not found',
        statusCode: 404,
        code: 'NOT_FOUND',
      );
    }

    if (response.statusCode >= 400) {
      String errorMsg = 'OpenWA API error (${response.statusCode})';
      try {
        final errorBody = jsonDecode(response.body);
        if (errorBody is Map && errorBody['message'] != null) {
          errorMsg = errorBody['message'] as String;
        }
      } catch (_) {}
      throw OpenWAException(
        message: errorMsg,
        statusCode: response.statusCode,
      );
    }

    return response;
  }

  T _parseBody<T>(http.Response response) {
    if (response.statusCode == 204) {
      // No content
      return null as T;
    }
    final decoded = jsonDecode(response.body);
    return decoded as T;
  }

  /// Release HTTP client resources.
  void dispose() {
    _httpClient.close();
  }
}

/// Exception thrown by OpenWA API operations.
class OpenWAException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;

  const OpenWAException({
    required this.message,
    this.statusCode,
    this.code,
  });

  bool get isAuthError => statusCode == 401;
  bool get isNotFound => statusCode == 404;
  bool get isServerError => (statusCode ?? 0) >= 500;

  @override
  String toString() =>
      'OpenWAException(${statusCode ?? 'N/A'}): $message${code != null ? ' [$code]' : ''}';
}
