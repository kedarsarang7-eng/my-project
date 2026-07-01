import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'dart:developer' as developer;
import '../../../core/di/service_locator.dart';
import '../../../core/repository/bills_repository.dart';
import '../../../core/session/session_manager.dart';
import '../../../core/api/api_client.dart';

class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  late Razorpay _razorpay;

  // Use Repositories via Service Locator
  BillsRepository get _billsRepo => sl<BillsRepository>();
  SessionManager get _session => sl<SessionManager>();

  PaymentService._internal();

  factory PaymentService() {
    return _instance;
  }

  Future<void> init() async {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  /// Backend API client for payment verification
  final ApiClient _apiClient = sl<ApiClient>();

  /// Initiate online payment for a bill
  /// CRITICAL SECURITY: This now calls the backend to create the order,
  /// ensuring per-tenant keys are used and server-side verification is performed.
  Future<void> initiateOnlinePayment({
    required Bill bill,
    required String customerName,
    required String customerPhone,
    required String customerEmail,
    required double amount,
    required Function(bool success, String message) onResult,
    String businessName = 'Dukan Billing',
  }) async {
    try {
      // Validate amount
      if (amount <= 0) {
        onResult(false, 'Invalid payment amount');
        return;
      }

      // CRITICAL FIX: Create order via backend to get per-tenant credentials
      // This ensures payments go to the correct merchant account, not a single platform account
      final orderResponse = await _createPaymentOrderViaBackend(
        billId: bill.id,
        businessId: _session.currentBusinessId ?? bill.businessId ?? '',
        amount: amount,
        customerName: customerName,
        customerPhone: customerPhone,
      );

      if (orderResponse == null) {
        onResult(false, 'Failed to create payment order. Please try again.');
        return;
      }

      // Store current bill context for success handler
      // CRITICAL: Store the backend order ID and key for verification
      _currentBillContext = {
        'bill': bill,
        'amount': amount,
        'paymentTime': DateTime.now(),
        'onResult': onResult,
        'backendOrderId': orderResponse['orderId'],
        'razorpayOrderId': orderResponse['razorpayOrderId'],
        'razorpayKey': orderResponse['razorpayKey'],
        'businessId': _session.currentBusinessId ?? bill.businessId ?? '',
      };

      // Create payment options using backend-provided key and order ID
      var options = {
        'key': orderResponse['razorpayKey'],
        'order_id': orderResponse['razorpayOrderId'],
        'amount': (amount * 100).round(),
        'name': businessName,
        'description': 'Bill Payment - #${bill.id.substring(0, 8)}',
        'prefill': {
          'contact': customerPhone,
          'email': customerEmail,
          'name': customerName,
        },
        'external': {
          'wallets': ['paytm', 'googlepay'],
        },
        'notes': {
          'bill_id': bill.id,
          'backend_order_id': orderResponse['orderId'],
        },
      };

      _razorpay.open(options);
    } catch (e) {
      developer.log('Error initiating payment: $e', name: 'PaymentService');
      onResult(false, 'Error initiating payment: $e');
    }
  }

  /// Create payment order via backend to ensure per-tenant credentials
  Future<Map<String, dynamic>?> _createPaymentOrderViaBackend({
    required String billId,
    required String businessId,
    required double amount,
    required String customerName,
    required String customerPhone,
  }) async {
    try {
      final response = await _apiClient.post('/billing/payment/create-order', body: {
        'billId': billId,
        'businessId': businessId,
        'amount': amount,
        'customerName': customerName,
        'customerPhone': customerPhone,
      });

      if (response.isSuccess && response.data != null && response.data!['success'] == true) {
        return {
          'orderId': response.data!['orderId'],
          'razorpayOrderId': response.data!['razorpayOrderId'],
          'razorpayKey': response.data!['razorpayKey'],
        };
      }
      return null;
    } catch (e) {
      developer.log('Failed to create backend order: $e', name: 'PaymentService');
      return null;
    }
  }

  Map<String, dynamic> _currentBillContext = {};

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      final Bill bill = _currentBillContext['bill'] as Bill;
      final Function onResult = _currentBillContext['onResult'] as Function;
      final String businessId = _currentBillContext['businessId'] as String;
      final String? razorpayOrderId = _currentBillContext['razorpayOrderId'] as String?;

      // CRITICAL SECURITY FIX: Verify payment server-side before marking bill as paid
      // Do NOT trust the SDK callback alone - it can be spoofed
      final verificationResult = await _verifyPaymentWithBackend(
        billId: bill.id,
        businessId: businessId,
        razorpayPaymentId: response.paymentId ?? '',
        razorpayOrderId: response.orderId ?? razorpayOrderId ?? '',
        razorpaySignature: response.signature ?? '',
      );

      if (!verificationResult['success']) {
        onResult(false, 'Payment verification failed: ${verificationResult['error']}');
        _currentBillContext.clear();
        return;
      }

      // Clear context after successful verification
      _currentBillContext.clear();

      onResult(true, 'Payment successful! Bill updated.');
    } catch (e) {
      final Function onResult = _currentBillContext['onResult'] as Function;
      onResult(false, 'Error verifying payment: $e');
      _currentBillContext.clear();
    }
  }

  /// CRITICAL: Verify payment with backend before marking bill as paid
  /// This prevents spoofed SDK callbacks from marking bills paid without actual payment
  Future<Map<String, dynamic>> _verifyPaymentWithBackend({
    required String billId,
    required String businessId,
    required String razorpayPaymentId,
    required String razorpayOrderId,
    required String razorpaySignature,
  }) async {
    try {
      final response = await _apiClient.post('/billing/payment/verify', body: {
        'billId': billId,
        'businessId': businessId,
        'razorpayPaymentId': razorpayPaymentId,
        'razorpayOrderId': razorpayOrderId,
        'razorpaySignature': razorpaySignature,
      });

      if (response.isSuccess && response.data != null && response.data!['success'] == true) {
        return {'success': true};
      }

      return {
        'success': false,
        'error': response.data?['error'] ?? response.error ?? 'Verification failed',
      };
    } catch (e) {
      developer.log('Payment verification error: $e', name: 'PaymentService');
      return {'success': false, 'error': 'Verification error: $e'};
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    try {
      final Function onResult = _currentBillContext['onResult'] as Function;
      onResult(false, 'Payment failed: ${response.message}');
      _currentBillContext.clear();
    } catch (e) {
      developer.log(
        'Error handling payment failure: $e',
        name: 'PaymentService',
      );
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    try {
      final Function onResult = _currentBillContext['onResult'] as Function;
      onResult(
        false,
        'External wallet ${response.walletName} is being used. Complete the payment in wallet app.',
      );
      _currentBillContext.clear();
    } catch (e) {
      developer.log(
        'Error handling external wallet: $e',
        name: 'PaymentService',
      );
    }
  }

  /// Record offline cash payment
  Future<void> recordOfflinePayment({
    required Bill bill,
    required double amountPaid,
    required Function(bool success, String message) onResult,
  }) async {
    try {
      if (amountPaid <= 0) {
        onResult(false, 'Invalid payment amount');
        return;
      }

      final userId = _session.ownerId ?? bill.ownerId;
      if (userId.isEmpty) {
        onResult(false, 'Authentication error: User ID not found');
        return;
      }

      final result = await _billsRepo.recordPayment(
        userId: userId,
        billId: bill.id,
        amount: amountPaid,
        paymentMode: 'Cash',
      );

      if (result.success) {
        onResult(true, 'Offline payment recorded successfully!');
      } else {
        onResult(false, 'Error recording payment: ${result.errorMessage}');
      }
    } catch (e) {
      onResult(false, 'Error recording payment: $e');
    }
  }

  /// Mark bill as paid (owner marking from app)
  Future<void> markBillAsPaid({
    required Bill bill,
    required String paymentType, // 'Cash' or 'Online'
    required Function(bool success, String message) onResult,
  }) async {
    try {
      double cashPaid = 0;
      double onlinePaid = 0;

      // CRITICAL FIX: Use grandTotal (includes tax, service charge, etc.)
      // NOT subtotal (which excludes these amounts)
      final amountToPay = bill.grandTotal;

      if (paymentType == 'Cash') {
        cashPaid = amountToPay;
      } else if (paymentType == 'Online') {
        onlinePaid = amountToPay;
      }

      final userId = _session.ownerId ?? bill.ownerId;
      if (userId.isEmpty) {
        onResult(false, 'Authentication error: User ID not found');
        return;
      }

      // Use updateBillStatus for full override
      final result = await _billsRepo.updateBillStatus(
        billId: bill.id,
        status: 'Paid',
        paidAmount: amountToPay,
        cashPaid: cashPaid,
        onlinePaid: onlinePaid,
      );

      if (result.success) {
        onResult(true, 'Bill marked as paid!');
      } else {
        onResult(false, 'Error marking bill as paid: ${result.errorMessage}');
      }
    } catch (e) {
      onResult(false, 'Error marking bill as paid: $e');
    }
  }

  /// Get payment summary for a customer
  Future<Map<String, dynamic>> getPaymentSummary(String customerId) async {
    try {
      final userId = _session.ownerId;
      if (userId == null) return {};

      // Use Repository to get all bills for customer
      final result = await _billsRepo.getAll(
        userId: userId,
        customerId: customerId,
      );

      final customerBills = result.data ?? [];

      double totalAmount = 0;
      double totalPaid = 0;
      double totalPending = 0;
      double totalCashPaid = 0;
      double totalOnlinePaid = 0;
      int totalBills = customerBills.length;
      int paidBills = 0;
      int partialBills = 0;
      int unpaidBills = 0;

      for (final bill in customerBills) {
        totalAmount +=
            bill.grandTotal; // Use grandTotal instead of subtotal for accuracy
        totalPaid += bill.paidAmount;
        totalPending += (bill.grandTotal - bill.paidAmount);
        totalCashPaid += bill.cashPaid;
        totalOnlinePaid += bill.onlinePaid;

        if (bill.status == 'Paid') {
          paidBills++;
        } else if (bill.status == 'Partial') {
          partialBills++;
        } else {
          unpaidBills++;
        }
      }

      return {
        'totalBills': totalBills,
        'totalAmount': totalAmount,
        'totalPaid': totalPaid,
        'totalPending': totalPending,
        'totalCashPaid': totalCashPaid,
        'totalOnlinePaid': totalOnlinePaid,
        'paidBills': paidBills,
        'partialBills': partialBills,
        'unpaidBills': unpaidBills,
        'bills': customerBills,
      };
    } catch (e) {
      developer.log(
        'Error getting payment summary: $e',
        name: 'PaymentService',
      );
      return {};
    }
  }

  /// Process refund for a paid bill
  /// Requires Admin or Manager role
  Future<Map<String, dynamic>> processRefund({
    required String billId,
    required String businessId,
    double? amount, // null = full refund
    required String reason,
    String? notes,
  }) async {
    try {
      final response = await _apiClient.post('/billing/payment/refund', body: {
        'billId': billId,
        'businessId': businessId,
        'amount': ?amount,
        'reason': reason,
        'notes': ?notes,
      });

      if (response.isSuccess && response.data != null) {
        return {
          'success': response.data!['success'] ?? false,
          'refundId': response.data!['refundId'],
          'amount': response.data!['amount'],
          'status': response.data!['status'],
          'isFullyRefunded': response.data!['isFullyRefunded'],
          'message': response.data!['message'],
        };
      }

      return {
        'success': false,
        'error': response.error ?? 'Refund request failed',
      };
    } catch (e) {
      developer.log('Refund error: $e', name: 'PaymentService');
      return {
        'success': false,
        'error': 'Error processing refund: $e',
      };
    }
  }

  /// Fetch refund history for a specific bill
  Future<List<Map<String, dynamic>>> getRefundHistory(String billId) async {
    try {
      final response = await _apiClient.get('/billing/payment/refunds?billId=$billId');

      if (response.isSuccess && response.data != null) {
        final refunds = response.data!['refunds'] as List<dynamic>?;
        return refunds?.cast<Map<String, dynamic>>() ?? [];
      }

      return [];
    } catch (e) {
      developer.log('Get refund history error: $e', name: 'PaymentService');
      return [];
    }
  }

  /// Dispose of Razorpay instance
  void dispose() {
    _razorpay.clear();
  }
}
