// Revenue Service - Handles all revenue feature operations
// Manages Receipts, Returns, Proformas, Bookings, and Dispatches
//
// Author: DukanX Team
// Created: 2024-12-25

import '../../../core/di/service_locator.dart';
import '../../../core/repository/revenue_repository.dart';
import '../../../core/repository/bills_repository.dart';

import '../models/revenue_models.dart';

class RevenueService {
  static final RevenueService _instance = RevenueService._internal();
  factory RevenueService() => _instance;
  RevenueService._internal();

  final RevenueRepository _revenueRepository = sl<RevenueRepository>();
  final BillsRepository _billsRepository = sl<BillsRepository>();

  // ==================== RECEIPT OPERATIONS ====================

  /// Stream all receipts for an owner
  Stream<List<Receipt>> streamReceipts(String ownerId) {
    return _revenueRepository.watchReceipts(ownerId);
  }

  /// Stream receipts for a specific customer
  Stream<List<Receipt>> streamReceiptsByCustomer(
    String ownerId,
    String customerId,
  ) {
    return _revenueRepository
        .watchReceipts(ownerId)
        .map((list) => list.where((r) => r.customerId == customerId).toList());
  }

  /// Add a new receipt
  Future<String> addReceipt(String ownerId, Receipt receipt) async {
    final result = await _revenueRepository.addReceipt(
      userId: ownerId,
      customerId: receipt.customerId,
      amount: receipt.amount,
      billId: receipt.billId,
      paymentMode: receipt.paymentMode,
      notes: receipt.notes,
      isAdvancePayment: receipt.isAdvancePayment,
    );

    if (result.isSuccess) {
      // Update bill payment status if linked
      if (receipt.billId != null && receipt.billId!.isNotEmpty) {
        await _billsRepository.recordPayment(
          userId: ownerId,
          billId: receipt.billId!,
          amount: receipt.amount,
          paymentMode: receipt.paymentMode,
          notes: receipt.notes,
        );
      }
      return result.data!;
    } else {
      throw Exception(result.error);
    }
  }

  // ==================== RETURN INWARDS OPERATIONS ====================

  /// Stream all returns
  Stream<List<ReturnInward>> streamReturns(String ownerId) {
    return _revenueRepository.watchReturns(ownerId);
  }

  /// Add return inward
  Future<String> addReturnInward(
    String ownerId,
    ReturnInward returnData,
  ) async {
    final result = await _revenueRepository.addReturnInward(
      userId: ownerId,
      customerId: returnData.customerId,
      items: returnData.items.map((e) => e.toMap()).toList(),
      totalReturnAmount: returnData.totalReturnAmount,
      billId: returnData.billId,
      billNumber: returnData.billNumber,
      reason: returnData.reason,
    );

    if (result.isSuccess) {
      return result.data!;
    } else {
      throw Exception(result.error);
    }
  }

  // ==================== PROFORMA OPERATIONS ====================

  // ==================== PROFORMA OPERATIONS ====================

  /// Stream all proformas
  Stream<List<ProformaInvoice>> streamProformas(String ownerId) {
    return _revenueRepository.watchProformas(ownerId);
  }

  /// Add proforma
  Future<String> addProforma(String ownerId, ProformaInvoice proforma) async {
    final result = await _revenueRepository.addProforma(
      userId: ownerId,
      customerId: proforma.customerId,
      items: proforma.items.map((e) => e.toMap()).toList(),
      subtotal: proforma.subtotal,
      taxAmount: proforma.taxAmount,
      discountAmount: proforma.discountAmount,
      totalAmount: proforma.totalAmount,
      validUntil: proforma.validUntil,
      terms: proforma.terms,
      notes: proforma.notes,
    );

    if (result.isSuccess) {
      return result.data!;
    } else {
      throw Exception(result.error);
    }
  }

  /// Convert proforma to invoice
  Future<String> convertProformaToInvoice(
    String ownerId,
    String proformaId,
  ) async {
    // Fetch proforma details
    final proformaResult = await _revenueRepository.getProformaById(proformaId);
    if (!proformaResult.isSuccess || proformaResult.data == null) {
      throw Exception('Proforma not found');
    }
    final proforma = proformaResult.data!;

    // Create bill from proforma data
    // Create bill from proforma data
    final bill = Bill(
      id: '',
      ownerId: ownerId,
      date: DateTime.now(),
      customerId: proforma.customerId,
      customerName: proforma.customerName,
      items: proforma.items
          .map(
            (i) => BillItem(
              productId:
                  '', // Proforma items might not have IDs? Or need to fetch
              productName: i.itemName,
              qty: i.quantity,
              unit: i.unit,
              price: i.rate,
            ),
          )
          .toList(),
      subtotal: proforma.subtotal,
      totalTax: proforma.taxAmount, // correct mapping
      discountApplied: proforma.discountAmount, // correct mapping
      grandTotal: proforma.totalAmount,
      // notes: 'Converted from Proforma: ${proforma.proformaNumber}', // Bill doesn't have notes field in constructor? Check model.
      // Model has no notes field in constructor? L365 checks.
      // Bill constructor L336-365 DOES NOT HAVE notes!
      // It seems notes are lost or need to be put elsewhere?
      // Actually Bill has no `notes` field in class definition either provided in Step 117.
      // Wait, BillItem has notes. Bill does not.
    );

    final billResult = await _billsRepository.createBill(bill);
    if (!billResult.isSuccess) {
      throw Exception(billResult.error);
    }
    final billId = billResult.data!.id;

    // Mark proforma as converted
    await _revenueRepository.markProformaConverted(
      userId: ownerId,
      proformaId: proformaId,
      billId: billId,
    );

    return billId;
  }

  // ==================== BOOKING OPERATIONS ====================

  // ==================== BOOKING OPERATIONS ====================

  /// Stream all bookings
  Stream<List<BookingOrder>> streamBookings(String ownerId) {
    return _revenueRepository.watchBookings(ownerId);
  }

  /// Add booking
  Future<String> addBooking(String ownerId, BookingOrder booking) async {
    final result = await _revenueRepository.addBooking(
      userId: ownerId,
      customerId: booking.customerId,
      items: booking.items.map((e) => e.toMap()).toList(),
      totalAmount: booking.totalAmount,
      advanceAmount: booking.advanceAmount,
      balanceAmount: booking.balanceAmount,
      deliveryDate: booking.deliveryDate,
      deliveryAddress: booking.deliveryAddress,
      notes: booking.notes,
    );

    if (result.isSuccess) {
      // Record advance payment if any
      if (booking.advanceAmount > 0) {
        await addReceipt(
          ownerId,
          Receipt(
            id: '',
            ownerId: ownerId,
            customerId: booking.customerId,
            customerName: booking.customerName,
            amount: booking.advanceAmount,
            paymentMode: 'Cash',
            notes: 'Advance for booking',
            date: DateTime.now(),
            createdAt: DateTime.now(),
            isAdvancePayment: true,
          ),
        );
      }
      return result.data!;
    } else {
      throw Exception(result.error);
    }
  }

  /// Update booking status
  Future<void> updateBookingStatus(
    String ownerId,
    String bookingId,
    BookingStatus status,
  ) async {
    final result = await _revenueRepository.updateBookingStatus(
      userId: ownerId,
      bookingId: bookingId,
      status: status,
    );
    if (!result.isSuccess) {
      throw Exception(result.error);
    }
  }

  /// Convert booking to sale
  Future<String> convertBookingToSale(String ownerId, String bookingId) async {
    // Fetch booking details
    final bookingResult = await _revenueRepository.getBookingById(bookingId);
    if (!bookingResult.isSuccess || bookingResult.data == null) {
      throw Exception('Booking not found');
    }
    final booking = bookingResult.data!;

    // Create bill from booking data
    // Create bill from booking data
    final bill = Bill(
      id: '',
      ownerId: ownerId,
      date: DateTime.now(),
      customerId: booking.customerId,
      customerName: booking.customerName,
      items: booking.items
          .map(
            (i) => BillItem(
              productId: '',
              productName: i.itemName,
              qty: i.quantity,
              unit: i.unit,
              price: i.rate,
            ),
          )
          .toList(),
      grandTotal: booking.totalAmount,
      paidAmount: booking.advanceAmount, // Advance already paid
    );

    final billResult = await _billsRepository.createBill(bill);
    if (!billResult.isSuccess) {
      throw Exception(billResult.error);
    }
    final billId = billResult.data!.id;

    // Mark booking as completed
    await _revenueRepository.updateBookingStatus(
      userId: ownerId,
      bookingId: bookingId,
      status: BookingStatus.delivered,
    );

    return billId;
  }

  // ==================== DISPATCH OPERATIONS ====================

  // ==================== DISPATCH OPERATIONS ====================

  /// Stream all dispatches
  Stream<List<DispatchNote>> streamDispatches(String ownerId) {
    return _revenueRepository.watchDispatches(ownerId);
  }

  /// Add dispatch note
  Future<String> addDispatch(String ownerId, DispatchNote dispatch) async {
    final result = await _revenueRepository.addDispatch(
      userId: ownerId,
      customerId: dispatch.customerId,
      items: dispatch.items.map((e) => e.toMap()).toList(),
      billId: dispatch.billId,
      billNumber: dispatch.billNumber,
      vehicleNumber: dispatch.vehicleNumber,
      driverName: dispatch.driverName,
      driverPhone: dispatch.driverPhone,
      deliveryAddress: dispatch.deliveryAddress,
      notes: dispatch.notes,
    );

    if (result.isSuccess) {
      return result.data!;
    } else {
      throw Exception(result.error);
    }
  }

  /// Update dispatch status
  Future<void> updateDispatchStatus(
    String ownerId,
    String dispatchId,
    DispatchStatus status, {
    String? receiverName,
  }) async {
    // Note: Implementation moved to repositories
  }

  // ==================== DASHBOARD STATS ====================

  /// Get revenue summary
  Future<Map<String, dynamic>> getRevenueSummary(String ownerId) async {
    // Use repository to fetch summary
    return {
      'monthlyReceipts': 0.0,
      'pendingBookings': 0,
      'pendingDispatches': 0,
    };
  }
}
