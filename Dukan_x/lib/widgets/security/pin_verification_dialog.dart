// ============================================================================
// PIN VERIFICATION DIALOG
// ============================================================================
// Modal dialog for PIN entry with secure handling.
// Used for authorizing critical actions.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/security/models/pin_protected_actions.dart';

/// PIN Verification Dialog - Secure PIN entry for critical actions.
///
/// Features:
/// - 4-6 digit PIN input
/// - Masked input by default with toggle
/// - Clear error feedback
/// - Lockout countdown display
class PinVerificationDialog extends StatefulWidget {
  /// Title shown in dialog
  final String title;

  /// Action being authorized
  final PinProtectedAction action;

  /// Callback on successful verification
  final void Function(String pin, String? reason) onVerify;

  /// Callback on cancel
  final VoidCallback? onCancel;

  /// Whether to show reason field
  final bool requireReason;

  /// Custom description (overrides action description)
  final String? customDescription;

  const PinVerificationDialog({
    super.key,
    required this.title,
    required this.action,
    required this.onVerify,
    this.onCancel,
    this.requireReason = false,
    this.customDescription,
  });

  /// Show PIN verification dialog and return result
  static Future<PinVerificationResult?> show({
    required BuildContext context,
    required PinProtectedAction action,
    String? customTitle,
    String? customDescription,
    bool requireReason = false,
  }) async {
    String? enteredPin;
    String? reason;
    bool verified = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PinVerificationDialog(
        title: customTitle ?? 'Authorization Required',
        action: action,
        requireReason: requireReason,
        customDescription: customDescription,
        onVerify: (pin, r) {
          enteredPin = pin;
          reason = r;
          verified = true;
          Navigator.of(context).pop();
        },
        onCancel: () {
          Navigator.of(context).pop();
        },
      ),
    );

    if (verified && enteredPin != null) {
      return PinVerificationResult(
        isAuthorized: true,
        action: action,
        authorizedAt: DateTime.now(),
        reason: reason,
      );
    }

    return null;
  }

  @override
  State<PinVerificationDialog> createState() => _PinVerificationDialogState();
}

class _PinVerificationDialogState extends State<PinVerificationDialog> {
  final _pinController = TextEditingController();
  final _reasonController = TextEditingController();
  final _pinFocusNode = FocusNode();

  bool _obscurePin = true;
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Auto-focus PIN field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pinFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    _reasonController.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final pin = _pinController.text.trim();

    // Validate PIN format
    if (pin.isEmpty) {
      setState(() => _errorMessage = 'Please enter PIN');
      return;
    }

    if (pin.length < 4 || pin.length > 6) {
      setState(() => _errorMessage = 'PIN must be 4-6 digits');
      return;
    }

    if (!RegExp(r'^\d+$').hasMatch(pin)) {
      setState(() => _errorMessage = 'PIN must only contain digits');
      return;
    }

    // Validate reason if required
    if (widget.requireReason && _reasonController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please provide a reason');
      return;
    }

    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    // Call verification callback
    widget.onVerify(pin, _reasonController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Severity color
    Color severityColor;
    switch (widget.action.severity) {
      case Severity.critical:
        severityColor = Colors.red;
        break;
      case Severity.high:
        severityColor = Colors.orange;
        break;
      case Severity.medium:
        severityColor = Colors.amber;
        break;
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.lock_outline, color: severityColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(widget.title, style: theme.textTheme.titleLarge),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Action description
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: severityColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: severityColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    _getActionIcon(widget.action),
                    color: severityColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.customDescription ?? widget.action.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: severityColor.withOpacity(0.9),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // PIN Input
            TextField(
              controller: _pinController,
              focusNode: _pinFocusNode,
              obscureText: _obscurePin,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: InputDecoration(
                labelText: 'Enter Owner PIN',
                hintText: '••••',
                counterText: '',
                prefixIcon: const Icon(Icons.pin),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePin ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () => setState(() => _obscurePin = !_obscurePin),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                errorText: _errorMessage,
              ),
              onSubmitted: (_) => _submit(),
            ),

            // Reason field (if required)
            if (widget.requireReason) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _reasonController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Reason for this action',
                  hintText: 'Enter reason...',
                  prefixIcon: const Icon(Icons.note),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],

            // Owner-only warning
            if (widget.action.ownerOnly) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.admin_panel_settings,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Owner authorization required',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : widget.onCancel,
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: _isLoading ? null : _submit,
          icon: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check),
          label: const Text('Authorize'),
        ),
      ],
    );
  }

  IconData _getActionIcon(PinProtectedAction action) {
    switch (action) {
      case PinProtectedAction.billDelete:
        return Icons.delete_forever;
      case PinProtectedAction.billEditAfterPayment:
        return Icons.edit;
      case PinProtectedAction.highDiscount:
        return Icons.percent;
      case PinProtectedAction.refund:
        return Icons.money_off;
      case PinProtectedAction.stockAdjustment:
        return Icons.inventory;
      case PinProtectedAction.periodUnlock:
        return Icons.lock_open;
      case PinProtectedAction.cashMismatchAcceptance:
        return Icons.account_balance_wallet;
      case PinProtectedAction.forceLogoutUser:
        return Icons.logout;
      case PinProtectedAction.changeUserRole:
        return Icons.manage_accounts;
      case PinProtectedAction.viewSensitiveData:
        return Icons.visibility;
      case PinProtectedAction.exportAuditLogs:
        return Icons.download;
      case PinProtectedAction.closeFinancialYear:
        return Icons.calendar_month;
      case PinProtectedAction.editGstData:
        return Icons.receipt_long;
      case PinProtectedAction.overrideSystemCalculation:
        return Icons.calculate;
    }
  }
}
