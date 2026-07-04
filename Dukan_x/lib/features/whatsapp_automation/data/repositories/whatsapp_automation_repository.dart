// ============================================================================
// WhatsApp Automation Repository — API communication layer
// ============================================================================
// Uses ApiClient (via DI) to call /whatsapp/* endpoints.
// Follows the same _assertSuccess pattern as PaymentGatewayApiService.
// ============================================================================

import '../../../../core/api/api_client.dart';
import '../../../../core/services/logger_service.dart';
import '../models/ai_responder_settings_model.dart';
import '../models/automation_config_model.dart';
import '../models/automation_rule_model.dart';
import '../models/audit_log_model.dart';
import '../models/delivery_log_model.dart';
import '../models/message_template_model.dart';
import '../models/whatsapp_customer_model.dart';

/// WhatsApp Automation Repository — handles all /whatsapp/* API calls.
class WhatsAppAutomationRepository {
  final ApiClient _apiClient;

  WhatsAppAutomationRepository(this._apiClient);

  // ── Config ──────────────────────────────────────────────────────────────────

  /// Get the automation config for the current business.
  Future<AutomationConfig?> getConfig() async {
    final response = await _apiClient.get('/whatsapp/config');
    if (response.statusCode == 404) return null;
    _assertSuccess(response, 'getConfig');
    return AutomationConfig.fromJson(
      response.data!['data'] as Map<String, dynamic>,
    );
  }

  /// Update the automation config.
  Future<AutomationConfig> updateConfig(Map<String, dynamic> updates) async {
    final response = await _apiClient.put('/whatsapp/config', body: updates);
    _assertSuccess(response, 'updateConfig');
    return AutomationConfig.fromJson(
      response.data!['data'] as Map<String, dynamic>,
    );
  }

  // ── Templates ───────────────────────────────────────────────────────────────

  /// Get all message templates.
  Future<List<MessageTemplate>> getTemplates() async {
    final response = await _apiClient.get('/whatsapp/templates');
    _assertSuccess(response, 'getTemplates');
    final list = response.data!['data'] as List<dynamic>;
    return list
        .map((e) => MessageTemplate.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Create a new message template.
  Future<MessageTemplate> createTemplate(Map<String, dynamic> body) async {
    final response = await _apiClient.post('/whatsapp/templates', body: body);
    _assertSuccess(response, 'createTemplate');
    return MessageTemplate.fromJson(
      response.data!['data'] as Map<String, dynamic>,
    );
  }

  /// Update an existing template.
  Future<MessageTemplate> updateTemplate(
    String templateId,
    Map<String, dynamic> updates,
  ) async {
    final response = await _apiClient.put(
      '/whatsapp/templates/$templateId',
      body: updates,
    );
    _assertSuccess(response, 'updateTemplate');
    return MessageTemplate.fromJson(
      response.data!['data'] as Map<String, dynamic>,
    );
  }

  /// Delete a template.
  Future<void> deleteTemplate(String templateId) async {
    final response = await _apiClient.delete('/whatsapp/templates/$templateId');
    _assertSuccess(response, 'deleteTemplate');
  }

  // ── Rules ───────────────────────────────────────────────────────────────────

  /// Get all automation rules.
  Future<List<AutomationRule>> getRules() async {
    final response = await _apiClient.get('/whatsapp/rules');
    _assertSuccess(response, 'getRules');
    final list = response.data!['data'] as List<dynamic>;
    return list
        .map((e) => AutomationRule.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Create a new automation rule.
  Future<AutomationRule> createRule(Map<String, dynamic> body) async {
    final response = await _apiClient.post('/whatsapp/rules', body: body);
    _assertSuccess(response, 'createRule');
    return AutomationRule.fromJson(
      response.data!['data'] as Map<String, dynamic>,
    );
  }

  /// Update an existing rule.
  Future<AutomationRule> updateRule(
    String ruleId,
    Map<String, dynamic> updates,
  ) async {
    final response = await _apiClient.put(
      '/whatsapp/rules/$ruleId',
      body: updates,
    );
    _assertSuccess(response, 'updateRule');
    return AutomationRule.fromJson(
      response.data!['data'] as Map<String, dynamic>,
    );
  }

  /// Delete a rule.
  Future<void> deleteRule(String ruleId) async {
    final response = await _apiClient.delete('/whatsapp/rules/$ruleId');
    _assertSuccess(response, 'deleteRule');
  }

  /// Enable a rule.
  Future<AutomationRule> enableRule(String ruleId) async {
    final response = await _apiClient.put(
      '/whatsapp/rules/$ruleId',
      body: {'enabled': true},
    );
    _assertSuccess(response, 'enableRule');
    return AutomationRule.fromJson(
      response.data!['data'] as Map<String, dynamic>,
    );
  }

  /// Disable a rule.
  Future<AutomationRule> disableRule(String ruleId) async {
    final response = await _apiClient.put(
      '/whatsapp/rules/$ruleId',
      body: {'enabled': false},
    );
    _assertSuccess(response, 'disableRule');
    return AutomationRule.fromJson(
      response.data!['data'] as Map<String, dynamic>,
    );
  }

  // ── Customers ───────────────────────────────────────────────────────────────

  /// Get all WhatsApp customers.
  Future<List<WhatsAppCustomer>> getCustomers() async {
    final response = await _apiClient.get('/whatsapp/customers');
    _assertSuccess(response, 'getCustomers');
    final list = response.data!['data'] as List<dynamic>;
    return list
        .map((e) => WhatsAppCustomer.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Create a new WhatsApp customer profile.
  Future<WhatsAppCustomer> createCustomer(Map<String, dynamic> body) async {
    final response = await _apiClient.post('/whatsapp/customers', body: body);
    _assertSuccess(response, 'createCustomer');
    return WhatsAppCustomer.fromJson(
      response.data!['data'] as Map<String, dynamic>,
    );
  }

  /// Update a customer profile.
  Future<WhatsAppCustomer> updateCustomer(
    String customerId,
    Map<String, dynamic> updates,
  ) async {
    final response = await _apiClient.put(
      '/whatsapp/customers/$customerId',
      body: updates,
    );
    _assertSuccess(response, 'updateCustomer');
    return WhatsAppCustomer.fromJson(
      response.data!['data'] as Map<String, dynamic>,
    );
  }

  /// Set consent state for a customer with an audit note.
  Future<WhatsAppCustomer> setConsent(
    String customerId,
    ConsentState consentState, {
    String? auditNote,
  }) async {
    final body = <String, dynamic>{'consentState': consentState.value};
    if (auditNote != null && auditNote.isNotEmpty) {
      body['auditNote'] = auditNote;
    }
    final response = await _apiClient.put(
      '/whatsapp/customers/$customerId',
      body: body,
    );
    _assertSuccess(response, 'setConsent');
    return WhatsAppCustomer.fromJson(
      response.data!['data'] as Map<String, dynamic>,
    );
  }

  // ── Logs ────────────────────────────────────────────────────────────────────

  /// Get delivery logs (read-only, append-only).
  Future<List<DeliveryLogEntry>> getDeliveryLogs({
    String? outboundMessageId,
    int? limit,
  }) async {
    final queryParams = <String, String>{};
    if (outboundMessageId != null) {
      queryParams['outboundMessageId'] = outboundMessageId;
    }
    if (limit != null) queryParams['limit'] = limit.toString();

    final response = await _apiClient.get(
      '/whatsapp/logs',
      queryParams: queryParams,
    );
    _assertSuccess(response, 'getDeliveryLogs');
    final list = response.data!['data'] as List<dynamic>;
    return list
        .map((e) => DeliveryLogEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Get audit logs (read-only, append-only).
  Future<List<AuditLogEntry>> getAuditLogs({int? limit}) async {
    final queryParams = <String, String>{};
    if (limit != null) queryParams['limit'] = limit.toString();

    final response = await _apiClient.get(
      '/whatsapp/logs/audit',
      queryParams: queryParams,
    );
    _assertSuccess(response, 'getAuditLogs');
    final list = response.data!['data'] as List<dynamic>;
    return list
        .map((e) => AuditLogEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── AI Responder ──────────────────────────────────────────────────────────

  /// Get AI responder settings. Returns null if not configured.
  Future<AiResponderSettings?> getAiResponderSettings() async {
    final response = await _apiClient.get('/whatsapp/ai-responder/settings');
    if (response.statusCode == 404) return null;
    _assertSuccess(response, 'getAiResponderSettings');
    return AiResponderSettings.fromJson(
      response.data!['data'] as Map<String, dynamic>,
    );
  }

  /// Update AI responder settings.
  Future<AiResponderSettings> updateAiResponderSettings(
    Map<String, dynamic> updates,
  ) async {
    final response = await _apiClient.put(
      '/whatsapp/ai-responder/settings',
      body: updates,
    );
    _assertSuccess(response, 'updateAiResponderSettings');
    return AiResponderSettings.fromJson(
      response.data!['data'] as Map<String, dynamic>,
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  void _assertSuccess(ApiResponse response, String method) {
    if (!response.isSuccess) {
      final errorMsg = response.data?['error']?['message'] ?? 'Unknown error';
      LoggerService.d(
        'WhatsAppAutomation',
        'WhatsAppAutomationRepository.$method failed: $errorMsg',
      );
      throw ApiException(
        message: errorMsg.toString(),
        statusCode: response.statusCode,
        url: method,
      );
    }
  }
}
