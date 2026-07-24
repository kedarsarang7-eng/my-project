/// Price Adjustment Screen — Price Protection / Markdown with Approval
///
/// Renders a price adjustment form with:
/// - Approval workflow (requires authorized approver)
/// - Margin impact display (shows revenue impact before confirmation)
/// - Audit trail (immutable event created on approval)
/// - Feature policy gating
///
/// Requirements: 10.11, 12.1–12.8
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../auth/tenant_context_resolver.dart';
import '../../widgets/mobile_shop_session_state.dart';
import 'commerce_ui_utils.dart';
import 'mobile_commerce_service.dart';

/// Adjustment types supported by the price protection system.
enum PriceAdjustmentType {
  markdown('markdown', 'Markdown', Icons.trending_down),
  priceProtection(
    'price_protection',
    'Price Protection',
    Icons.shield_outlined,
  ),
  promotional('promotional', 'Promotional', Icons.local_offer_outlined);

  final String wireValue;
  final String displayName;
  final IconData icon;

  const PriceAdjustmentType(this.wireValue, this.displayName, this.icon);
}

/// Price adjustment screen with approval workflow.
///
/// Gated by 'PRICE_PROTECTION' feature policy.
class PriceAdjustmentScreen extends StatefulWidget {
  /// The commerce service.
  final MobileCommerceService service;

  /// The tenant context resolver.
  final TenantContextResolver resolver;

  /// Optional pre-filled IMEI.
  final String? prefillImei;

  /// Optional pre-filled unit ID.
  final String? prefillUnitId;

  /// Optional pre-filled original price (minor units).
  final int? prefillOriginalPriceMinor;

  const PriceAdjustmentScreen({
    super.key,
    required this.service,
    required this.resolver,
    this.prefillImei,
    this.prefillUnitId,
    this.prefillOriginalPriceMinor,
  });

  @override
  State<PriceAdjustmentScreen> createState() => _PriceAdjustmentScreenState();
}

class _PriceAdjustmentScreenState extends State<PriceAdjustmentScreen> {
  final _formKey = GlobalKey<FormState>();

  final _unitIdCtrl = TextEditingController();
  final _imeiCtrl = TextEditingController();
  final _originalPriceCtrl = TextEditingController();
  final _adjustedPriceCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final _approverCtrl = TextEditingController();
  final _effectiveFromCtrl = TextEditingController();
  final _effectiveToCtrl = TextEditingController();

  PriceAdjustmentType _adjustmentType = PriceAdjustmentType.markdown;
  bool _isSubmitting = false;
  bool _approvalConfirmed = false;
  CommerceOutcome? _lastOutcome;

  @override
  void initState() {
    super.initState();
    if (widget.prefillImei != null) {
      _imeiCtrl.text = widget.prefillImei!;
    }
    if (widget.prefillUnitId != null) {
      _unitIdCtrl.text = widget.prefillUnitId!;
    }
    if (widget.prefillOriginalPriceMinor != null) {
      _originalPriceCtrl.text = (widget.prefillOriginalPriceMinor! ~/ 100)
          .toString();
    }
  }

  @override
  void dispose() {
    _unitIdCtrl.dispose();
    _imeiCtrl.dispose();
    _originalPriceCtrl.dispose();
    _adjustedPriceCtrl.dispose();
    _reasonCtrl.dispose();
    _approverCtrl.dispose();
    _effectiveFromCtrl.dispose();
    _effectiveToCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MobileShopSessionGuardWidget(
      resolver: widget.resolver,
      builder: (context, tenantContext) => FeaturePolicyGate(
        featureId: 'PRICE_PROTECTION',
        service: widget.service,
        child: _buildContent(context, tenantContext),
      ),
    );
  }

  Widget _buildContent(BuildContext context, TenantContext tenantContext) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Price Adjustment')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Outcome display
              if (_lastOutcome != null) ...[
                CommerceOutcomeDisplay(
                  outcome: _lastOutcome!,
                  onDismiss: () => setState(() => _lastOutcome = null),
                  onRetry: _lastOutcome!.state == CommerceOutcomeState.rejected
                      ? () => _submit(tenantContext)
                      : null,
                ),
                const SizedBox(height: 16),
              ],

              // Adjustment type selector
              Semantics(
                label: 'Adjustment type',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Adjustment Type',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<PriceAdjustmentType>(
                      segments: PriceAdjustmentType.values
                          .map(
                            (type) => ButtonSegment(
                              value: type,
                              label: Text(type.displayName),
                              icon: Icon(type.icon),
                            ),
                          )
                          .toList(),
                      selected: {_adjustmentType},
                      onSelectionChanged: (types) {
                        setState(() => _adjustmentType = types.first);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Device identification
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _unitIdCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Unit ID',
                        prefixIcon: Icon(Icons.inventory_2_outlined),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _imeiCtrl,
                      decoration: const InputDecoration(
                        labelText: 'IMEI',
                        prefixIcon: Icon(Icons.qr_code_outlined),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(15),
                      ],
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (v.length != 15) return '15 digits';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Pricing section
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _originalPriceCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Original Price (₹)',
                        prefixIcon: Icon(Icons.price_change_outlined),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setState(() {}),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _adjustedPriceCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Adjusted Price (₹)',
                        prefixIcon: Icon(Icons.edit_outlined),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setState(() {}),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Margin impact display
              _MarginImpactCard(
                originalMinor:
                    (int.tryParse(_originalPriceCtrl.text) ?? 0) * 100,
                adjustedMinor:
                    (int.tryParse(_adjustedPriceCtrl.text) ?? 0) * 100,
              ),
              const SizedBox(height: 16),

              // Reason
              TextFormField(
                controller: _reasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Reason for Adjustment',
                  hintText:
                      'e.g. Price drop from manufacturer, promotional campaign',
                  prefixIcon: Icon(Icons.note_outlined),
                ),
                maxLines: 2,
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Reason is required' : null,
              ),
              const SizedBox(height: 12),

              // Effective period
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _effectiveFromCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Effective From',
                        hintText: 'YYYY-MM-DD',
                        prefixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _effectiveToCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Effective To (optional)',
                        hintText: 'YYYY-MM-DD',
                        prefixIcon: Icon(Icons.event_outlined),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Approval section
              Card(
                color: theme.colorScheme.secondaryContainer.withOpacity(0.3),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.approval_outlined,
                            color: theme.colorScheme.secondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Approval Required',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.secondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _approverCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Approved By',
                          hintText: 'Manager/owner name or ID',
                          prefixIcon: Icon(Icons.person_pin_outlined),
                        ),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Approver is required'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        value: _approvalConfirmed,
                        onChanged: (v) => setState(() {
                          _approvalConfirmed = v ?? false;
                        }),
                        title: const Text(
                          'I confirm this adjustment is authorized',
                        ),
                        subtitle: Text(
                          'This action creates an immutable audit record.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Submit button (requires approval confirmation)
              FilledButton.icon(
                onPressed: (_isSubmitting || !_approvalConfirmed)
                    ? null
                    : () => _submit(tenantContext),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outlined),
                label: Text(
                  _isSubmitting
                      ? 'Submitting...'
                      : _approvalConfirmed
                      ? 'Submit Adjustment'
                      : 'Confirm Approval to Submit',
                ),
              ),
              if (!_approvalConfirmed)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Check the approval confirmation above to enable submission.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit(TenantContext tenantCtx) async {
    if (!_formKey.currentState!.validate()) return;
    if (!_approvalConfirmed) return;

    // Destructive/financial confirmation dialog (Req 12.7)
    final confirmed = await _showConfirmationDialog(this.context);
    if (!confirmed) return;

    setState(() {
      _isSubmitting = true;
      _lastOutcome = null;
    });

    try {
      final request = PriceAdjustmentRequest(
        unitId: _unitIdCtrl.text.trim(),
        imei: _imeiCtrl.text.trim(),
        adjustmentType: _adjustmentType.wireValue,
        originalPriceMinor: (int.tryParse(_originalPriceCtrl.text) ?? 0) * 100,
        adjustedPriceMinor: (int.tryParse(_adjustedPriceCtrl.text) ?? 0) * 100,
        reason: _reasonCtrl.text.trim(),
        approvedBy: _approverCtrl.text.trim(),
        effectiveFrom: _effectiveFromCtrl.text.isNotEmpty
            ? _effectiveFromCtrl.text.trim()
            : null,
        effectiveTo: _effectiveToCtrl.text.isNotEmpty
            ? _effectiveToCtrl.text.trim()
            : null,
        currency: 'INR',
      );

      final outcome = await widget.service.submitPriceAdjustment(
        tenantCtx,
        request,
      );
      setState(() => _lastOutcome = outcome);
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<bool> _showConfirmationDialog(BuildContext context) async {
    final originalPrice = (int.tryParse(_originalPriceCtrl.text) ?? 0) * 100;
    final adjustedPrice = (int.tryParse(_adjustedPriceCtrl.text) ?? 0) * 100;
    final impact = adjustedPrice - originalPrice;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Price Adjustment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('IMEI: ${_imeiCtrl.text}'),
            const SizedBox(height: 8),
            Text('Original: ${formatMoney(originalPrice, "INR")}'),
            Text('Adjusted: ${formatMoney(adjustedPrice, "INR")}'),
            Text(
              'Margin Impact: ${impact >= 0 ? "+" : ""}${formatMoney(impact, "INR")}',
              style: TextStyle(
                color: impact < 0 ? Colors.red : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text('Approved by: ${_approverCtrl.text}'),
            const Divider(),
            const Text(
              'This action is financially material and creates an '
              'immutable audit record. Proceed?',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    return result ?? false;
  }
}

// ─── Margin Impact Card ──────────────────────────────────────────────────────

class _MarginImpactCard extends StatelessWidget {
  final int originalMinor;
  final int adjustedMinor;

  const _MarginImpactCard({
    required this.originalMinor,
    required this.adjustedMinor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final impact = adjustedMinor - originalMinor;
    final isReduction = impact < 0;
    final percentChange = originalMinor > 0
        ? ((impact / originalMinor) * 100).toStringAsFixed(1)
        : '0.0';

    if (originalMinor == 0 && adjustedMinor == 0) {
      return const SizedBox.shrink();
    }

    return Semantics(
      label:
          'Margin impact: ${isReduction ? "reduction" : "increase"} '
          'of ${formatMoney(impact.abs(), "INR")}',
      child: Card(
        color: isReduction
            ? Colors.red.withOpacity(0.05)
            : Colors.green.withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                isReduction ? Icons.trending_down : Icons.trending_up,
                color: isReduction ? Colors.red : Colors.green,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Margin Impact', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(
                      '${isReduction ? "" : "+"}${formatMoney(impact, "INR")} ($percentChange%)',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: isReduction ? Colors.red : Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
