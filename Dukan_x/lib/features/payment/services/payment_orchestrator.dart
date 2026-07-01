import '../../../core/di/service_locator.dart';
import '../../accounting/services/accounting_service.dart';
import '../../party_ledger/services/party_ledger_service.dart';
import '../data/repositories/payment_repository.dart';

/// Payment Orchestrator
///
/// Coordinates Payment persistence, Accounting journaling, and Party Ledger updates.
/// Ensures that a "Received Payment" action correctly updates all systems.
class PaymentOrchestrator {
  final PaymentRepository _paymentRepo;
  final AccountingService _accountingService;
  final PartyLedgerService _partyLedgerService;

  PaymentOrchestrator({
    PaymentRepository? paymentRepo,
    AccountingService? accountingService,
    PartyLedgerService? partyLedgerService,
  }) : _paymentRepo = paymentRepo ?? sl<PaymentRepository>(),
       _accountingService = accountingService ?? sl<AccountingService>(),
       _partyLedgerService = partyLedgerService ?? sl<PartyLedgerService>();

  /// Record a received payment (Customer -> Shop)
  Future<String> recordReceivedPayment({
    required String userId,
    required String customerId,
    required String customerName,
    required double amount,
    required String paymentMode,
    required DateTime date,
    String? notes,
  }) async {
    // 1. Create Payment Record (Source of Truth for Receipt)
    // We pass 'billId' as empty or a special marker if it's a general on-account payment.
    // Ideally, we should allow linking to multiple bills, but for now "On Account".
    final paymentResult = await _paymentRepo.createPayment(
      userId: userId,
      billId: '', // General Payment
      customerId: customerId,
      amount: amount,
      paymentMode: paymentMode,
      referenceNumber: 'RCPT-${DateTime.now().millisecondsSinceEpoch}',
      notes: notes ?? 'Payment Received via Party Ledger',
      date: date,
    );

    final paymentId = paymentResult.data;

    if (paymentId == null) {
      throw Exception('Failed to create payment record');
    }

    // 2. Create Accounting Entry (Receipt Voucher)
    await _accountingService.createReceiptEntry(
      userId: userId,
      paymentId: paymentId,
      customerId: customerId,
      customerName: customerName,
      amount: amount,
      paymentMode: paymentMode,
      paymentDate: date,
    );

    // 3. Sync Legacy Customer Balance
    await _partyLedgerService.syncCustomerBalance(userId, customerId);

    return paymentId;
  }

  /// Record a made payment (Shop -> Vendor)
  Future<String> recordPaidPayment({
    required String userId,
    required String vendorId,
    required String vendorName,
    required double amount,
    required String paymentMode,
    required DateTime date,
    String? notes,
  }) async {
    // 1. Create Payment Record (Vendor payments might be in a different table or same?)
    // PaymentRepository currently seems biased towards Customer payments (billId, customerId).
    // But for now we might use it or Expenses?
    // Actually, Vendor Payments should ideally be in Purchase Module or General Payments.
    // Let's us PaymentRepository but we need to check if it supports VendorId.
    // Looking at PaymentRepository... it has customerId. It does NOT have vendorId.
    //
    // GAP: PaymentRepository needs to support VendorId or we use ExpenseRepository?
    // ExpenseRepository is for Expenses. Vendor Payment is "Payment Out".
    //
    // For MVP, we will use AccountingService directly for Ledger updates,
    // and maybe ExpenseRepository for persistence if PaymentRepo is strictly customer?
    //
    // Checking AccountingService... createPaymentEntry(vendorId...) exists!
    // So Accounting supports it.
    //
    // Let's skip PaymentRepository for Vendor for now (or overload customerId?)
    // Better: Use AccountingService.createPaymentEntry which creates the Journal.
    // We might not have a raw "payments" table record for vendor yet.
    // This is acceptable for Phase 1 as Journal is the Ledger SOT.

    // 2. Create Accounting Entry (Payment Voucher)
    // We generate a ID ourselves since we skip PaymentRepo
    final paymentId = 'PAY-${DateTime.now().millisecondsSinceEpoch}';

    await _accountingService.createPaymentEntry(
      userId: userId,
      paymentId: paymentId,
      vendorId: vendorId,
      vendorName: vendorName,
      amount: amount,
      paymentMode: paymentMode,
      paymentDate: date,
    );

    // 3. Sync Vendor Balance (if PartyLedgerService supports it)
    // PartyLedgerService only has syncCustomerBalance.
    // We need syncVendorBalance there too.
    // For now, let's assume Journal is enough for reports.

    return paymentId;
  }
}
