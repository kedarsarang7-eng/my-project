// ============================================================================
// PIN PROTECTED ACTIONS
// ============================================================================
// Defines all critical actions that require PIN verification.
// Used by PinVerificationService to determine authorization requirements.
// ============================================================================

/// Severity level for PIN-protected actions
enum Severity {
  /// Medium risk - logged but less scrutiny
  medium,

  /// High risk - logged with details
  high,

  /// Critical - requires detailed audit and may trigger alerts
  critical,
}

/// Actions that require owner/manager PIN for authorization.
///
/// These are high-risk operations that can be exploited for fraud.
/// PIN verification creates accountability and audit trail.
enum PinProtectedAction {
  /// Delete a bill (can hide sales/transactions)
  billDelete,

  /// Edit a bill after payment has been recorded
  billEditAfterPayment,

  /// Apply discount higher than configured threshold
  highDiscount,

  /// Process a refund (money going out)
  refund,

  /// Manual stock adjustment without document
  stockAdjustment,

  /// Unlock a locked accounting period
  periodUnlock,

  /// Accept cash mismatch during daily closing
  cashMismatchAcceptance,

  /// Force logout another user's session
  forceLogoutUser,

  /// Change user role/permissions
  changeUserRole,

  /// View sensitive financial data (profit margins)
  viewSensitiveData,

  /// Export full audit logs
  exportAuditLogs,

  /// Close financial year
  closeFinancialYear,

  /// Edit GST returns data
  editGstData,

  /// Override system-calculated totals
  overrideSystemCalculation,
}

/// Extension for display and logic
extension PinProtectedActionX on PinProtectedAction {
  /// Human-readable name for UI
  String get displayName {
    switch (this) {
      case PinProtectedAction.billDelete:
        return 'Bill Delete';
      case PinProtectedAction.billEditAfterPayment:
        return 'Edit Paid Bill';
      case PinProtectedAction.highDiscount:
        return 'High Discount';
      case PinProtectedAction.refund:
        return 'Process Refund';
      case PinProtectedAction.stockAdjustment:
        return 'Stock Adjustment';
      case PinProtectedAction.periodUnlock:
        return 'Unlock Period';
      case PinProtectedAction.cashMismatchAcceptance:
        return 'Accept Cash Mismatch';
      case PinProtectedAction.forceLogoutUser:
        return 'Force Logout';
      case PinProtectedAction.changeUserRole:
        return 'Change User Role';
      case PinProtectedAction.viewSensitiveData:
        return 'View Sensitive Data';
      case PinProtectedAction.exportAuditLogs:
        return 'Export Audit Logs';
      case PinProtectedAction.closeFinancialYear:
        return 'Close Financial Year';
      case PinProtectedAction.editGstData:
        return 'Edit GST Data';
      case PinProtectedAction.overrideSystemCalculation:
        return 'Override Calculation';
    }
  }

  /// Description for confirmation dialogs
  String get description {
    switch (this) {
      case PinProtectedAction.billDelete:
        return 'This will permanently delete the bill. Stock will be restored.';
      case PinProtectedAction.billEditAfterPayment:
        return 'This bill has been paid/printed. Changes will be audited.';
      case PinProtectedAction.highDiscount:
        return 'Discount exceeds your configured threshold.';
      case PinProtectedAction.refund:
        return 'This will issue a refund and update customer balance.';
      case PinProtectedAction.stockAdjustment:
        return 'Manual stock change without purchase/sale document.';
      case PinProtectedAction.periodUnlock:
        return 'Unlocking allows modifications to a closed period.';
      case PinProtectedAction.cashMismatchAcceptance:
        return 'There is a variance between expected and actual cash.';
      case PinProtectedAction.forceLogoutUser:
        return 'This will end the user\'s session on their device.';
      case PinProtectedAction.changeUserRole:
        return 'This will change the user\'s access permissions.';
      case PinProtectedAction.viewSensitiveData:
        return 'Accessing confidential profit and margin data.';
      case PinProtectedAction.exportAuditLogs:
        return 'Exporting complete audit trail of all actions.';
      case PinProtectedAction.closeFinancialYear:
        return 'This will lock the entire financial year from edits.';
      case PinProtectedAction.editGstData:
        return 'Modifying data that affects GST filings.';
      case PinProtectedAction.overrideSystemCalculation:
        return 'Manually overriding system-calculated amounts.';
    }
  }

  /// Get severity level
  Severity get severity {
    switch (this) {
      case PinProtectedAction.billDelete:
      case PinProtectedAction.billEditAfterPayment:
      case PinProtectedAction.periodUnlock:
      case PinProtectedAction.changeUserRole:
      case PinProtectedAction.closeFinancialYear:
      case PinProtectedAction.editGstData:
      case PinProtectedAction.overrideSystemCalculation:
        return Severity.critical;
      case PinProtectedAction.highDiscount:
      case PinProtectedAction.refund:
      case PinProtectedAction.stockAdjustment:
      case PinProtectedAction.cashMismatchAcceptance:
        return Severity.high;
      case PinProtectedAction.forceLogoutUser:
      case PinProtectedAction.viewSensitiveData:
      case PinProtectedAction.exportAuditLogs:
        return Severity.medium;
    }
  }

  /// Whether this action should create a fraud alert
  bool get createsFraudAlert => severity == Severity.critical;

  /// Whether this action is owner-only (managers cannot authorize)
  bool get ownerOnly {
    switch (this) {
      case PinProtectedAction.billDelete:
      case PinProtectedAction.periodUnlock:
      case PinProtectedAction.changeUserRole:
      case PinProtectedAction.closeFinancialYear:
      case PinProtectedAction.editGstData:
      case PinProtectedAction.overrideSystemCalculation:
        return true;
      default:
        return false;
    }
  }
}

/// Result of a PIN verification attempt
class PinVerificationResult {
  /// Whether the PIN was correct
  final bool isAuthorized;

  /// Who authorized (userId)
  final String? authorizedBy;

  /// The action that was authorized
  final PinProtectedAction action;

  /// When authorization was granted
  final DateTime? authorizedAt;

  /// Reason/notes for authorization
  final String? reason;

  const PinVerificationResult({
    required this.isAuthorized,
    this.authorizedBy,
    required this.action,
    this.authorizedAt,
    this.reason,
  });

  /// Create a denied result
  factory PinVerificationResult.denied(PinProtectedAction action) {
    return PinVerificationResult(isAuthorized: false, action: action);
  }

  /// Create an authorized result
  factory PinVerificationResult.authorized({
    required PinProtectedAction action,
    required String authorizedBy,
    String? reason,
  }) {
    return PinVerificationResult(
      isAuthorized: true,
      authorizedBy: authorizedBy,
      action: action,
      authorizedAt: DateTime.now(),
      reason: reason,
    );
  }
}
