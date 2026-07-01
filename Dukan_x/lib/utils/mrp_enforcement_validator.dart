/// MRP Enforcement Validator (pharmacy vertical)
///
/// Enforces the Maximum Retail Price (MRP) ceiling: no line item may be sold
/// above its MRP. All comparisons operate on **integer paise** (Requirement 2),
/// using the shared [Paise] helper for any rupee→paise conversion at the
/// boundary so that MRP, GST, and credit-note math agree on the same rounding
/// rule.
///
/// This validator is invoked at two chokepoints:
///   * `BillCreationScreenV2` (Pharmacy_POS) at line-item price entry (R8.1–R8.2)
///   * `bills_repository` before a pharmacy bill is persisted (R8.3–R8.4)
///
/// Wiring into those callers happens in downstream tasks (4.1 / 4.2); this file
/// provides the paise-based API they consume.
///
/// Validates: Requirements 8.1, 8.2, 8.3, 8.4.
library;

import 'package:dukanx/core/pharmacy/paise.dart';
import 'package:dukanx/models/bill.dart';

/// Resolves the MRP (in integer paise) for a given [BillItem].
///
/// `BillItem` does not itself carry an MRP field (Requirement 4 forbids
/// retyping shared model fields), so callers supply a lookup that resolves MRP
/// from product/batch data. A `null` result means the MRP is genuinely unknown
/// for that item and the MRP ceiling cannot be enforced against it.
class MrpLookup {
  const MrpLookup(this._resolve);

  /// Build a lookup from a `productId → mrpPaise` map. Missing entries (and
  /// explicit `null` values) resolve to an unknown MRP.
  factory MrpLookup.fromProductMrpPaise(Map<String, int?> mrpPaiseByProductId) {
    return MrpLookup((item) => mrpPaiseByProductId[item.productId]);
  }

  final int? Function(BillItem item) _resolve;

  /// MRP for [item] in integer paise, or `null` when genuinely unknown.
  int? mrpPaiseFor(BillItem item) => _resolve(item);
}

class MrpEnforcementValidator {
  const MrpEnforcementValidator._();

  /// Returns `true` when the selling price is at or below the MRP ceiling.
  ///
  /// Both values are integer paise. A `null` or non-positive [mrpPaise] is
  /// treated as a genuinely-unknown MRP and is therefore non-blocking here
  /// (returns `true`); pharmacy items are expected to carry a real MRP, and the
  /// product-entry validation (R8.5–R8.6) is what guarantees that.
  ///
  /// Validates: Requirements 8.1, 8.3.
  static bool isMrpCompliant(int sellingPaise, int? mrpPaise) {
    if (mrpPaise == null || mrpPaise <= 0) {
      return true; // MRP unknown — cannot enforce the ceiling.
    }
    return sellingPaise <= mrpPaise;
  }

  /// Validate every line item of [bill] against its MRP ceiling, collecting one
  /// [MrpViolation] per line whose selling price strictly exceeds its MRP.
  ///
  /// The per-unit selling price is read from `BillItem.price` (rupees) and
  /// converted to integer paise at the boundary via [Paise.fromRupees]
  /// (round-half-up). The MRP (already in paise) is resolved through [mrp].
  ///
  /// The returned result is compliant only when no line item violates the
  /// ceiling; callers (e.g. `bills_repository`) reject the entire bill on any
  /// violation and use [MrpValidationResult.violations] to report which lines
  /// failed (R8.4).
  ///
  /// Validates: Requirements 8.2, 8.3, 8.4.
  static MrpValidationResult validateBill(Bill bill, MrpLookup mrp) {
    final violations = <MrpViolation>[];

    for (final item in bill.items) {
      final int? mrpPaise = mrp.mrpPaiseFor(item);
      final int sellingPaise = Paise.fromRupees(item.price);

      if (!isMrpCompliant(sellingPaise, mrpPaise)) {
        // mrpPaise is non-null and positive here (otherwise isMrpCompliant
        // would have returned true), so the `!` is safe.
        violations.add(
          MrpViolation(
            productId: item.productId,
            itemName: item.productName,
            sellingPaise: sellingPaise,
            mrpPaise: mrpPaise!,
          ),
        );
      }
    }

    return MrpValidationResult(
      isCompliant: violations.isEmpty,
      violations: violations,
    );
  }
}

/// A single line item whose selling price exceeded its MRP ceiling.
///
/// All monetary fields are integer paise (Requirement 2.1).
class MrpViolation {
  MrpViolation({
    required this.productId,
    required this.itemName,
    required this.sellingPaise,
    required this.mrpPaise,
  });

  final String productId;
  final String itemName;

  /// The selling price that violated the ceiling, in integer paise.
  final int sellingPaise;

  /// The MRP ceiling that was exceeded, in integer paise.
  final int mrpPaise;

  /// Human-readable violation message naming the line item and its MRP
  /// (Requirements 8.2, 8.4). Currency is derived from paise via
  /// [Paise.toDisplay] (rupees with exactly two decimals).
  String get message =>
      '$itemName billed at ₹${Paise.toDisplay(sellingPaise)} '
      'exceeds its MRP of ₹${Paise.toDisplay(mrpPaise)}.';
}

/// Outcome of validating a bill against the MRP ceiling.
class MrpValidationResult {
  MrpValidationResult({required this.isCompliant, required this.violations});

  /// `true` when no line item exceeded its MRP ceiling.
  final bool isCompliant;

  /// One entry per violating line item (empty when [isCompliant] is `true`).
  final List<MrpViolation> violations;

  /// Summary message suitable for surfacing to the user.
  String get summary {
    if (isCompliant) return 'MRP compliance: OK';
    return 'MRP compliance violations: ${violations.length} item(s)';
  }
}
