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

  // ── Contacts (extended) ──────────────────────────────────────────────────

  /// Get all contacts for a session.
  Future<List<Map<String, dynamic>>> getContacts(
    String sessionId, {
    int? limit,
    int? offset,
  }) async {
    final params = <String>[];
    if (limit != null) params.add('limit=$limit');
    if (offset != null) params.add('offset=$offset');
    final query = params.isNotEmpty ? '?${params.join('&')}' : '';
    final data = await _get<List<dynamic>>(
      '/sessions/$sessionId/contacts$query',
    );
    return data.cast<Map<String, dynamic>>();
  }

  /// Get a specific contact by ID.
  Future<Map<String, dynamic>> getContact(
    String sessionId,
    String contactId,
  ) async {
    return _get<Map<String, dynamic>>(
      '/sessions/$sessionId/contacts/${Uri.encodeComponent(contactId)}',
    );
  }

  /// Get profile picture URL for a contact.
  Future<String?> getProfilePicture(
    String sessionId,
    String contactId,
  ) async {
    final data = await _get<Map<String, dynamic>>(
      '/sessions/$sessionId/contacts/${Uri.encodeComponent(contactId)}/profile-picture',
    );
    return data['url'] as String?;
  }

  /// Resolve a contact ID to a phone number.
  Future<String?> resolveContactPhone(
    String sessionId,
    String contactId,
  ) async {
    final data = await _get<Map<String, dynamic>>(
      '/sessions/$sessionId/contacts/${Uri.encodeComponent(contactId)}/phone',
    );
    return data['phone'] as String?;
  }

  /// Block a contact.
  Future<void> blockContact(String sessionId, String contactId) async {
    await _post<Map<String, dynamic>>(
      '/sessions/$sessionId/contacts/${Uri.encodeComponent(contactId)}/block',
    );
  }

  /// Unblock a contact.
  Future<void> unblockContact(String sessionId, String contactId) async {
    await _delete(
      '/sessions/$sessionId/contacts/${Uri.encodeComponent(contactId)}/block',
    );
  }

  // ── Groups ───────────────────────────────────────────────────────────────

  /// List all groups for a session.
  Future<List<Map<String, dynamic>>> getGroups(
    String sessionId, {
    int? limit,
    int? offset,
  }) async {
    final params = <String>[];
    if (limit != null) params.add('limit=$limit');
    if (offset != null) params.add('offset=$offset');
    final query = params.isNotEmpty ? '?${params.join('&')}' : '';
    final data = await _get<List<dynamic>>(
      '/sessions/$sessionId/groups$query',
    );
    return data.cast<Map<String, dynamic>>();
  }

  /// Get detailed info for a group.
  Future<Map<String, dynamic>> getGroupInfo(
    String sessionId,
    String groupId,
  ) async {
    return _get<Map<String, dynamic>>(
      '/sessions/$sessionId/groups/${Uri.encodeComponent(groupId)}',
    );
  }

  /// Create a new group.
  Future<Map<String, dynamic>> createGroup(
    String sessionId,
    String name,
    List<String> participants,
  ) async {
    return _post<Map<String, dynamic>>(
      '/sessions/$sessionId/groups',
      body: {'name': name, 'participants': participants},
    );
  }

  /// Add participants to a group.
  Future<void> addGroupParticipants(
    String sessionId,
    String groupId,
    List<String> participants,
  ) async {
    await _post<Map<String, dynamic>>(
      '/sessions/$sessionId/groups/${Uri.encodeComponent(groupId)}/participants',
      body: {'participants': participants},
    );
  }

  /// Remove participants from a group.
  Future<void> removeGroupParticipants(
    String sessionId,
    String groupId,
    List<String> participants,
  ) async {
    await _request('DELETE',
      '/sessions/$sessionId/groups/${Uri.encodeComponent(groupId)}/participants',
      body: {'participants': participants},
    );
  }

  /// Leave a group.
  Future<void> leaveGroup(String sessionId, String groupId) async {
    await _post<Map<String, dynamic>>(
      '/sessions/$sessionId/groups/${Uri.encodeComponent(groupId)}/leave',
    );
  }

  /// Get group invite code/link.
  Future<Map<String, dynamic>> getGroupInviteCode(
    String sessionId,
    String groupId,
  ) async {
    return _get<Map<String, dynamic>>(
      '/sessions/$sessionId/groups/${Uri.encodeComponent(groupId)}/invite-code',
    );
  }

  // ── Labels ───────────────────────────────────────────────────────────────

  /// Get all labels (WhatsApp Business only).
  Future<List<Map<String, dynamic>>> getLabels(String sessionId) async {
    final data = await _get<List<dynamic>>(
      '/sessions/$sessionId/labels',
    );
    return data.cast<Map<String, dynamic>>();
  }

  /// Get labels for a specific chat.
  Future<List<Map<String, dynamic>>> getChatLabels(
    String sessionId,
    String chatId,
  ) async {
    final data = await _get<List<dynamic>>(
      '/sessions/$sessionId/labels/chat/${Uri.encodeComponent(chatId)}',
    );
    return data.cast<Map<String, dynamic>>();
  }

  /// Add a label to a chat.
  Future<void> addLabelToChat(
    String sessionId,
    String chatId,
    String labelId,
  ) async {
    await _post<Map<String, dynamic>>(
      '/sessions/$sessionId/labels/chat/${Uri.encodeComponent(chatId)}',
      body: {'labelId': labelId},
    );
  }

  /// Remove a label from a chat.
  Future<void> removeLabelFromChat(
    String sessionId,
    String chatId,
    String labelId,
  ) async {
    await _delete(
      '/sessions/$sessionId/labels/chat/${Uri.encodeComponent(chatId)}/$labelId',
    );
  }

  // ── Messages (extended) ──────────────────────────────────────────────────

  /// Send a video message.
  Future<WAMessageResponse> sendVideo(
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
      '/sessions/$sessionId/messages/send-video',
      body: body,
    );
    return WAMessageResponse.fromJson(data);
  }

  /// Send an audio message.
  Future<WAMessageResponse> sendAudio(
    String sessionId,
    String chatId, {
    String? url,
    String? base64Data,
  }) async {
    final body = <String, dynamic>{'chatId': chatId};
    if (url != null) body['url'] = url;
    if (base64Data != null) body['base64'] = base64Data;

    final data = await _post<Map<String, dynamic>>(
      '/sessions/$sessionId/messages/send-audio',
      body: body,
    );
    return WAMessageResponse.fromJson(data);
  }

  /// Send a location message.
  Future<WAMessageResponse> sendLocation(
    String sessionId,
    String chatId, {
    required double latitude,
    required double longitude,
    String? name,
    String? address,
  }) async {
    final body = <String, dynamic>{
      'chatId': chatId,
      'latitude': latitude,
      'longitude': longitude,
    };
    if (name != null) body['name'] = name;
    if (address != null) body['address'] = address;

    final data = await _post<Map<String, dynamic>>(
      '/sessions/$sessionId/messages/send-location',
      body: body,
    );
    return WAMessageResponse.fromJson(data);
  }

  /// Send a contact card message.
  Future<WAMessageResponse> sendContactCard(
    String sessionId,
    String chatId, {
    required String contactName,
    required String contactPhone,
  }) async {
    final data = await _post<Map<String, dynamic>>(
      '/sessions/$sessionId/messages/send-contact',
      body: {
        'chatId': chatId,
        'name': contactName,
        'phone': contactPhone,
      },
    );
    return WAMessageResponse.fromJson(data);
  }

  /// Reply to a message.
  Future<WAMessageResponse> replyToMessage(
    String sessionId,
    String chatId,
    String quotedMessageId,
    String text,
  ) async {
    final data = await _post<Map<String, dynamic>>(
      '/sessions/$sessionId/messages/reply',
      body: {
        'chatId': chatId,
        'quotedMessageId': quotedMessageId,
        'text': text,
      },
    );
    return WAMessageResponse.fromJson(data);
  }

  /// React to a message.
  Future<void> reactToMessage(
    String sessionId,
    String chatId,
    String messageId,
    String emoji,
  ) async {
    await _post<Map<String, dynamic>>(
      '/sessions/$sessionId/messages/react',
      body: {
        'chatId': chatId,
        'messageId': messageId,
        'emoji': emoji,
      },
    );
  }

  /// Forward a message.
  Future<void> forwardMessage(
    String sessionId,
    String chatId,
    String messageId,
    String toChatId,
  ) async {
    await _post<Map<String, dynamic>>(
      '/sessions/$sessionId/messages/forward',
      body: {
        'chatId': chatId,
        'messageId': messageId,
        'toChatId': toChatId,
      },
    );
  }

  /// Delete a message (for everyone).
  Future<void> deleteMessage(
    String sessionId,
    String chatId,
    String messageId,
  ) async {
    await _post<Map<String, dynamic>>(
      '/sessions/$sessionId/messages/delete',
      body: {'chatId': chatId, 'messageId': messageId},
    );
  }

  /// Send bulk messages.
  Future<Map<String, dynamic>> sendBulk(
    String sessionId,
    List<Map<String, dynamic>> messages, {
    Map<String, dynamic>? options,
  }) async {
    return _post<Map<String, dynamic>>(
      '/sessions/$sessionId/messages/send-bulk',
      body: {'messages': messages, 'options': ?options},
    );
  }

  /// Get batch send status.
  Future<Map<String, dynamic>> getBatchStatus(
    String sessionId,
    String batchId,
  ) async {
    return _get<Map<String, dynamic>>(
      '/sessions/$sessionId/messages/batch/$batchId',
    );
  }

  /// Cancel a running batch.
  Future<void> cancelBatch(String sessionId, String batchId) async {
    await _post<Map<String, dynamic>>(
      '/sessions/$sessionId/messages/batch/$batchId/cancel',
    );
  }

  /// Mark a chat as read.
  Future<void> markChatRead(String sessionId, String chatId) async {
    await _post<Map<String, dynamic>>(
      '/sessions/$sessionId/chats/read',
      body: {'chatId': chatId},
    );
  }

  /// Mark a chat as unread.
  Future<void> markChatUnread(String sessionId, String chatId) async {
    await _post<Map<String, dynamic>>(
      '/sessions/$sessionId/chats/unread',
      body: {'chatId': chatId},
    );
  }

  /// Send typing indicator.
  Future<void> sendTyping(String sessionId, String chatId) async {
    await _post<Map<String, dynamic>>(
      '/sessions/$sessionId/chats/typing',
      body: {'chatId': chatId},
    );
  }

  /// Force-kill a stuck session.
  Future<void> forceKillSession(String sessionId) async {
    await _post<Map<String, dynamic>>(
      '/sessions/$sessionId/force-kill',
    );
  }

  /// Get session status.
  Future<Map<String, dynamic>> getSessionStatus(String sessionId) async {
    return _get<Map<String, dynamic>>('/sessions/$sessionId/status');
  }

  // ── Webhooks ─────────────────────────────────────────────────────────────

  /// List all webhooks for a session.
  Future<List<Map<String, dynamic>>> listWebhooks(String sessionId) async {
    final data = await _get<List<dynamic>>(
      '/sessions/$sessionId/webhooks',
    );
    return data.cast<Map<String, dynamic>>();
  }

  /// Get a specific webhook.
  Future<Map<String, dynamic>> getWebhook(
    String sessionId,
    String webhookId,
  ) async {
    return _get<Map<String, dynamic>>(
      '/sessions/$sessionId/webhooks/$webhookId',
    );
  }

  /// Create a webhook.
  Future<Map<String, dynamic>> createWebhook(
    String sessionId, {
    required String url,
    required List<String> events,
    String? secret,
    Map<String, String>? headers,
    Map<String, dynamic>? filters,
  }) async {
    final body = <String, dynamic>{'url': url, 'events': events};
    if (secret != null) body['secret'] = secret;
    if (headers != null) body['headers'] = headers;
    if (filters != null) body['filters'] = filters;

    return _post<Map<String, dynamic>>(
      '/sessions/$sessionId/webhooks',
      body: body,
    );
  }

  /// Update a webhook.
  Future<Map<String, dynamic>> updateWebhook(
    String sessionId,
    String webhookId,
    Map<String, dynamic> data,
  ) async {
    return _put<Map<String, dynamic>>(
      '/sessions/$sessionId/webhooks/$webhookId',
      body: data,
    );
  }

  /// Delete a webhook.
  Future<void> deleteWebhook(String sessionId, String webhookId) async {
    await _delete('/sessions/$sessionId/webhooks/$webhookId');
  }

  /// Test a webhook.
  Future<Map<String, dynamic>> testWebhook(
    String sessionId,
    String webhookId,
  ) async {
    return _post<Map<String, dynamic>>(
      '/sessions/$sessionId/webhooks/$webhookId/test',
    );
  }

  // ── Auth / API Keys ──────────────────────────────────────────────────────

  /// List all API keys (admin only).
  Future<List<Map<String, dynamic>>> listApiKeys() async {
    final data = await _get<List<dynamic>>('/auth/api-keys');
    return data.cast<Map<String, dynamic>>();
  }

  /// Create a new API key.
  Future<Map<String, dynamic>> createApiKey({
    required String name,
    required String role,
    List<String>? allowedIps,
    List<String>? allowedSessions,
    String? expiresAt,
  }) async {
    final body = <String, dynamic>{'name': name, 'role': role};
    if (allowedIps != null) body['allowedIps'] = allowedIps;
    if (allowedSessions != null) body['allowedSessions'] = allowedSessions;
    if (expiresAt != null) body['expiresAt'] = expiresAt;

    return _post<Map<String, dynamic>>('/auth/api-keys', body: body);
  }

  /// Update an API key.
  Future<Map<String, dynamic>> updateApiKey(
    String keyId,
    Map<String, dynamic> data,
  ) async {
    return _put<Map<String, dynamic>>('/auth/api-keys/$keyId', body: data);
  }

  /// Delete an API key.
  Future<void> deleteApiKey(String keyId) async {
    await _delete('/auth/api-keys/$keyId');
  }

  /// Revoke an API key.
  Future<Map<String, dynamic>> revokeApiKey(String keyId) async {
    return _post<Map<String, dynamic>>('/auth/api-keys/$keyId/revoke');
  }

  // ── Audit Logs ───────────────────────────────────────────────────────────

  /// Get audit logs.
  Future<Map<String, dynamic>> getAuditLogs({
    String? action,
    String? severity,
    int? limit,
    int? offset,
  }) async {
    final params = <String>[];
    if (action != null) params.add('action=$action');
    if (severity != null) params.add('severity=$severity');
    if (limit != null) params.add('limit=$limit');
    if (offset != null) params.add('offset=$offset');
    final query = params.isNotEmpty ? '?${params.join('&')}' : '';
    return _get<Map<String, dynamic>>('/audit$query');
  }

  // ── Stats ────────────────────────────────────────────────────────────────

  /// Get overview statistics.
  Future<Map<String, dynamic>> getOverviewStats() async {
    return _get<Map<String, dynamic>>('/stats/overview');
  }

  /// Get message statistics for a period.
  Future<Map<String, dynamic>> getMessageStats({String? period}) async {
    final query = period != null ? '?period=$period' : '';
    return _get<Map<String, dynamic>>('/stats/messages$query');
  }

  // ── Infrastructure ───────────────────────────────────────────────────────

  /// Get infrastructure status.
  Future<Map<String, dynamic>> getInfraStatus() async {
    return _get<Map<String, dynamic>>('/infra/status');
  }

  /// Get saved infrastructure config.
  Future<Map<String, dynamic>> getInfraConfig() async {
    return _get<Map<String, dynamic>>('/infra/config');
  }

  /// Save infrastructure configuration.
  Future<Map<String, dynamic>> saveInfraConfig(
    Map<String, dynamic> config,
  ) async {
    return _put<Map<String, dynamic>>('/infra/config', body: config);
  }

  /// Request server restart.
  Future<Map<String, dynamic>> requestRestart({
    List<String>? profiles,
    List<String>? profilesToRemove,
  }) async {
    return _post<Map<String, dynamic>>('/infra/restart', body: {
      'profiles': ?profiles,
      'profilesToRemove': ?profilesToRemove,
    });
  }

  /// Get available engines.
  Future<List<Map<String, dynamic>>> getEngines() async {
    final data = await _get<List<dynamic>>('/infra/engines');
    return data.cast<Map<String, dynamic>>();
  }

  // ── Channels ─────────────────────────────────────────────────────────────

  /// Get subscribed channels/newsletters.
  Future<List<Map<String, dynamic>>> getChannels(String sessionId) async {
    final data = await _get<List<dynamic>>(
      '/sessions/$sessionId/channels',
    );
    return data.cast<Map<String, dynamic>>();
  }

  /// Get channel messages.
  Future<List<Map<String, dynamic>>> getChannelMessages(
    String sessionId,
    String channelId, {
    int? limit,
  }) async {
    final query = limit != null ? '?limit=$limit' : '';
    final data = await _get<List<dynamic>>(
      '/sessions/$sessionId/channels/${Uri.encodeComponent(channelId)}/messages$query',
    );
    return data.cast<Map<String, dynamic>>();
  }

  // ── Catalog ──────────────────────────────────────────────────────────────

  /// Get business catalog.
  Future<Map<String, dynamic>> getCatalog(String sessionId) async {
    return _get<Map<String, dynamic>>('/sessions/$sessionId/catalog');
  }

  /// Get catalog products.
  Future<List<Map<String, dynamic>>> getCatalogProducts(
    String sessionId, {
    int? page,
    int? limit,
  }) async {
    final params = <String>[];
    if (page != null) params.add('page=$page');
    if (limit != null) params.add('limit=$limit');
    final query = params.isNotEmpty ? '?${params.join('&')}' : '';
    final data = await _get<List<dynamic>>(
      '/sessions/$sessionId/catalog/products$query',
    );
    return data.cast<Map<String, dynamic>>();
  }

  // ── Status Updates ───────────────────────────────────────────────────────

  /// Get all status updates.
  Future<Map<String, dynamic>> getStatuses(String sessionId) async {
    return _get<Map<String, dynamic>>('/sessions/$sessionId/status');
  }

  /// Post a text status.
  Future<Map<String, dynamic>> postTextStatus(
    String sessionId,
    String text, {
    String? backgroundColor,
    int? font,
  }) async {
    final body = <String, dynamic>{'text': text};
    if (backgroundColor != null) body['backgroundColor'] = backgroundColor;
    if (font != null) body['font'] = font;
    return _post<Map<String, dynamic>>(
      '/sessions/$sessionId/status/send-text',
      body: body,
    );
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
