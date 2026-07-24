/// SIM / Recharge Screen — Provider-Neutral Recharge Form
///
/// Renders a provider-neutral SIM activation and recharge form with:
/// - Masked mobile numbers for display
/// - Pending verification states (providerPending, ambiguous)
/// - Online-only enforcement (cannot proceed offline)
/// - Feature policy gating
///
/// Requirements: 10.5, 10.7–10.9, 12.1–12.8
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../auth/tenant_context_resolver.dart';
import '../../models/recharge_models.dart';
import '../../widgets/mobile_shop_session_state.dart';
import 'commerce_ui_utils.dart';
import 'mobile_commerce_service.dart';

/// SIM and recharge transaction screen.
///
/// Gated by 'SIM_RECHARGE' feature policy. Requires online connectivity
/// for real-time provider submission.
class SimRechargeScreen extends StatefulWidget {
  /// The commerce service for submitting recharge transactions.
  final MobileCommerceService service;

  /// The tenant context resolver.
  final TenantContextResolver resolver;

  const SimRechargeScreen({
    super.key,
    required this.service,
    required this.resolver,
  });

  @override
  State<SimRechargeScreen> createState() => _SimRechargeScreenState();
}

class _SimRechargeScreenState extends State<SimRechargeScreen> {
  final _formKey = GlobalKey<FormState>();

  final _mobileNumberCtrl = TextEditingController();
  final _planIdCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _providerCtrl = TextEditingController();
  final _customerIdCtrl = TextEditingController();

  RechargeType _selectedType = RechargeType.prepaid;
  bool _isSubmitting = false;
  CommerceOutcome? _lastOutcome;

  @override
  void dispose() {
    _mobileNumberCtrl.dispose();
    _planIdCtrl.dispose();
    _amountCtrl.dispose();
    _providerCtrl.dispose();
    _customerIdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MobileShopSessionGuardWidget(
      resolver: widget.resolver,
      builder: (context, tenantContext) => FeaturePolicyGate(
        featureId: 'SIM_RECHARGE',
        service: widget.service,
        child: _buildContent(context, tenantContext),
      ),
    );
  }

  Widget _buildContent(BuildContext context, TenantContext tenantContext) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('SIM / Recharge')),
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

              // Connectivity requirement notice
              Card(
                color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.wifi_outlined,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This operation requires an active internet connection for real-time provider verification.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Recharge type selector
              Semantics(
                label: 'Recharge type selection',
                child: SegmentedButton<RechargeType>(
                  segments: const [
                    ButtonSegment(
                      value: RechargeType.prepaid,
                      label: Text('Prepaid'),
                      icon: Icon(Icons.sim_card_outlined),
                    ),
                    ButtonSegment(
                      value: RechargeType.postpaid,
                      label: Text('Postpaid'),
                      icon: Icon(Icons.phone_outlined),
                    ),
                    ButtonSegment(
                      value: RechargeType.dataPack,
                      label: Text('Data'),
                      icon: Icon(Icons.data_usage_outlined),
                    ),
                    ButtonSegment(
                      value: RechargeType.dth,
                      label: Text('DTH'),
                      icon: Icon(Icons.tv_outlined),
                    ),
                  ],
                  selected: {_selectedType},
                  onSelectionChanged: (types) {
                    setState(() => _selectedType = types.first);
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Provider field
              TextFormField(
                controller: _providerCtrl,
                decoration: const InputDecoration(
                  labelText: 'Provider',
                  hintText: 'e.g. Jio, Airtel, Vi, BSNL',
                  prefixIcon: Icon(Icons.cell_tower_outlined),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Provider is required' : null,
              ),
              const SizedBox(height: 12),

              // Mobile number with masking
              TextFormField(
                controller: _mobileNumberCtrl,
                decoration: InputDecoration(
                  labelText: 'Mobile Number',
                  hintText: '10-digit mobile number',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  suffixIcon: _mobileNumberCtrl.text.length >= 10
                      ? Tooltip(
                          message:
                              'Masked: ${SensitiveMask.maskMobileNumber(_mobileNumberCtrl.text)}',
                          child: const Icon(Icons.visibility_off_outlined),
                        )
                      : null,
                ),
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  if (v == null || v.isEmpty)
                    return 'Mobile number is required';
                  if (v.length != 10) return 'Must be 10 digits';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Plan ID
              TextFormField(
                controller: _planIdCtrl,
                decoration: const InputDecoration(
                  labelText: 'Plan ID / Recharge Code',
                  hintText: 'Enter plan code or browse plans',
                  prefixIcon: Icon(Icons.local_offer_outlined),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Plan is required' : null,
              ),
              const SizedBox(height: 12),

              // Amount
              TextFormField(
                controller: _amountCtrl,
                decoration: const InputDecoration(
                  labelText: 'Amount (₹)',
                  prefixIcon: Icon(Icons.currency_rupee_outlined),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Amount is required';
                  final amount = int.tryParse(v);
                  if (amount == null || amount <= 0) return 'Invalid amount';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Customer reference (optional)
              TextFormField(
                controller: _customerIdCtrl,
                decoration: const InputDecoration(
                  labelText: 'Customer Reference (optional)',
                  hintText: 'Link to customer record',
                  prefixIcon: Icon(Icons.person_outlined),
                ),
              ),
              const SizedBox(height: 24),

              // Summary card
              if (_amountCtrl.text.isNotEmpty) ...[
                _RechargeSummaryCard(
                  type: _selectedType,
                  provider: _providerCtrl.text,
                  maskedNumber: _mobileNumberCtrl.text.length >= 10
                      ? SensitiveMask.maskMobileNumber(_mobileNumberCtrl.text)
                      : _mobileNumberCtrl.text,
                  amount: int.tryParse(_amountCtrl.text) ?? 0,
                ),
                const SizedBox(height: 16),
              ],

              // Submit button
              FilledButton.icon(
                onPressed: _isSubmitting ? null : () => _submit(tenantContext),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
                label: Text(
                  _isSubmitting ? 'Processing...' : 'Submit Recharge',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit(TenantContext context) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _lastOutcome = null;
    });

    try {
      final request = RechargeRequest(
        mobileNumber: _mobileNumberCtrl.text.trim(),
        rechargeType: _selectedType,
        provider: _providerCtrl.text.trim(),
        planId: _planIdCtrl.text.trim(),
        amountMinor: (int.tryParse(_amountCtrl.text) ?? 0) * 100,
        currency: 'INR',
        customerId: _customerIdCtrl.text.isNotEmpty
            ? _customerIdCtrl.text.trim()
            : null,
      );

      final outcome = await widget.service.submitRecharge(context, request);
      setState(() => _lastOutcome = outcome);
    } finally {
      setState(() => _isSubmitting = false);
    }
  }
}

// ─── Summary Card ────────────────────────────────────────────────────────────

class _RechargeSummaryCard extends StatelessWidget {
  final RechargeType type;
  final String provider;
  final String maskedNumber;
  final int amount;

  const _RechargeSummaryCard({
    required this.type,
    required this.provider,
    required this.maskedNumber,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recharge Summary', style: theme.textTheme.titleSmall),
            const Divider(),
            _SummaryRow('Type', type.name.toUpperCase()),
            _SummaryRow('Provider', provider),
            _SummaryRow('Number', maskedNumber),
            _SummaryRow('Amount', formatMoney(amount * 100, 'INR')),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
