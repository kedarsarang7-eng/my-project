// ============================================================================
// Payment Gateway API Service — Desktop ↔ Backend Integration
// ============================================================================
// Communicates with the new multi-tenant payment backend endpoints:
//   - /payment-config     (merchant onboarding)
//   - /payment/initiate   (QR generation)
//   - /payment/status     (status polling)
//   - /payment/reconcile  (offline recovery)
//
// SECURITY:
//   - All requests use Cognito JWT (via ApiClient auto-auth)
//   - NO payment secrets are ever stored on the desktop
//   - QR payloads come from the server (gateway-generated)
// ============================================================================

import 'dart:async';
import '../../../core/api/api_client.dart';
import '../../../core/services/logger_service.dart';

/// Supported payment gateway types (matches backend enum)
enum GatewayType {
  phonepe('phonepe'),
  razorpay('razorpay');

  const GatewayType(this.value);
  final String value;
}

/// Gateway configuration status
enum GatewayConfigStatus {
  pendingVerification('pending_verification'),
  active('active'),
  inactive('inactive'),
  failed('failed');

  const GatewayConfigStatus(this.value);
  final String value;

  static GatewayConfigStatus fromString(String s) {
    return GatewayConfigStatus.values.firstWhere(
      (e) => e.value == s,
      orElse: () => GatewayConfigStatus.pendingVerification,
    );
  }
}

/// Payment order status
enum PaymentOrderStatus {
  created('created'),
  qrGenerated('qr_generated'),
  pending('pending'),
  success('success'),
  failed('failed'),
  expired('expired'),
  refunded('refunded');

  const PaymentOrderStatus(this.value);
  final String value;

  static PaymentOrderStatus fromString(String s) {
    return PaymentOrderStatus.values.firstWhere(
      (e) => e.value == s,
      orElse: () => PaymentOrderStatus.pending,
    );
  }

  bool get isFinal =>
      this == success || this == failed || this == expired || this == refunded;
}

// ── Data Models ─────────────────────────────────────────────────────────────

/// Gateway configuration (returned from backend — no secrets)
class GatewayConfig {
  final String id;
  final String tenantId;
  final GatewayType gatewayType;
  final GatewayConfigStatus status;
  final String? displayName;
  final bool isDefault;
  final DateTime? verifiedAt;
  final DateTime createdAt;

  GatewayConfig({
    required this.id,
    required this.tenantId,
    required this.gatewayType,
    required this.status,
    this.displayName,
    this.isDefault = false,
    this.verifiedAt,
    required this.createdAt,
  });

  factory GatewayConfig.fromJson(Map<String, dynamic> json) {
    return GatewayConfig(
      id: json['id'] as String,
      tenantId: json['tenantId'] as String,
      gatewayType: GatewayType.values.firstWhere(
        (e) => e.value == json['gatewayType'],
        orElse: () => GatewayType.phonepe,
      ),
      status: GatewayConfigStatus.fromString(json['status'] as String),
      displayName: json['displayName'] as String?,
      isDefault: json['isDefault'] as bool? ?? false,
      verifiedAt: json['verifiedAt'] != null
          ? DateTime.parse(json['verifiedAt'] as String)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// Whether this config is ready for payment processing
  bool get isActive => status == GatewayConfigStatus.active;
}

/// Payment order result (QR code data)
class PaymentOrderResult {
  final String orderId;
  final String gatewayOrderId;
  final String? qrPayload;
  final String? paymentUrl;
  final DateTime? expiresAt;
  final PaymentOrderStatus status;

  PaymentOrderResult({
    required this.orderId,
    required this.gatewayOrderId,
    this.qrPayload,
    this.paymentUrl,
    this.expiresAt,
    required this.status,
  });

  factory PaymentOrderResult.fromJson(Map<String, dynamic> json) {
    return PaymentOrderResult(
      orderId: json['orderId'] as String,
      gatewayOrderId: json['gatewayOrderId'] as String,
      qrPayload: json['qrPayload'] as String?,
      paymentUrl: json['paymentUrl'] as String?,
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      status: PaymentOrderStatus.fromString(json['status'] as String),
    );
  }
}

/// Payment order status (for polling)
class PaymentOrderStatusResult {
  final String orderId;
  final String invoiceId;
  final GatewayType gatewayType;
  final PaymentOrderStatus status;
  final int amountCents;
  final String? qrPayload;
  final String? gatewayTransactionId;
  final DateTime? expiresAt;

  PaymentOrderStatusResult({
    required this.orderId,
    required this.invoiceId,
    required this.gatewayType,
    required this.status,
    required this.amountCents,
    this.qrPayload,
    this.gatewayTransactionId,
    this.expiresAt,
  });

  factory PaymentOrderStatusResult.fromJson(Map<String, dynamic> json) {
    return PaymentOrderStatusResult(
      orderId: json['orderId'] as String,
      invoiceId: json['invoiceId'] as String,
      gatewayType: GatewayType.values.firstWhere(
        (e) => e.value == json['gatewayType'],
        orElse: () => GatewayType.phonepe,
      ),
      status: PaymentOrderStatus.fromString(json['status'] as String),
      amountCents: json['amountCents'] as int,
      qrPayload: json['qrPayload'] as String?,
      gatewayTransactionId: json['gatewayTransactionId'] as String?,
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
    );
  }

  /// Amount in rupees
  double get amountRupees => amountCents / 100;
}

// ── API Service ─────────────────────────────────────────────────────────────

/// Payment Gateway API Service
///
/// Handles all communication with the multi-tenant payment backend.
/// Uses [ApiClient] for HTTP requests with auto JWT authentication.
class PaymentGatewayApiService {
  final ApiClient _apiClient;

  PaymentGatewayApiService(this._apiClient);

  // ── Gateway Config (Merchant Onboarding) ────────────────────────────────

  /// Save gateway credentials (Owner/Admin only).
  /// Credentials are KMS-encrypted on the backend.
  Future<GatewayConfig> savePhonePeConfig({
    required String merchantId,
    required String saltKey,
    required String saltIndex,
    String? webhookSecret,
    String? displayName,
  }) async {
    final response = await _apiClient.post(
      '/payment-config',
      body: {
        'gatewayType': 'phonepe',
        'merchantId': merchantId,
        'saltKey': saltKey,
        'saltIndex': saltIndex,
        ...{'webhookSecret': webhookSecret},
        ...{'displayName': displayName},
      },
    );
    _assertSuccess(response, 'savePhonePeConfig');
    return GatewayConfig.fromJson(
      response.data!['data'] as Map<String, dynamic>,
    );
  }

  /// Save Razorpay gateway credentials (Owner/Admin only).
  Future<GatewayConfig> saveRazorpayConfig({
    required String keyId,
    required String keySecret,
    required String webhookSecret,
    String? displayName,
  }) async {
    final response = await _apiClient.post(
      '/payment-config',
      body: {
        'gatewayType': 'razorpay',
        'keyId': keyId,
        'keySecret': keySecret,
        'webhookSecret': webhookSecret,
        ...(displayName == null
            ? const <String, dynamic>{}
            : <String, dynamic>{'displayName': displayName}),
      },
    );
    _assertSuccess(response, 'saveRazorpayConfig');
    return GatewayConfig.fromJson(
      response.data!['data'] as Map<String, dynamic>,
    );
  }

  /// Get all gateway configs for the current tenant (no secrets returned).
  Future<List<GatewayConfig>> getGatewayConfigs() async {
    final response = await _apiClient.get('/payment-config');
    _assertSuccess(response, 'getGatewayConfigs');

    final list = response.data!['data'] as List<dynamic>;
    return list
        .map((e) => GatewayConfig.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Verify and activate gateway credentials.
  /// Makes a test API call to the gateway to validate credentials.
  Future<GatewayConfig> verifyGatewayConfig(GatewayType gatewayType) async {
    final response = await _apiClient.post(
      '/payment-config/verify',
      body: {'gatewayType': gatewayType.value},
    );
    _assertSuccess(response, 'verifyGatewayConfig');
    return GatewayConfig.fromJson(
      response.data!['data'] as Map<String, dynamic>,
    );
  }

  /// Delete a gateway config.
  Future<void> deleteGatewayConfig(GatewayType gatewayType) async {
    final response = await _apiClient.delete(
      '/payment-config/${gatewayType.value}',
    );
    _assertSuccess(response, 'deleteGatewayConfig');
  }

  // ── Payment Initiation (QR Generation) ──────────────────────────────────

  /// Initiate a payment order and generate QR code.
  /// The backend handles gateway selection, credential decryption, and QR generation.
  ///
  /// [invoiceId] — the invoice/transaction UUID
  /// [gatewayType] — optional; auto-selects if only one gateway is active
  Future<PaymentOrderResult> initiatePayment({
    required String invoiceId,
    GatewayType? gatewayType,
  }) async {
    final response = await _apiClient.post(
      '/payment/initiate',
      body: {
        'invoiceId': invoiceId,
        if (gatewayType != null) 'gatewayType': gatewayType.value,
      },
    );
    _assertSuccess(response, 'initiatePayment');
    return PaymentOrderResult.fromJson(
      response.data!['data'] as Map<String, dynamic>,
    );
  }

  /// Get payment order status (by order ID or invoice ID).
  Future<PaymentOrderStatusResult?> getPaymentStatus({
    String? orderId,
    String? invoiceId,
  }) async {
    assert(orderId != null || invoiceId != null);

    final queryParams = <String, String>{};
    if (orderId != null) queryParams['orderId'] = orderId;
    if (invoiceId != null) queryParams['invoiceId'] = invoiceId;

    final response = await _apiClient.get(
      '/payment/status',
      queryParams: queryParams,
    );

    if (response.statusCode == 404) return null;
    _assertSuccess(response, 'getPaymentStatus');

    return PaymentOrderStatusResult.fromJson(
      response.data!['data'] as Map<String, dynamic>,
    );
  }

  /// Poll for payment completion with exponential backoff.
  /// Returns when payment reaches a final status (success/failed/expired).
  ///
  /// [onStatusUpdate] is called with each poll result for UI updates.
  /// [maxPollDuration] limits total polling time (default 5 minutes).
  Future<PaymentOrderStatusResult> pollPaymentStatus({
    required String orderId,
    Duration pollInterval = const Duration(seconds: 3),
    Duration maxPollDuration = const Duration(minutes: 5),
    void Function(PaymentOrderStatusResult)? onStatusUpdate,
  }) async {
    final stopwatch = Stopwatch()..start();
    Duration currentInterval = pollInterval;

    while (stopwatch.elapsed < maxPollDuration) {
      await Future.delayed(currentInterval);

      final result = await getPaymentStatus(orderId: orderId);
      if (result == null) {
        throw Exception('Payment order not found');
      }

      onStatusUpdate?.call(result);

      if (result.status.isFinal) {
        return result;
      }

      // Exponential backoff capped at 10 seconds
      currentInterval = Duration(
        milliseconds: (currentInterval.inMilliseconds * 1.5).toInt().clamp(
          pollInterval.inMilliseconds,
          10000,
        ),
      );
    }

    throw TimeoutException(
      'Payment status polling timed out after ${maxPollDuration.inMinutes} minutes',
    );
  }

  // ── Reconciliation ────────────────────────────────────────────────────────

  /// Reconcile pending payment orders by polling the gateway.
  /// Used when webhook delivery fails or desktop was offline.
  Future<Map<String, dynamic>> reconcilePayments() async {
    final response = await _apiClient.post('/payment/reconcile');
    _assertSuccess(response, 'reconcilePayments');
    return response.data!['data'] as Map<String, dynamic>;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _assertSuccess(ApiResponse response, String method) {
    if (!response.isSuccess) {
      final errorMsg = response.data?['error']?['message'] ?? 'Unknown error';
      LoggerService.d('PaymentGateway', 'PaymentGatewayApiService.$method failed: $errorMsg');
      throw ApiException(
        message: errorMsg.toString(),
        statusCode: response.statusCode,
        url: method,
      );
    }
  }
}
