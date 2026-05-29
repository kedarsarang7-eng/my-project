import 'dart:async';

import '../../../core/network/api_client.dart';

/// QR Payment response from backend
class QRPaymentResponse {
  final String orderId;
  final String transactionId;
  final int amountPaise;
  final String qrImageUrl;
  final String status;
  final DateTime expiresAt;
  final Map<String, dynamic> rawResponse;

  QRPaymentResponse({
    required this.orderId,
    required this.transactionId,
    required this.amountPaise,
    required this.qrImageUrl,
    required this.status,
    required this.expiresAt,
    required this.rawResponse,
  });

  factory QRPaymentResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;
    
    // Parse expiry time - backend sends TTL or ISO string
    DateTime expiresAt;
    final expiryRaw = data['expiresAt'] ?? data['pendingTTL'];
    if (expiryRaw is int) {
      // Unix timestamp
      expiresAt = DateTime.fromMillisecondsSinceEpoch(expiryRaw * 1000);
    } else if (expiryRaw is String) {
      expiresAt = DateTime.tryParse(expiryRaw) ?? DateTime.now().add(const Duration(minutes: 10));
    } else {
      // Default 10 minutes
      expiresAt = DateTime.now().add(const Duration(minutes: 10));
    }

    return QRPaymentResponse(
      orderId: data['orderId']?.toString() ?? '',
      transactionId: data['transactionId']?.toString() ?? '',
      amountPaise: (data['amount'] ?? 0).toInt(),
      qrImageUrl: data['qrImageUrl']?.toString() ?? '',
      status: data['status']?.toString() ?? 'PENDING',
      expiresAt: expiresAt,
      rawResponse: json,
    );
  }

  /// Get amount in rupees (convert from paise)
  double get amountRupees => amountPaise / 100;

  /// Check if QR has expired
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Get remaining seconds before expiry
  int get remainingSeconds {
    final diff = expiresAt.difference(DateTime.now());
    return diff.inSeconds.clamp(0, 600); // Max 10 minutes
  }
}

/// Payment status response
class PaymentStatusResponse {
  final String orderId;
  final String transactionId;
  final String status;
  final int amountPaise;
  final DateTime? paidAt;
  final String? paymentMethod;
  final Map<String, dynamic> rawResponse;

  PaymentStatusResponse({
    required this.orderId,
    required this.transactionId,
    required this.status,
    required this.amountPaise,
    this.paidAt,
    this.paymentMethod,
    required this.rawResponse,
  });

  factory PaymentStatusResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;
    
    DateTime? paidAt;
    final paidAtRaw = data['paidAt'] ?? data['completedAt'];
    if (paidAtRaw is int) {
      paidAt = DateTime.fromMillisecondsSinceEpoch(paidAtRaw * 1000);
    } else if (paidAtRaw is String) {
      paidAt = DateTime.tryParse(paidAtRaw);
    }

    return PaymentStatusResponse(
      orderId: data['orderId']?.toString() ?? '',
      transactionId: data['transactionId']?.toString() ?? '',
      status: data['status']?.toString() ?? 'UNKNOWN',
      amountPaise: (data['amount'] ?? 0).toInt(),
      paidAt: paidAt,
      paymentMethod: data['paymentMethod']?.toString(),
      rawResponse: json,
    );
  }

  double get amountRupees => amountPaise / 100;
  bool get isSuccess => status == 'SUCCESS' || status == 'PAID';
  bool get isFailed => status == 'FAILED' || status == 'CANCELLED';
  bool get isPending => status == 'PENDING' || status == 'CREATED';
}

/// Repository for QR Payment operations
class QRPaymentRepository {
  final ApiClient _apiClient = ApiClient();

  /// Generate QR code for payment
  /// [amountRupees] - Amount in rupees (will be converted to paise)
  /// [stationId] - Station ID for tenant isolation
  /// Returns QRPaymentResponse with orderId, transactionId, and QR image URL
  Future<QRPaymentResponse> generateQR({
    required double amountRupees,
    required String stationId,
    String? staffId,
    String? description,
  }) async {
    // Convert rupees to paise (backend expects paise)
    final amountPaise = (amountRupees * 100).round();

    final response = await _apiClient.post(
      '/qr/generate', // Note: Add to ApiEndpoints if not present
      data: {
        'amount': amountPaise,
        'stationId': stationId,
        if (staffId != null) 'staffId': staffId,
        if (description != null) 'description': description,
        'currency': 'INR',
      },
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return QRPaymentResponse.fromJson(response.data);
    } else {
      throw Exception(response.data['error'] ?? 'Failed to generate QR code');
    }
  }

  /// Check payment status
  /// [orderId] - The order ID returned from generateQR
  /// Returns PaymentStatusResponse with current status
  Future<PaymentStatusResponse> getPaymentStatus(String orderId) async {
    final response = await _apiClient.get('/payment/status/$orderId');

    if (response.statusCode == 200) {
      return PaymentStatusResponse.fromJson(response.data);
    } else {
      throw Exception(response.data['error'] ?? 'Failed to get payment status');
    }
  }

  /// Poll payment status until success/failure or timeout
  /// [orderId] - The order ID to poll
  /// [timeout] - Maximum time to poll (default 10 minutes)
  /// [interval] - Polling interval (default 3 seconds)
  /// Returns final status or throws on timeout
  Future<PaymentStatusResponse> pollPaymentStatus({
    required String orderId,
    Duration timeout = const Duration(minutes: 10),
    Duration interval = const Duration(seconds: 3),
  }) async {
    final endTime = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(endTime)) {
      final status = await getPaymentStatus(orderId);
      
      // Stop polling if payment is complete
      if (status.isSuccess || status.isFailed) {
        return status;
      }

      // Wait before next poll
      await Future.delayed(interval);
    }

    throw TimeoutException('Payment status polling timed out after ${timeout.inMinutes} minutes');
  }

  /// Cancel a pending payment
  Future<void> cancelPayment(String orderId) async {
    final response = await _apiClient.post('/payment/cancel/$orderId');
    
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(response.data['error'] ?? 'Failed to cancel payment');
    }
  }
}

/// Exception for polling timeout
class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
  
  @override
  String toString() => 'TimeoutException: $message';
}
