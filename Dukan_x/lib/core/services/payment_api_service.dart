// ignore_for_file: dead_code
// ignore_for_file: unused_field
// ============================================================================
// PaymentApiService - Razorpay Payment Integration for DukanX
// Handles QR generation, status polling, cash payments, and merchant onboarding
// ============================================================================

import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

// ============================================================================
// Data Models
// ============================================================================

enum PaymentMode { cash, upi, online, card }

enum PaymentStatus { pending, paid, failed, expired, duplicate }

class PaymentQrResponse {
  final bool success;
  final String qrImageUrl;
  final String orderId;
  final String qrId;
  final DateTime expiresAt;
  final double amount;
  final String currency;

  PaymentQrResponse({
    required this.success,
    required this.qrImageUrl,
    required this.orderId,
    required this.qrId,
    required this.expiresAt,
    required this.amount,
    this.currency = 'INR',
  });

  factory PaymentQrResponse.fromJson(Map<String, dynamic> json) {
    return PaymentQrResponse(
      success: json['success'] ?? false,
      qrImageUrl: json['qrImageUrl'] ?? '',
      orderId: json['orderId'] ?? '',
      qrId: json['qrId'] ?? '',
      expiresAt: DateTime.parse(json['expiresAt'] ?? DateTime.now().toIso8601String()),
      amount: (json['amount'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'INR',
    );
  }

  Map<String, dynamic> toJson() => {
    'success': success,
    'qrImageUrl': qrImageUrl,
    'orderId': orderId,
    'qrId': qrId,
    'expiresAt': expiresAt.toIso8601String(),
    'amount': amount,
    'currency': currency,
  };
}

class PaymentStatusResponse {
  final bool success;
  final String billId;
  final PaymentStatus status;
  final double amount;
  final bool? paid;
  final DateTime? paidAt;
  final String? paymentId;
  final String? paymentMode;
  final String? paymentMethod;
  final String? failureReason;
  final String? failureCode;
  final DateTime? qrExpiresAt;

  PaymentStatusResponse({
    required this.success,
    required this.billId,
    required this.status,
    required this.amount,
    this.paid,
    this.paidAt,
    this.paymentId,
    this.paymentMode,
    this.paymentMethod,
    this.failureReason,
    this.failureCode,
    this.qrExpiresAt,
  });

  factory PaymentStatusResponse.fromJson(Map<String, dynamic> json) {
    return PaymentStatusResponse(
      success: json['success'] ?? false,
      billId: json['billId'] ?? '',
      status: _parsePaymentStatus(json['status']),
      amount: (json['amount'] ?? 0).toDouble(),
      paid: json['paid'],
      paidAt: json['paidAt'] != null ? DateTime.parse(json['paidAt']) : null,
      paymentId: json['paymentId'],
      paymentMode: json['paymentMode'],
      paymentMethod: json['paymentMethod'],
      failureReason: json['failureReason'],
      failureCode: json['failureCode'],
      qrExpiresAt: json['qrExpiresAt'] != null ? DateTime.parse(json['qrExpiresAt']) : null,
    );
  }

  static PaymentStatus _parsePaymentStatus(String? status) {
    switch (status?.toUpperCase()) {
      case 'PAID': return PaymentStatus.paid;
      case 'FAILED': return PaymentStatus.failed;
      case 'EXPIRED': return PaymentStatus.expired;
      case 'DUPLICATE': return PaymentStatus.duplicate;
      case 'PENDING':
      default: return PaymentStatus.pending;
    }
  }
}

class CashPaymentRequest {
  final String billId;
  final String businessId;
  final double amountReceived;
  final double? changeGiven;
  final String staffId;
  final String? notes;

  CashPaymentRequest({
    required this.billId,
    required this.businessId,
    required this.amountReceived,
    this.changeGiven,
    required this.staffId,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
    'billId': billId,
    'businessId': businessId,
    'amountReceived': amountReceived,
    'changeGiven': changeGiven,
    'staffId': staffId,
    'notes': notes,
  };
}

class CashPaymentResponse {
  final bool success;
  final String billId;
  final String paymentId;
  final PaymentStatus status;
  final double amount;
  final double change;
  final DateTime paidAt;

  CashPaymentResponse({
    required this.success,
    required this.billId,
    required this.paymentId,
    required this.status,
    required this.amount,
    required this.change,
    required this.paidAt,
  });

  factory CashPaymentResponse.fromJson(Map<String, dynamic> json) {
    return CashPaymentResponse(
      success: json['success'] ?? false,
      billId: json['billId'] ?? '',
      paymentId: json['paymentId'] ?? '',
      status: PaymentStatusResponse.fromJson(json).status,
      amount: (json['amount'] ?? 0).toDouble(),
      change: (json['change'] ?? 0).toDouble(),
      paidAt: DateTime.parse(json['paidAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class MerchantOnboardingRequest {
  final String businessId;
  final String ownerId;
  final String businessName;
  final String businessType;
  final String email;
  final String phone;
  final String legalName;
  final String? gstNumber;
  final String? bankAccountNumber;
  final String? ifscCode;

  MerchantOnboardingRequest({
    required this.businessId,
    required this.ownerId,
    required this.businessName,
    required this.businessType,
    required this.email,
    required this.phone,
    required this.legalName,
    this.gstNumber,
    this.bankAccountNumber,
    this.ifscCode,
  });

  Map<String, dynamic> toJson() => {
    'businessId': businessId,
    'ownerId': ownerId,
    'businessName': businessName,
    'businessType': businessType,
    'email': email,
    'phone': phone,
    'legalName': legalName,
    'gstNumber': gstNumber,
    'bankAccountNumber': bankAccountNumber,
    'ifscCode': ifscCode,
  };
}

class MerchantOnboardingResponse {
  final bool success;
  final String? linkedAccountId;
  final String? accountStatus;
  final String message;
  final String businessId;

  MerchantOnboardingResponse({
    required this.success,
    this.linkedAccountId,
    this.accountStatus,
    required this.message,
    required this.businessId,
  });

  factory MerchantOnboardingResponse.fromJson(Map<String, dynamic> json) {
    return MerchantOnboardingResponse(
      success: json['success'] ?? false,
      linkedAccountId: json['linkedAccountId'],
      accountStatus: json['accountStatus'],
      message: json['message'] ?? '',
      businessId: json['businessId'] ?? '',
    );
  }
}

// ============================================================================
// Exceptions
// ============================================================================

class PaymentApiException implements Exception {
  final String message;
  final String? code;
  final int? statusCode;

  PaymentApiException(this.message, {this.code, this.statusCode});

  @override
  String toString() => 'PaymentApiException: $message (code: $code, status: $statusCode)';
}

class PaymentAlreadyPaidException extends PaymentApiException {
  PaymentAlreadyPaidException() : super('Bill is already paid', code: 'ALREADY_PAID', statusCode: 409);
}

class MerchantNotOnboardedException extends PaymentApiException {
  MerchantNotOnboardedException() : super('Merchant not onboarded to Razorpay', code: 'MERCHANT_NOT_ONBOARDED', statusCode: 400);
}

class BillNotFoundException extends PaymentApiException {
  BillNotFoundException() : super('Bill not found', code: 'BILL_NOT_FOUND', statusCode: 404);
}

class QRExpiredException extends PaymentApiException {
  QRExpiredException() : super('QR code has expired', code: 'QR_EXPIRED');
}

class PaymentFailedException extends PaymentApiException {
  PaymentFailedException(super.reason, {String? code}) : super(code: code ?? 'PAYMENT_FAILED');
}

// ============================================================================
// PaymentApiService
// ============================================================================

class PaymentApiService {
  final Dio _dio;
  final String _baseUrl;

  PaymentApiService({
    required String baseUrl,
    String? authToken,
    Dio? dio,
  })  : _baseUrl = baseUrl,
        _dio = dio ?? _createDio(baseUrl, authToken);

  static Dio _createDio(String baseUrl, String? authToken) {
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        if (authToken != null) 'Authorization': 'Bearer $authToken',
      },
    ));

    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
      ));
    }

    return dio;
  }

  void updateAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  // -------------------------------------------------------------------------
  // Merchant Onboarding
  // -------------------------------------------------------------------------
  Future<MerchantOnboardingResponse> onboardMerchant(MerchantOnboardingRequest request) async {
    try {
      final response = await _dio.post(
        '/billing/merchants/onboard',
        data: request.toJson(),
      );

      return MerchantOnboardingResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // -------------------------------------------------------------------------
  // Generate Payment QR
  // -------------------------------------------------------------------------
  Future<PaymentQrResponse> generatePaymentQR({
    required String billId,
    required String businessId,
    required double amount,
    required String invoiceNumber,
    String? customerName,
    String? customerPhone,
    String? description,
  }) async {
    try {
      final response = await _dio.post(
        '/billing/payment/generate-qr',
        data: {
          'billId': billId,
          'businessId': businessId,
          'amount': amount,
          'invoiceNumber': invoiceNumber,
          'customerName': ?customerName,
          'customerPhone': ?customerPhone,
          'description': ?description,
        },
      );

      return PaymentQrResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // -------------------------------------------------------------------------
  // Get Payment Status (Single Poll)
  // -------------------------------------------------------------------------
  Future<PaymentStatusResponse> getPaymentStatus(String billId) async {
    try {
      final response = await _dio.get('/billing/payment/status/$billId');

      return PaymentStatusResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // -------------------------------------------------------------------------
  // Poll Payment Status (Continuous with Callback)
  // -------------------------------------------------------------------------
  Stream<PaymentStatusResponse> pollPaymentStatus({
    required String billId,
    Duration interval = const Duration(seconds: 3),
    Duration timeout = const Duration(minutes: 10),
  }) async* {
    final stopwatch = Stopwatch()..start();
    Timer? timer;

    try {
      while (stopwatch.elapsed < timeout) {
        final status = await getPaymentStatus(billId);
        yield status;

        // Stop polling if payment is resolved
        if (status.status == PaymentStatus.paid ||
            status.status == PaymentStatus.failed ||
            status.status == PaymentStatus.expired) {
          break;
        }

        // Wait before next poll
        await Future.delayed(interval);
      }
    } finally {
      timer?.cancel();
      stopwatch.stop();
    }
  }

  // -------------------------------------------------------------------------
  // Process Cash Payment
  // -------------------------------------------------------------------------
  Future<CashPaymentResponse> processCashPayment(CashPaymentRequest request) async {
    try {
      final response = await _dio.post(
        '/billing/payment/cash',
        data: request.toJson(),
      );

      return CashPaymentResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // -------------------------------------------------------------------------
  // Error Handling
  // -------------------------------------------------------------------------
  PaymentApiException _handleDioError(DioException error) {
    final response = error.response;
    final statusCode = response?.statusCode;
    final data = response?.data as Map<String, dynamic>?;
    final errorCode = data?['errorCode'] as String?;
    final message = data?['error'] ?? error.message ?? 'Unknown error';

    switch (errorCode) {
      case 'ALREADY_PAID':
        return PaymentAlreadyPaidException();
      case 'MERCHANT_NOT_ONBOARDED':
        return MerchantNotOnboardedException();
      case 'BILL_NOT_FOUND':
        return BillNotFoundException();
      case 'QR_EXPIRED':
        return QRExpiredException();
      case 'PAYMENT_FAILED':
        return PaymentFailedException(message, code: errorCode);
      default:
        return PaymentApiException(
          message,
          code: errorCode ?? 'UNKNOWN_ERROR',
          statusCode: statusCode,
        );
    }
  }
}
