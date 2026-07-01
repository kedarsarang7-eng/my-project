// ============================================================================
// CUSTOMER REPORT SCREEN - COMPATIBILITY WRAPPER
// ============================================================================
// This file provides backward compatibility for legacy code referencing
// CustomerReportScreen. It redirects to the modern CustomerDetailScreen.
//
// NOTE: This wrapper was created during the legacy screen cleanup audit.
// Future work should update all references to use CustomerDetailScreen directly.
// ============================================================================

import 'package:flutter/material.dart';
import '../features/customers/presentation/screens/customer_detail_screen.dart';

/// Legacy CustomerReportScreen - now wraps CustomerDetailScreen
@Deprecated('Use CustomerDetailScreen directly instead')
class CustomerReportScreen extends StatelessWidget {
  final String customerId;
  final String? customerName; // Ignored but kept for compatibility

  const CustomerReportScreen({
    super.key,
    required this.customerId,
    this.customerName,
  });

  @override
  Widget build(BuildContext context) {
    // CustomerDetailScreen only takes customerId
    return CustomerDetailScreen(customerId: customerId);
  }
}
