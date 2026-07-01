import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'dart:developer' as developer;
import '../core/di/service_locator.dart';
import '../core/repository/bills_repository.dart';
import '../core/session/session_manager.dart';

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

  /// Initiate online payment for a bill
  Future<void> initiateOnlinePayment({
    required Bill bill,
    required String customerName,
    required String customerPhone,
    required String customerEmail,
    required double amount,
    required Function(bool success, String message) onResult,
  }) async {
    try {
      // Validate amount
      if (amount <= 0) {
        onResult(false, 'Invalid payment amount');
        return;
      }

      // PRODUCTION SAFETY: Razorpay Key Configuration
      //
      // Set RAZORPAY_KEY environment variable during build:
      //   flutter build apk --dart-define=RAZORPAY_KEY=rzp_live_YOUR_KEY
      //
      // For development, the test key is used automatically.
      const String keyId = String.fromEnvironment(
        'RAZORPAY_KEY',
        defaultValue: 'rzp_test_REPLACE_IN_PRODUCTION',
      );

      // CRITICAL: Fail fast if using test key in release mode
      const bool isRelease = bool.fromEnvironment('dart.vm.product');
      if (isRelease && keyId.contains('test')) {
        developer.log(
          'CRITICAL: Razorpay test key detected in production build!',
          name: 'PaymentService',
          level: 1200, // Severe
        );
        onResult(
          false,
          'Payment system not configured for production. Please contact support.',
        );
        return;
      }

      // Warn in debug mode if still using placeholder
      if (keyId.contains('REPLACE_IN_PRODUCTION')) {
        developer.log(
          'WARNING: Using placeholder Razorpay key. Set RAZORPAY_KEY environment variable.',
          name: 'PaymentService',
          level: 900, // Warning
        );
      }

      // Create payment options
      var options = {
        'key': keyId,
        'amount': (amount * 100).toInt(), // Amount in paise
        'name': 'Vegetable Billing',
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
          'customer_phone': customerPhone,
          'bill_amount': bill.subtotal.toString(),
        },
      };

      // Store current bill context for success handler
      _currentBillContext = {
        'bill': bill,
        'amount': amount,
        'paymentTime': DateTime.now(),
        'onResult': onResult,
      };

      _razorpay.open(options);
    } catch (e) {
      onResult(false, 'Error initiating payment: $e');
    }
  }

  Map<String, dynamic> _currentBillContext = {};

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      final Bill bill = _currentBillContext['bill'] as Bill;
      final double amount = _currentBillContext['amount'] as double;
      final Function onResult = _currentBillContext['onResult'] as Function;

      // Update bill with online payment via Repository
      final userId = _session.ownerId ?? bill.ownerId;
      if (userId.isEmpty) {
        onResult(false, 'Authentication error: User ID not found');
        return;
      }

      final result = await _billsRepo.recordPayment(
        userId: userId,
        billId: bill.id,
        amount: amount,
        paymentMode: 'Online',
        notes: 'Razorpay Payment ID: ${response.paymentId}',
      );

      // Clear context
      _currentBillContext.clear();

      if (result.success) {
        onResult(true, 'Payment successful! Bill updated.');
      } else {
        onResult(false, 'Error updating bill: ${result.errorMessage}');
      }
    } catch (e) {
      final Function onResult = _currentBillContext['onResult'] as Function;
      onResult(false, 'Error updating bill: $e');
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

  /// Dispose of Razorpay instance
  void dispose() {
    _razorpay.clear();
  }
}
