// ============================================================================
// PWA PAYMENT SERVICE — Razorpay Integration for Restaurant PWA
// ============================================================================
// Handles restaurant table payments via Razorpay SDK
// Flow: Create Order → Razorpay Checkout → Verify → WebSocket Confirmation
// ============================================================================

import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'pwa_api_service.dart';

class PwaPaymentService {
  static final PwaPaymentService _instance = PwaPaymentService._internal();
  late Razorpay _razorpay;
  bool _isInitialized = false;

  // Payment callback handlers
  Function(bool success, String message, String? paymentId)? _onPaymentResult;
  Map<String, dynamic> _currentPaymentContext = {};

  // API Configuration
  static const String _apiOrigin = String.fromEnvironment(
    'DUKANX_API_URL',
    defaultValue: 'https://api.dukanx.com',
  );
  static String get _base => '$_apiOrigin/api/v1/restaurant';
  static const _timeout = Duration(seconds: 15);

  PwaPaymentService._internal();

  factory PwaPaymentService() {
    return _instance;
  }

  Future<void> init() async {
    if (_isInitialized) return;
    
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    
    _isInitialized = true;
    developer.log('PwaPaymentService initialized', name: 'PwaPaymentService');
  }

  /// Check if online
  static Future<bool> _isOnline() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  /// Create payment order via backend
  Future<Map<String, dynamic>?> _createPaymentOrder({
    required String vendorId,
    required String tableId,
    required String orderId,
    required double amount,
    required String? customerName,
    required String? customerPhone,
  }) async {
    try {
      final token = await PwaApiService.ensureTableToken(
        vendorId: vendorId,
        tableId: tableId,
      );
      
      if (token == null) {
        developer.log('No auth token available', name: 'PwaPaymentService');
        return null;
      }

      final uri = Uri.parse('$_base/payment/create-order');
      final res = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'vendorId': vendorId,
              'tableId': tableId,
              'orderId': orderId,
              'amount': amount,
              'customerName': customerName,
              'customerPhone': customerPhone,
            }),
          )
          .timeout(_timeout);

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return data;
        }
      }
      
      developer.log('Create order failed: ${res.statusCode}', name: 'PwaPaymentService');
      return null;
    } catch (e) {
      developer.log('Create order error: $e', name: 'PwaPaymentService');
      return null;
    }
  }

  /// Verify payment with backend
  Future<bool> _verifyPayment({
    required String vendorId,
    required String tableId,
    required String razorpayPaymentId,
    required String razorpayOrderId,
    required String razorpaySignature,
  }) async {
    try {
      final token = await PwaApiService.ensureTableToken(
        vendorId: vendorId,
        tableId: tableId,
      );
      
      if (token == null) return false;

      final uri = Uri.parse('$_base/payment/verify');
      final res = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'vendorId': vendorId,
              'tableId': tableId,
              'razorpayPaymentId': razorpayPaymentId,
              'razorpayOrderId': razorpayOrderId,
              'razorpaySignature': razorpaySignature,
            }),
          )
          .timeout(_timeout);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return data['success'] == true;
      }
      
      return false;
    } catch (e) {
      developer.log('Verify payment error: $e', name: 'PwaPaymentService');
      return false;
    }
  }

  /// Initiate payment for restaurant order
  Future<void> initiatePayment({
    required String vendorId,
    required String tableId,
    required String orderId,
    required double amount,
    required String businessName,
    String? customerName,
    String? customerPhone,
    required Function(bool success, String message, String? paymentId) onResult,
  }) async {
    if (!await _isOnline()) {
      onResult(false, 'No internet connection. Please check your network.', null);
      return;
    }

    if (amount <= 0) {
      onResult(false, 'Invalid payment amount', null);
      return;
    }

    try {
      // Create order via backend
      final orderResponse = await _createPaymentOrder(
        vendorId: vendorId,
        tableId: tableId,
        orderId: orderId,
        amount: amount,
        customerName: customerName,
        customerPhone: customerPhone,
      );

      if (orderResponse == null) {
        onResult(false, 'Failed to create payment order. Please try again.', null);
        return;
      }

      // Store context for callbacks
      _onPaymentResult = onResult;
      _currentPaymentContext = {
        'vendorId': vendorId,
        'tableId': tableId,
        'orderId': orderId,
        'amount': amount,
        'backendOrderId': orderResponse['orderId'],
        'razorpayOrderId': orderResponse['razorpayOrderId'],
        'razorpayKey': orderResponse['razorpayKey'],
      };

      // Open Razorpay checkout
      final options = {
        'key': orderResponse['razorpayKey'],
        'order_id': orderResponse['razorpayOrderId'],
        'amount': (amount * 100).round(), // Convert to paise
        'name': businessName,
        'description': 'Table Order #$orderId',
        'prefill': {
          'contact': customerPhone ?? '',
          'name': customerName ?? '',
        },
        'external': {
          'wallets': ['paytm', 'googlepay', 'phonepe'],
        },
        'notes': {
          'vendor_id': vendorId,
          'table_id': tableId,
          'order_id': orderId,
          'backend_order_id': orderResponse['orderId'],
        },
        'theme': {
          'color': '#EA580C', // Restaurant orange theme
        },
      };

      _razorpay.open(options);
    } catch (e) {
      developer.log('Payment initiation error: $e', name: 'PwaPaymentService');
      onResult(false, 'Error initiating payment: $e', null);
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      final context = _currentPaymentContext;
      final onResult = _onPaymentResult;

      if (context.isEmpty || onResult == null) {
        developer.log('Payment success but no context', name: 'PwaPaymentService');
        return;
      }

      // Verify payment server-side
      final verified = await _verifyPayment(
        vendorId: context['vendorId'],
        tableId: context['tableId'],
        razorpayPaymentId: response.paymentId ?? '',
        razorpayOrderId: response.orderId ?? context['razorpayOrderId'] ?? '',
        razorpaySignature: response.signature ?? '',
      );

      _currentPaymentContext = {};
      _onPaymentResult = null;

      if (verified) {
        onResult(true, 'Payment successful! Your order is confirmed.', response.paymentId);
      } else {
        onResult(false, 'Payment verification failed. Please contact support.', null);
      }
    } catch (e) {
      developer.log('Payment success handler error: $e', name: 'PwaPaymentService');
      _onPaymentResult?.call(false, 'Error processing payment: $e', null);
      _currentPaymentContext = {};
      _onPaymentResult = null;
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    developer.log('Payment error: ${response.message}', name: 'PwaPaymentService');
    
    String message = response.message ?? 'Payment failed';
    
    // User-friendly error messages
    if (message.contains('cancelled') || message.contains('CANCELLED')) {
      message = 'Payment was cancelled. You can try again.';
    } else if (message.contains('network') || message.contains('NETWORK')) {
      message = 'Network error. Please check your connection and try again.';
    } else if (message.contains('timeout') || message.contains('TIMEOUT')) {
      message = 'Payment timed out. Please try again.';
    }

    _onPaymentResult?.call(false, message, null);
    _currentPaymentContext = {};
    _onPaymentResult = null;
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    developer.log('External wallet: ${response.walletName}', name: 'PwaPaymentService');
    // Keep waiting for actual payment success/failure
  }

  /// Retry failed payment
  Future<void> retryPayment({
    required String vendorId,
    required String tableId,
    required String orderId,
    required double amount,
    required String businessName,
    String? customerName,
    String? customerPhone,
    required Function(bool success, String message, String? paymentId) onResult,
  }) async {
    // Clear previous state
    _currentPaymentContext = {};
    _onPaymentResult = null;
    
    // Initiate fresh payment
    await initiatePayment(
      vendorId: vendorId,
      tableId: tableId,
      orderId: orderId,
      amount: amount,
      businessName: businessName,
      customerName: customerName,
      customerPhone: customerPhone,
      onResult: onResult,
    );
  }

  /// Dispose Razorpay instance
  void dispose() {
    _razorpay.clear();
    _isInitialized = false;
  }
}
