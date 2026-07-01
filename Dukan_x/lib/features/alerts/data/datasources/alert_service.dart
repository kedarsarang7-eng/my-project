import 'package:uuid/uuid.dart';

import '../../../billing/domain/repositories/billing_repository.dart';
import '../../domain/entities/alert.dart';

import '../../../../core/repository/products_repository.dart';
import '../../../../core/repository/bills_repository.dart';

class AlertService {
  final BillingRepository _billingRepo;
  final ProductsRepository _productRepo;
  final BillsRepository? _coreBillsRepo; // Optional: for expiry checking

  AlertService(this._billingRepo, this._productRepo, [this._coreBillsRepo]);

  Future<List<Alert>> checkAlerts(String userId) async {
    List<Alert> alerts = [];
    final now = DateTime.now();
    final warningDate = now.add(const Duration(days: 30));

    // 1. Check Product Alerts (Low Stock)
    final productsResult = await _productRepo.getAll(userId: userId);
    if (productsResult.data != null) {
      for (final product in productsResult.data!) {
        if (product.isLowStock) {
          alerts.add(
            Alert(
              id: const Uuid().v4(),
              type: AlertType.lowStock,
              message:
                  'Low Stock: ${product.name} (${product.stockQuantity} ${product.unit} remaining)',
              createdAt: DateTime.now(),
            ),
          );
        }
      }
    }

    // ============================================================
    // 2. EXPIRY ALERTS (Pharmacy Compliance)
    // ============================================================
    // Scan recent bills for items with expiry dates and generate alerts for:
    // - 🔴 Already expired items
    // - 🟡 Items expiring within 30 days
    //
    // Uses existing AlertType.expiry enum (no schema changes).
    // Requires the core BillsRepository which has full BillItem with expiry.
    // ============================================================
    if (_coreBillsRepo != null) {
      try {
        final coreBillsRepo = _coreBillsRepo; // Local variable for null safety
        final billsResult = await coreBillsRepo.getAll(userId: userId);
        if (billsResult.data != null) {
          final bills = billsResult.data!;

          // Collect unique product expiry dates from recent bills
          // Key: "productName_batchNo" to avoid duplicate alerts
          final expiryMap = <String, _ExpiryInfo>{};

          for (final bill in bills.take(100)) {
            // Check last 100 bills
            for (final item in bill.items) {
              if (item.expiryDate != null && item.productName.isNotEmpty) {
                final key = '${item.productName}_${item.batchNo ?? ""}';
                // Only keep the earliest expiry for each product-batch combo
                if (!expiryMap.containsKey(key) ||
                    item.expiryDate!.isBefore(expiryMap[key]!.expiryDate)) {
                  expiryMap[key] = _ExpiryInfo(
                    productName: item.productName,
                    batchNo: item.batchNo,
                    expiryDate: item.expiryDate!,
                  );
                }
              }
            }
          }

          // Generate alerts for expired and near-expiry items
          for (final entry in expiryMap.entries) {
            final info = entry.value;

            if (info.expiryDate.isBefore(now)) {
              // 🔴 EXPIRED - Critical alert
              alerts.add(
                Alert(
                  id: const Uuid().v4(),
                  type: AlertType.expiry,
                  message:
                      '⚠️ EXPIRED: ${info.productName}${info.batchNo != null ? " (Batch: ${info.batchNo})" : ""} - Expired: ${_formatDate(info.expiryDate)}',
                  createdAt: DateTime.now(),
                ),
              );
            } else if (info.expiryDate.isBefore(warningDate)) {
              // 🟡 NEAR EXPIRY - Warning alert
              alerts.add(
                Alert(
                  id: const Uuid().v4(),
                  type: AlertType.expiry,
                  message:
                      '⏰ Expiring Soon: ${info.productName}${info.batchNo != null ? " (Batch: ${info.batchNo})" : ""} - Expires: ${_formatDate(info.expiryDate)}',
                  createdAt: DateTime.now(),
                ),
              );
            }
          }
        }
      } catch (e) {
        // If core bills repo fails, continue without expiry alerts
        // This maintains backward compatibility
      }
    }

    // 3. Abnormal Bill Check (existing logic - uses domain bills)
    final billsResult = await _billingRepo.getBills();
    billsResult.fold((l) => null, (bills) {
      if (bills.isEmpty) return;

      double totalSum = 0;
      for (final b in bills) {
        totalSum += b.totalAmount;
      }
      final avg = totalSum / bills.length;

      // Check recent bills (e.g., last 3)
      final recentBills = bills.take(3);
      for (final bill in recentBills) {
        if (bill.totalAmount > (avg * 3) && avg > 100) {
          alerts.add(
            Alert(
              id: const Uuid().v4(),
              type: AlertType.abnormalBill,
              message:
                  'Abnormal Bill Detected: ₹${bill.totalAmount} (Avg: ₹${avg.toStringAsFixed(0)})',
              createdAt: bill.date,
            ),
          );
        }
      }
    });

    // Sort alerts: Expired first, then by date
    alerts.sort((a, b) {
      // Expiry alerts first
      if (a.type == AlertType.expiry && b.type != AlertType.expiry) return -1;
      if (b.type == AlertType.expiry && a.type != AlertType.expiry) return 1;
      // Then by date (newest first)
      return b.createdAt.compareTo(a.createdAt);
    });

    return alerts;
  }

  /// Format date for display
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}

/// Helper class for expiry tracking
class _ExpiryInfo {
  final String productName;
  final String? batchNo;
  final DateTime expiryDate;

  _ExpiryInfo({
    required this.productName,
    this.batchNo,
    required this.expiryDate,
  });
}
