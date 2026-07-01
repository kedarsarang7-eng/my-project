// ============================================================================
// ADVANCED BILL CREATION SCREEN - COMPATIBILITY WRAPPER
// ============================================================================
// This file provides backward compatibility for legacy code referencing
// AdvancedBillCreationScreen. It redirects to the modern BillCreationScreenV2.
//
// NOTE: This wrapper was created during the legacy screen cleanup audit.
// Future work should update all references to use BillCreationScreenV2 directly.
// ============================================================================

import 'package:flutter/material.dart';
import '../features/billing/presentation/screens/bill_creation_screen_v2.dart';
import '../models/transaction_model.dart';
import '../core/repository/bills_repository.dart';

/// Legacy AdvancedBillCreationScreen - now wraps BillCreationScreenV2
///
/// This wrapper maintains backward compatibility for:
/// - main.dart routes
/// - billing_reports_screen.dart
/// - bill_detail.dart
/// - sale/* modules
/// - owner_dashboard_screen.dart
@Deprecated('Use BillCreationScreenV2 directly instead')
class AdvancedBillCreationScreen extends StatelessWidget {
  final TransactionType transactionType;
  final Bill? editingBill;
  final bool startVoice; // Ignored but kept for compatibility

  const AdvancedBillCreationScreen({
    super.key,
    this.transactionType = TransactionType.sale,
    this.editingBill,
    this.startVoice = false,
  });

  @override
  Widget build(BuildContext context) {
    // Convert editingBill to initialItems if present
    List<BillItem>? initialItems;

    if (editingBill != null) {
      initialItems = editingBill!.items;
    }

    return BillCreationScreenV2(
      transactionType: transactionType,
      initialItems: initialItems,
      // Note: startVoice feature removed - voice can be triggered manually
    );
  }
}
