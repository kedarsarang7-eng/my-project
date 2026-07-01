// ============================================================================
// BILL STATE DEFINITIONS
// ============================================================================
// Bill state enum and immutability rules for fraud prevention.
// ============================================================================

/// Bill State - Defines the lifecycle state of a bill.
///
/// Immutability Rules:
/// - DRAFT: Fully editable
/// - UNPAID: Editable within edit window
/// - PAID: Locked, requires PIN to edit
/// - PRINTED: Locked, requires PIN to edit
/// - GST_FILED: Permanently locked (only adjustment via Credit Note)
enum BillState {
  /// Bill is being created, not yet saved
  draft,

  /// Bill saved but no payment received
  unpaid,

  /// Bill has partial or full payment
  paid,

  /// Bill has been printed or shared
  printed,

  /// Bill has been included in GST returns
  gstFiled,
}

extension BillStateX on BillState {
  /// Human-readable display name
  String get displayName {
    switch (this) {
      case BillState.draft:
        return 'Draft';
      case BillState.unpaid:
        return 'Unpaid';
      case BillState.paid:
        return 'Paid';
      case BillState.printed:
        return 'Printed';
      case BillState.gstFiled:
        return 'GST Filed';
    }
  }

  /// Whether this state is locked (requires PIN to edit)
  bool get isLocked {
    switch (this) {
      case BillState.draft:
        return false;
      case BillState.unpaid:
        return false;
      case BillState.paid:
        return true;
      case BillState.printed:
        return true;
      case BillState.gstFiled:
        return true;
    }
  }

  /// Whether edits are possible at all (even with PIN)
  bool get isEditable {
    switch (this) {
      case BillState.draft:
        return true;
      case BillState.unpaid:
        return true;
      case BillState.paid:
        return true; // With PIN
      case BillState.printed:
        return true; // With PIN
      case BillState.gstFiled:
        return false; // Never editable
    }
  }

  /// Whether deletion is possible
  bool get isDeletable {
    switch (this) {
      case BillState.draft:
        return true;
      case BillState.unpaid:
        return true; // With PIN
      case BillState.paid:
        return false; // Never delete paid bills
      case BillState.printed:
        return false; // Never delete printed bills
      case BillState.gstFiled:
        return false; // Never delete GST filed bills
    }
  }

  /// Color for UI display
  String get colorHex {
    switch (this) {
      case BillState.draft:
        return '#9E9E9E'; // Grey
      case BillState.unpaid:
        return '#FF9800'; // Orange
      case BillState.paid:
        return '#4CAF50'; // Green
      case BillState.printed:
        return '#2196F3'; // Blue
      case BillState.gstFiled:
        return '#9C27B0'; // Purple
    }
  }
}

/// Immutability Check Result
class ImmutabilityCheckResult {
  /// Whether the action is allowed
  final bool isAllowed;

  /// If not allowed, the reason
  final String? reason;

  /// Whether PIN can unlock this
  final bool canOverrideWithPin;

  /// Current bill state
  final BillState billState;

  const ImmutabilityCheckResult({
    required this.isAllowed,
    this.reason,
    this.canOverrideWithPin = false,
    required this.billState,
  });

  factory ImmutabilityCheckResult.allowed(BillState state) {
    return ImmutabilityCheckResult(isAllowed: true, billState: state);
  }

  factory ImmutabilityCheckResult.denied({
    required String reason,
    required BillState state,
    bool canOverride = false,
  }) {
    return ImmutabilityCheckResult(
      isAllowed: false,
      reason: reason,
      canOverrideWithPin: canOverride,
      billState: state,
    );
  }
}

/// Bill Immutability Service - Checks if bills can be edited/deleted.
class BillImmutabilityService {
  /// Determine bill state from bill data
  static BillState getBillState({
    required String status,
    required int printCount,
    required double paidAmount,
    bool isGstFiled = false,
  }) {
    if (isGstFiled) return BillState.gstFiled;
    if (printCount > 0) return BillState.printed;
    if (paidAmount > 0 || status == 'Paid' || status == 'Partial') {
      return BillState.paid;
    }
    if (status == 'Draft') return BillState.draft;
    return BillState.unpaid;
  }

  /// Check if bill can be edited
  static ImmutabilityCheckResult canEdit({
    required String status,
    required int printCount,
    required double paidAmount,
    required DateTime billDate,
    required int editWindowMinutes,
    bool isGstFiled = false,
    bool hasOwnerPin = false,
  }) {
    final state = getBillState(
      status: status,
      printCount: printCount,
      paidAmount: paidAmount,
      isGstFiled: isGstFiled,
    );

    // GST Filed - Never editable
    if (state == BillState.gstFiled) {
      return ImmutabilityCheckResult.denied(
        reason:
            'Bill is included in GST returns. Use Credit Note for corrections.',
        state: state,
        canOverride: false,
      );
    }

    // Draft - Always editable
    if (state == BillState.draft) {
      return ImmutabilityCheckResult.allowed(state);
    }

    // Check edit window for unpaid bills
    if (state == BillState.unpaid) {
      if (editWindowMinutes > 0) {
        final windowEnd = billDate.add(Duration(minutes: editWindowMinutes));
        if (DateTime.now().isAfter(windowEnd)) {
          return ImmutabilityCheckResult.denied(
            reason: 'Edit window expired (${editWindowMinutes}min)',
            state: state,
            canOverride: true,
          );
        }
      }
      return ImmutabilityCheckResult.allowed(state);
    }

    // Paid/Printed - Requires PIN
    if (hasOwnerPin) {
      return ImmutabilityCheckResult.allowed(state);
    }

    return ImmutabilityCheckResult.denied(
      reason: 'Bill is ${state.displayName}. Owner PIN required to edit.',
      state: state,
      canOverride: true,
    );
  }

  /// Check if bill can be deleted
  static ImmutabilityCheckResult canDelete({
    required String status,
    required int printCount,
    required double paidAmount,
    bool isGstFiled = false,
    bool hasOwnerPin = false,
  }) {
    final state = getBillState(
      status: status,
      printCount: printCount,
      paidAmount: paidAmount,
      isGstFiled: isGstFiled,
    );

    // GST Filed - Never deletable
    if (state == BillState.gstFiled) {
      return ImmutabilityCheckResult.denied(
        reason: 'Bill is included in GST returns. Cannot be deleted.',
        state: state,
        canOverride: false,
      );
    }

    // Paid/Printed - Never deletable
    if (state == BillState.paid || state == BillState.printed) {
      return ImmutabilityCheckResult.denied(
        reason:
            'Paid/Printed bills cannot be deleted. Use Credit Note for reversals.',
        state: state,
        canOverride: false,
      );
    }

    // Draft - Always deletable
    if (state == BillState.draft) {
      return ImmutabilityCheckResult.allowed(state);
    }

    // Unpaid - Requires PIN
    if (hasOwnerPin) {
      return ImmutabilityCheckResult.allowed(state);
    }

    return ImmutabilityCheckResult.denied(
      reason: 'Owner PIN required to delete bill.',
      state: state,
      canOverride: true,
    );
  }
}
