import 'package:uuid/uuid.dart';

import '../../../core/session/session_manager.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/repository/bills_repository.dart';
import '../../../core/repository/products_repository.dart';
import '../../../core/services/invoice_number_service.dart';
import '../models/delivery_challan_model.dart';
import '../data/repositories/delivery_challan_repository.dart';

class DeliveryChallanService {
  final DeliveryChallanRepository _repository;
  final BillsRepository _billsRepository;
  final ProductsRepository _productsRepository;
  final InvoiceNumberService _invoiceNumberService;
  final SessionManager _sessionManager;

  DeliveryChallanService(
    this._repository,
    this._billsRepository,
    this._productsRepository,
    this._invoiceNumberService,
    this._sessionManager,
  );

  /// Create a new Delivery Challan
  Future<DeliveryChallan?> createChallan({
    required String? customerId,
    required String? customerName,
    required List<DeliveryChallanItem> items,
    required DateTime challanDate,
    DateTime? dueDate,
    String? transportMode,
    String? vehicleNumber,
    String? eWayBillNumber,
    String? shippingAddress,
    String? lrNumber,
    String? transporterName,
  }) async {
    try {
      final userId = _sessionManager.ownerId;
      if (userId == null) throw Exception('User not logged in');

      // Atomic FY-based number (shares counter row with invoices; prefix DC in formatted string).
      final challanNumber = await _invoiceNumberService.getNextInvoiceNumber(
        userId: userId,
        prefix: 'DC',
      );

      // 2. Calculate totals
      double subtotal = 0;
      double taxAmount = 0;
      double grandTotal = 0;

      for (var item in items) {
        subtotal += item.totalAmount - item.taxAmount;
        taxAmount += item.taxAmount;
        grandTotal += item.totalAmount;
      }

      // 3. Create Challan Object
      final challan = DeliveryChallan(
        id: const Uuid().v4(),
        userId: userId,
        challanNumber: challanNumber,
        customerId: customerId,
        customerName: customerName,
        challanDate: challanDate,
        dueDate: dueDate,
        subtotal: subtotal,
        taxAmount: taxAmount,
        grandTotal: grandTotal,
        status: DeliveryChallanStatus.sent, // Assume sent immediately
        transportMode: transportMode,
        vehicleNumber: vehicleNumber,
        eWayBillNumber: eWayBillNumber,
        shippingAddress: shippingAddress,
        lrNumber: lrNumber,
        transporterName: transporterName,
        items: items,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // 4. Save to Repository
      await _repository.createChallan(challan);

      // 5. Reserve Stock (Optional: Mark as "Out on Challan" logic would go here)
      // For now, we adjust stock normally as it's leaving the warehouse?
      // GST Rule: Delivery Challan moves goods, so stock physically leaves.
      // We will decrement stock with a specific reason.
      for (var item in items) {
        await _productsRepository.adjustStock(
          productId: item.productId,
          quantity: -item.quantity, // Deduct stock
          userId: userId,
          // Extra metadata could be passed if adjustStock supported it,
          // but for now the reason is implicit or we add a log.
        );
      }

      return challan;
    } catch (e) {
      LoggerService.d(
        'DeliveryChallan',
        'DeliveryChallanService: Error creating challan: $e',
      );
      return null;
    }
  }

  /// Convert Delivery Challan to Tax Invoice
  Future<Bill?> convertToInvoice(DeliveryChallan challan) async {
    Future<void> reapplyDcStockDeduction() async {
      for (final item in challan.items) {
        await _productsRepository.adjustStock(
          productId: item.productId,
          quantity: -item.quantity,
          userId: challan.userId,
        );
      }
    }

    if (challan.status == DeliveryChallanStatus.converted) {
      LoggerService.d(
        'DeliveryChallan',
        'DeliveryChallanService: Challan already converted',
      );
      return null;
    }

    final userId = challan.userId;
    final businessType =
        (_sessionManager.activeBusinessType ?? BusinessType.other).name;
    var restoredStockForInvoice = false;
    var billPersisted = false;

    try {
      // 1. REVERSE Stock Deduction from DC (createBill will deduct again).
      for (final item in challan.items) {
        await _productsRepository.adjustStock(
          productId: item.productId,
          quantity: item.quantity,
          userId: userId,
        );
      }
      restoredStockForInvoice = true;

      final invoiceNumber = await _invoiceNumberService.getNextInvoiceNumber(
        userId: userId,
      );

      final billItemsProper = challan.items.map((dcItem) {
        return BillItem(
          productId: dcItem.productId,
          productName: dcItem.productName,
          qty: dcItem.quantity,
          price: dcItem.unitPrice,
          unit: dcItem.unit,
          gstRate: dcItem.taxRate,
          hsn: dcItem.hsnCode ?? '',
          discount: 0,
          cgst: dcItem.cgstAmount,
          sgst: dcItem.sgstAmount,
          igst: dcItem.igstAmount,
        );
      }).toList();

      final ship = challan.shippingAddress?.trim();
      final bill = Bill(
        id: const Uuid().v4(),
        ownerId: userId,
        invoiceNumber: invoiceNumber,
        customerId: challan.customerId ?? '',
        customerName: challan.customerName ?? 'Walk-in',
        customerAddress: (ship != null && ship.isNotEmpty) ? ship : '',
        date: DateTime.now(),
        subtotal: challan.subtotal,
        totalTax: challan.taxAmount,
        grandTotal: challan.grandTotal,
        status: 'Unpaid',
        paymentType: 'CREDIT',
        items: billItemsProper,
        deliveryChallanId: challan.id,
        updatedAt: DateTime.now(),
        businessType: businessType,
        businessId: userId,
      );

      final result = await _billsRepository.createBill(bill);
      if (!result.isSuccess) {
        await reapplyDcStockDeduction();
        restoredStockForInvoice = false;
        LoggerService.d(
          'DeliveryChallan',
          'DeliveryChallanService: createBill failed: ${result.errorMessage}',
        );
        return null;
      }
      billPersisted = true;

      final updatedChallan = challan.copyWith(
        status: DeliveryChallanStatus.converted,
        convertedBillId: bill.id,
        updatedAt: DateTime.now(),
      );
      await _repository.updateChallan(updatedChallan);

      return bill;
    } catch (e) {
      LoggerService.d(
        'DeliveryChallan',
        'DeliveryChallanService: Error converting to invoice: $e',
      );
      if (restoredStockForInvoice && !billPersisted) {
        try {
          await reapplyDcStockDeduction();
        } catch (rollbackErr) {
          LoggerService.d(
            'DeliveryChallan',
            'DeliveryChallanService: Stock rollback after failed conversion: $rollbackErr',
          );
        }
      }
      return null;
    }
  }

  /// Update non-converted challan and reconcile stock delta.
  Future<DeliveryChallan?> updateChallan({
    required DeliveryChallan existing,
    required String? customerId,
    required String? customerName,
    required List<DeliveryChallanItem> items,
    required DateTime challanDate,
    DateTime? dueDate,
    String? transportMode,
    String? vehicleNumber,
    String? eWayBillNumber,
    String? shippingAddress,
    String? lrNumber,
    String? transporterName,
  }) async {
    if (existing.status == DeliveryChallanStatus.converted ||
        existing.status == DeliveryChallanStatus.cancelled) {
      return null;
    }
    try {
      final oldByProduct = <String, double>{};
      final newByProduct = <String, double>{};

      for (final item in existing.items) {
        oldByProduct[item.productId] =
            (oldByProduct[item.productId] ?? 0) + item.quantity;
      }
      for (final item in items) {
        newByProduct[item.productId] =
            (newByProduct[item.productId] ?? 0) + item.quantity;
      }

      final productIds = <String>{...oldByProduct.keys, ...newByProduct.keys};
      final appliedAdjustments = <MapEntry<String, double>>[];
      try {
        for (final productId in productIds) {
          final oldQty = oldByProduct[productId] ?? 0;
          final newQty = newByProduct[productId] ?? 0;
          final delta = oldQty - newQty;
          if (delta == 0) continue;
          await _productsRepository.adjustStock(
            productId: productId,
            quantity: delta,
            userId: existing.userId,
          );
          appliedAdjustments.add(MapEntry(productId, delta));
        }

        double subtotal = 0;
        double taxAmount = 0;
        double grandTotal = 0;
        for (final item in items) {
          subtotal += item.totalAmount - item.taxAmount;
          taxAmount += item.taxAmount;
          grandTotal += item.totalAmount;
        }

        final updated = existing.copyWith(
          customerId: customerId,
          customerName: customerName,
          challanDate: challanDate,
          dueDate: dueDate,
          transportMode: transportMode,
          vehicleNumber: vehicleNumber,
          eWayBillNumber: eWayBillNumber,
          shippingAddress: shippingAddress,
          lrNumber: lrNumber,
          transporterName: transporterName,
          items: items,
          subtotal: subtotal,
          taxAmount: taxAmount,
          grandTotal: grandTotal,
          status: DeliveryChallanStatus.sent,
          updatedAt: DateTime.now(),
        );
        await _repository.updateChallan(updated);
        return updated;
      } catch (e) {
        for (final entry in appliedAdjustments.reversed) {
          await _productsRepository.adjustStock(
            productId: entry.key,
            quantity: -entry.value,
            userId: existing.userId,
          );
        }
        rethrow;
      }
    } catch (e) {
      LoggerService.d(
        'DeliveryChallan',
        'DeliveryChallanService: Error updating challan: $e',
      );
      return null;
    }
  }

  /// Cancel a non-converted challan and restore stock that was deducted at DC creation.
  Future<bool> cancelChallan(DeliveryChallan challan) async {
    if (challan.status == DeliveryChallanStatus.converted ||
        challan.status == DeliveryChallanStatus.cancelled) {
      return false;
    }
    try {
      for (final item in challan.items) {
        await _productsRepository.adjustStock(
          productId: item.productId,
          quantity: item.quantity,
          userId: challan.userId,
        );
      }
      try {
        await _repository.updateChallan(
          challan.copyWith(
            status: DeliveryChallanStatus.cancelled,
            updatedAt: DateTime.now(),
          ),
        );
      } catch (e) {
        for (final item in challan.items) {
          await _productsRepository.adjustStock(
            productId: item.productId,
            quantity: -item.quantity,
            userId: challan.userId,
          );
        }
        rethrow;
      }
      return true;
    } catch (e) {
      LoggerService.d(
        'DeliveryChallan',
        'DeliveryChallanService: Error cancelling challan: $e',
      );
      return false;
    }
  }
}
