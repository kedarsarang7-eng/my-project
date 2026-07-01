// ============================================================================
// ADVANCED BILLING SCREEN - COMPATIBILITY WRAPPER
// ============================================================================
// Redirects to BillCreationScreenV2 for backward compatibility.
// ============================================================================

import 'package:flutter/material.dart';
import '../features/billing/presentation/screens/bill_creation_screen_v2.dart';

/// Legacy AdvancedBillingScreen - now wraps BillCreationScreenV2
@Deprecated('Use BillCreationScreenV2 directly instead')
class AdvancedBillingScreen extends StatelessWidget {
  const AdvancedBillingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const BillCreationScreenV2();
  }
}
