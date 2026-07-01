// ============================================================================
// E-INVOICE STATUS TRACKING SERVICE
// ============================================================================
// Tracks E-Invoice (IRN) generation status for GST compliance visibility.
//
// Author: DukanX Engineering
// Created: 2026-01-23
// ============================================================================

import 'package:drift/drift.dart';
import '../core/database/app_database.dart';

/// E-Invoice Status
enum EInvoiceStatus { notRequired, pending, generated, cancelled, error }

/// E-Invoice tracking information
class EInvoiceInfo {
  final String billId;
  final String invoiceNumber;
  final String customerName;
  final double amount;
  final DateTime billDate;
  final EInvoiceStatus status;

  EInvoiceInfo({
    required this.billId,
    required this.invoiceNumber,
    required this.customerName,
    required this.amount,
    required this.billDate,
    required this.status,
  });

  bool get isCompliant =>
      status == EInvoiceStatus.generated ||
      status == EInvoiceStatus.notRequired;
}

/// E-Invoice Dashboard Summary
class EInvoiceDashboardSummary {
  final int totalHighValue;
  final int pending;
  final double compliancePercentage;
  final List<EInvoiceInfo> pendingInvoices;

  EInvoiceDashboardSummary({
    required this.totalHighValue,
    required this.pending,
    required this.compliancePercentage,
    required this.pendingInvoices,
  });

  factory EInvoiceDashboardSummary.empty() => EInvoiceDashboardSummary(
    totalHighValue: 0,
    pending: 0,
    compliancePercentage: 100,
    pendingInvoices: [],
  );

  bool get isFullyCompliant => pending == 0;
}

/// E-Invoice Integration Status Service
///
/// Tracks high-value invoices (Rs 2.5L+) that would require E-Invoice.
class EInvoiceStatusService {
  final AppDatabase db;

  EInvoiceStatusService({required this.db});

  /// Get E-Invoice dashboard summary for a user
  Future<EInvoiceDashboardSummary> getDashboardSummary(String userId) async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    // Get all invoices for user (filtering deleted and user in DB)
    final query = db.select(db.bills)
      ..where((b) => b.userId.equals(userId) & b.deletedAt.isNull());

    final allBills = await query.get();

    // Filter to this month in Dart to avoid 'isBiggerThanValue' issues
    final monthBills = allBills
        .where(
          (b) => b.billDate.isAfter(
            startOfMonth.subtract(const Duration(days: 1)),
          ),
        )
        .toList();

    final highValueInvoices = <EInvoiceInfo>[];

    for (final bill in monthBills) {
      if (bill.grandTotal >= 250000) {
        highValueInvoices.add(
          EInvoiceInfo(
            billId: bill.id,
            invoiceNumber: bill.invoiceNumber,
            customerName: bill.customerName ?? 'Unknown',
            amount: bill.grandTotal,
            billDate: bill.billDate,
            status: EInvoiceStatus.pending,
          ),
        );
      }
    }

    final total = highValueInvoices.length;
    return EInvoiceDashboardSummary(
      totalHighValue: total,
      pending: total,
      compliancePercentage: total == 0 ? 100.0 : 0.0,
      pendingInvoices: highValueInvoices,
    );
  }

  Future<bool> isIntegrationConfigured() async => false;

  Future<Map<String, dynamic>> getIntegrationStatus(String userId) async {
    final summary = await getDashboardSummary(userId);
    final isConfigured = await isIntegrationConfigured();

    return {
      'isConfigured': isConfigured,
      'highValueInvoices': summary.totalHighValue,
      'pending': summary.pending,
      'compliance': '${summary.compliancePercentage.toStringAsFixed(0)}%',
      'status': isConfigured
          ? (summary.isFullyCompliant ? 'COMPLIANT' : 'ACTION_NEEDED')
          : 'NOT_CONFIGURED',
      'message': 'E-Invoice integration pending setup',
    };
  }
}
