// ============================================================================
// OpenWA Provisioning API Service — Desktop ↔ Backend Integration
// ============================================================================
// Communicates with the backend's OpenWA provisioning endpoints:
//   - POST   /whatsapp/provisioning         (save credentials)
//   - GET    /whatsapp/provisioning         (get status, no secrets)
//   - POST   /whatsapp/provisioning/verify  (verify + activate)
//   - DELETE /whatsapp/provisioning         (remove credentials)
//
// SECURITY:
//   - All requests use Cognito JWT (via ApiClient auto-auth)
//   - apiKey / webhookSecret are write-only — never returned by the backend
//     and never persisted locally on the desktop
//
// Mirrors payment_gateway_api_service.dart exactly (model classes with
// fromJson, ApiClient-based service, _assertSuccess helper).
// ============================================================================

import '../../../core/api/api_client.dart';
import '../../../core/services/logger_service.dart';

/// Provisioning lifecycle status (matches backend `OpenWaProvisioningStatus`).
enum OpenWaProvisioningStatus {
  pendingVerification('pending_verification'),
  active('active'),
  inactive('inactive'),
  failed('failed');

  const OpenWaProvisioningStatus(this.value);
  final String value;

  static OpenWaProvisioningStatus fromString(String s) {
    return OpenWaProvisioningStatus.values.firstWhere(
      (e) => e.value == s,
      orElse: () => OpenWaProvisioningStatus.pendingVerification,
    );
  }
}

/// OpenWA provisioning config (returned from backend — no secrets).
class OpenWaProvisioningConfig {
  final String id;
  final String businessId;
  final String sessionId;
  final String baseUrl;
  final OpenWaProvisioningStatus status;
  final String? displayName;
  final bool webhookRegistered;
  final String? lastError;
  final DateTime? verifiedAt;
  final DateTime createdAt;

  OpenWaProvisioningConfig({
    required this.id,
    required this.businessId,
    required this.sessionId,
    required this.baseUrl,
    required this.status,
    this.displayName,
    this.webhookRegistered = false,
    this.lastError,
    this.verifiedAt,
    required this.createdAt,
  });

  factory OpenWaProvisioningConfig.fromJson(Map<String, dynamic> json) {
    return OpenWaProvisioningConfig(
      id: json['id'] as String,
      businessId: json['businessId'] as String,
      sessionId: json['sessionId'] as String,
      baseUrl: json['baseUrl'] as String,
      status: OpenWaProvisioningStatus.fromString(json['status'] as String),
      displayName: json['displayName'] as String?,
      webhookRegistered: json['webhookRegistered'] as bool? ?? false,
      lastError: json['lastError'] as String?,
      verifiedAt: json['verifiedAt'] != null
          ? DateTime.parse(json['verifiedAt'] as String)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  bool get isActive => status == OpenWaProvisioningStatus.active;
}

/// OpenWA Provisioning API Service.
///
/// Handles all communication with the backend's OpenWA credential
/// provisioning endpoints. Uses [ApiClient] for HTTP requests with
/// automatic JWT authentication.
class OpenwaProvisioningApiService {
  final ApiClient _apiClient;

  OpenwaProvisioningApiService(this._apiClient);

  /// Save OpenWA gateway credentials (Owner/Admin only).
  /// Leaves the config in `pending_verification` — call [verifyConfig] next.
  Future<OpenWaProvisioningConfig> saveConfig({
    required String baseUrl,
    required String apiKey,
    required String sessionId,
    required String webhookSecret,
    String? displayName,
  }) async {
    final response = await _apiClient.post(
      '/whatsapp/provisioning',
      body: {
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'sessionId': sessionId,
        'webhookSecret': webhookSecret,
        if (displayName != null && displayName.isNotEmpty)
          'displayName': displayName,
      },
    );
    _assertSuccess(response, 'saveConfig');
    return OpenWaProvisioningConfig.fromJson(
      response.data!['data'] as Map<String, dynamic>,
    );
  }

  /// Get the current provisioning status for the authenticated business.
  /// Returns null if no config has been saved yet (404).
  Future<OpenWaProvisioningConfig?> getConfig() async {
    final response = await _apiClient.get('/whatsapp/provisioning');
    if (response.statusCode == 404) return null;
    _assertSuccess(response, 'getConfig');
    return OpenWaProvisioningConfig.fromJson(
      response.data!['data'] as Map<String, dynamic>,
    );
  }

  /// Verify the saved credentials against the real OpenWA gateway, register
  /// the delivery webhook, and activate the config.
  Future<OpenWaProvisioningConfig> verifyConfig() async {
    final response = await _apiClient.post('/whatsapp/provisioning/verify');
    _assertSuccess(response, 'verifyConfig');
    return OpenWaProvisioningConfig.fromJson(
      response.data!['data'] as Map<String, dynamic>,
    );
  }

  /// Remove OpenWA credentials and the registered webhook.
  Future<void> deleteConfig() async {
    final response = await _apiClient.delete('/whatsapp/provisioning');
    _assertSuccess(response, 'deleteConfig');
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _assertSuccess(ApiResponse response, String method) {
    if (!response.isSuccess) {
      final errorMsg = response.data?['error']?['message'] ?? 'Unknown error';
      LoggerService.d(
        'OpenwaProvisioning',
        'OpenwaProvisioningApiService.$method failed: $errorMsg',
      );
      throw ApiException(
        message: errorMsg.toString(),
        statusCode: response.statusCode,
        url: method,
      );
    }
  }
}
