// ============================================================================
// Computer Shop — Dashboard Alert Providers
// ============================================================================
// Provides real-time dashboard alert counts for the computerShop vertical,
// sourced from ComputerRepository REST queries.
//
// Pattern follows electronicsAlertCountsProvider (business_alerts_widget.dart):
//   - Per-metric failure isolation (available flag per count)
//   - FutureProvider.autoDispose for automatic cleanup
//   - No hardcoded counts — every value derives from a live query
//
// Requirements: 14.1, 14.2, 14.5
// ============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/computer_repository.dart';
import 'computer_job_providers.dart';

// ============================================================================
// Model
// ============================================================================

/// Dashboard alert snapshot for the computerShop vertical.
///
/// Each metric has a count and an availability flag. When a query fails, the
/// corresponding `*Available` flag is set to `false` and the count defaults
/// to 0 — the widget should render an unavailable indicator (e.g. `...`)
/// rather than a numeric value.
///
/// Requirements: 14.1, 14.2, 14.5
class ComputerShopAlertSnapshot {
  const ComputerShopAlertSnapshot({
    required this.warrantyExpiring,
    required this.warrantyExpiringAvailable,
    required this.pendingRepairs,
    required this.pendingRepairsAvailable,
  });

  /// Count of warranties whose end date falls within [today, today + 30 days].
  final int warrantyExpiring;

  /// Whether the warranty-expiring count was successfully retrieved.
  final bool warrantyExpiringAvailable;

  /// Count of job cards whose status is NOT delivered or cancelled.
  final int pendingRepairs;

  /// Whether the pending-repairs count was successfully retrieved.
  final bool pendingRepairsAvailable;
}

// ============================================================================
// Provider
// ============================================================================

/// Fetches real computerShop alert metrics from [ComputerRepository].
///
/// Per-metric failure isolation: if one query fails, the other metric is still
/// available. The widget renders `...` for unavailable metrics instead of a
/// stale or default numeric value (Req 14.5).
///
/// Requirements: 14.1, 14.2, 14.5
final computerShopAlertCountsProvider =
    FutureProvider.autoDispose<ComputerShopAlertSnapshot>((ref) async {
      final repository = ref.watch(computerRepositoryProvider);

      // --- Warranty expiring (end date in [today, today+30d]) ---
      int warrantyExpiring = 0;
      bool warrantyOk = true;
      try {
        warrantyExpiring = await repository.getWarrantyExpiringCount();
      } catch (_) {
        warrantyOk = false;
      }

      // --- Pending repairs (status ∉ {delivered, cancelled}) ---
      int pendingRepairs = 0;
      bool repairsOk = true;
      try {
        pendingRepairs = await repository.getPendingRepairsCount();
      } catch (_) {
        repairsOk = false;
      }

      return ComputerShopAlertSnapshot(
        warrantyExpiring: warrantyExpiring,
        warrantyExpiringAvailable: warrantyOk,
        pendingRepairs: pendingRepairs,
        pendingRepairsAvailable: repairsOk,
      );
    });
