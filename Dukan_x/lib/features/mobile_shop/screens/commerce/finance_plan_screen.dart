/// Finance Plan Screen — EMI/Finance Provider-Neutral Form
///
/// Renders a provider-neutral finance plan application form with:
/// - Masked sensitive values (PAN, account numbers)
/// - Pending approval states (never shows false success)
/// - Offline data preservation when connectivity is required
/// - Feature policy gating
///
/// Requirements: 10.4–10.6, 12.1–12.8
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../auth/tenant_context_resolver.dart';
import '../../config/feature_policy_config.dart';
import '../../models/common_models.dart';
import '../../widgets/mobile_shop_session_state.dart';
import 'commerce_ui_utils.dart';
import 'mobile_commerce_service.dart';

/// Finance plan application screen.
///
/// Gated by 'FINANCE_PLANS' feature policy. Requires online connectivity
/// for provider verification (offline-ineligible per config).
class FinancePlanScreen extends StatefulWidget {
  /// The commerce service for submitting finance plans.
  final MobileCommerceService service;

  /// The tenant context resolver for session validation.
  final TenantContextResolver resolver;

  /// Optional pre-filled invoice ID (from a sale flow).
  final String? prefillInvoiceId;

  /// Optional pre-filled IMEI (from a sale flow).
  final String? prefillImei;

  const FinancePlanScreen({
    super.key,
    required this.service,
    required this.resolver,
    this.prefillInvoiceId,
    this.prefillImei,
  });

  @override
  State<FinancePlanScreen> createState() => _FinancePlanScreenState();
}

class _FinancePlanScreenState extends State<FinancePlanScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers for form fields — preserved across state changes
  final _customerIdCtrl = TextEditingController();
  final _customerNameCtrl = TextEditingController();
  final _invoiceIdCtrl = TextEditingController();
  final _imeiCtrl = TextEditingController();
  final _providerCtrl = TextEditingController();
  final _principalCtrl = TextEditingController();
  final _downPaymentCtrl = TextEditingController();
  final _interestRateCtrl = TextEditingController();
  final _tenureCtrl = TextEditingController();
  final _consentRefCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  bool _isSubmitting = false;
  CommerceOutcome? _lastOutcome;
  bool _showMaskedPreview = false;

  @override
  void initState() {
    super.initState();
    if (widget.prefillInvoiceId != null) {
      _invoiceIdCtrl.text = widget.prefillInvoiceId!;
    }
    if (widget.prefillImei != null) {
      _imeiCtrl.text = widget.prefillImei!;
    }
  }

  @override
  void dispose() {
    _customerIdCtrl.dispose();
    _customerNameCtrl.dispose();
    _invoiceIdCtrl.dispose();
    _imeiCtrl.dispose();
    _providerCtrl.dispose();
    _principalCtrl.dispose();
    _downPaymentCtrl.dispose();
    _interestRateCtrl.dispose();
    _tenureCtrl.dispose();
    _consentRefCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MobileShopSessionGuardWidget(
      resolver: widget.resolver,
      builder: (context, tenantContext) => FeaturePolicyGate(
        featureId: 'FINANCE_PLANS',
        service: widget.service,
        child: _buildContent(context, tenantContext),
      ),
    );
  }

  Widget _buildContent(BuildContext context, TenantContext tenantContext) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finance Plan Application'),
        actions: [
          // Toggle masked preview
          IconButton(
            onPressed: () =>
                setState(() => _showMaskedPreview = !_showMaskedPreview),
            icon: Icon(
              _showMaskedPreview ? Icons.visibility_off : Icons.visibility,
            ),
            tooltip: _showMaskedPreview
                ? 'Hide preview'
                : 'Show masked preview',
          ),
        ],
      ),
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

              // Offline banner
              if (_lastOutcome?.isOffline == true) ...[
                OfflinePreservationBanner(
                  operationType: 'finance plan',
                  onRetryNow: () => _submit(tenantContext),
                ),
                const SizedBox(height: 16),
              ],

              // Provider section (provider-neutral)
              _SectionHeader(title: 'Provider', icon: Icons.business_outlined),
              const SizedBox(height: 8),
              TextFormField(
                controller: _providerCtrl,
                decoration: const InputDecoration(
                  labelText: 'Finance Provider',
                  hintText: 'e.g. Bajaj Finserv, HDFC, etc.',
                  prefixIcon: Icon(Icons.account_balance_outlined),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Provider is required' : null,
              ),
              const SizedBox(height: 16),

              // Customer section
              _SectionHeader(title: 'Customer', icon: Icons.person_outlined),
              const SizedBox(height: 8),
              TextFormField(
                controller: _customerIdCtrl,
                decoration: const InputDecoration(
                  labelText: 'Customer ID / PAN',
                  hintText: 'Enter PAN or customer reference',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Customer ID is required' : null,
              ),
              if (_showMaskedPreview && _customerIdCtrl.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 48),
                  child: Text(
                    'Display: ${SensitiveMask.maskPan(_customerIdCtrl.text)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _customerNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Customer Name',
                  prefixIcon: Icon(Icons.person_outlined),
                ),
                validator: (v) => (v == null || v.isEmpty)
                    ? 'Customer name is required'
                    : null,
              ),
              const SizedBox(height: 16),

              // Device section
              _SectionHeader(
                title: 'Device',
                icon: Icons.phone_android_outlined,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _invoiceIdCtrl,
                decoration: const InputDecoration(
                  labelText: 'Invoice ID',
                  prefixIcon: Icon(Icons.receipt_outlined),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Invoice ID is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _imeiCtrl,
                decoration: const InputDecoration(
                  labelText: 'IMEI Number',
                  prefixIcon: Icon(Icons.qr_code_outlined),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(15),
                ],
                validator: (v) {
                  if (v == null || v.isEmpty) return 'IMEI is required';
                  if (v.length != 15) return 'IMEI must be 15 digits';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Finance terms section
              _SectionHeader(
                title: 'Finance Terms',
                icon: Icons.calculate_outlined,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _principalCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Principal (₹)',
                        prefixIcon: Icon(Icons.currency_rupee_outlined),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _downPaymentCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Down Payment (₹)',
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _interestRateCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Interest Rate (bps)',
                        hintText: 'e.g. 1200 = 12%',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _tenureCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Tenure (months)',
                        hintText: 'e.g. 6, 9, 12, 18, 24',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        final months = int.tryParse(v);
                        if (months == null || months < 1 || months > 60) {
                          return '1–60 months';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _consentRefCtrl,
                decoration: const InputDecoration(
                  labelText: 'Consent Reference (optional)',
                  hintText: 'Provider consent/OTP reference',
                  prefixIcon: Icon(Icons.verified_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  prefixIcon: Icon(Icons.note_outlined),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),

              // EMI preview
              if (_principalCtrl.text.isNotEmpty &&
                  _tenureCtrl.text.isNotEmpty) ...[
                _EmiPreviewCard(
                  principalMinor:
                      (int.tryParse(_principalCtrl.text) ?? 0) * 100,
                  downPaymentMinor:
                      (int.tryParse(_downPaymentCtrl.text) ?? 0) * 100,
                  interestBps: int.tryParse(_interestRateCtrl.text) ?? 0,
                  tenureMonths: int.tryParse(_tenureCtrl.text) ?? 1,
                ),
                const SizedBox(height: 24),
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
                  _isSubmitting ? 'Submitting...' : 'Submit Application',
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
      final request = FinancePlanRequest(
        customerId: _customerIdCtrl.text.trim(),
        customerName: _customerNameCtrl.text.trim(),
        invoiceId: _invoiceIdCtrl.text.trim(),
        imei: _imeiCtrl.text.trim(),
        unitId: _imeiCtrl.text.trim(), // Unit ID derived from IMEI
        provider: _providerCtrl.text.trim(),
        principalAmountMinor: (int.tryParse(_principalCtrl.text) ?? 0) * 100,
        downPaymentMinor: (int.tryParse(_downPaymentCtrl.text) ?? 0) * 100,
        interestRateBasisPoints: int.tryParse(_interestRateCtrl.text) ?? 0,
        tenureMonths: int.tryParse(_tenureCtrl.text) ?? 1,
        currency: 'INR',
        consentReference: _consentRefCtrl.text.isNotEmpty
            ? _consentRefCtrl.text.trim()
            : null,
        notes: _notesCtrl.text.isNotEmpty ? _notesCtrl.text.trim() : null,
      );

      final outcome = await widget.service.submitFinancePlan(context, request);
      setState(() => _lastOutcome = outcome);
    } finally {
      setState(() => _isSubmitting = false);
    }
  }
}

// ─── Section Header ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }
}

// ─── EMI Preview Card ────────────────────────────────────────────────────────

class _EmiPreviewCard extends StatelessWidget {
  final int principalMinor;
  final int downPaymentMinor;
  final int interestBps;
  final int tenureMonths;

  const _EmiPreviewCard({
    required this.principalMinor,
    required this.downPaymentMinor,
    required this.interestBps,
    required this.tenureMonths,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loanAmount = principalMinor - downPaymentMinor;
    final monthlyRate = interestBps / 120000; // bps to monthly decimal
    final emi = tenureMonths > 0 && monthlyRate > 0
        ? (loanAmount * monthlyRate * _pow(1 + monthlyRate, tenureMonths)) /
              (_pow(1 + monthlyRate, tenureMonths) - 1)
        : loanAmount / (tenureMonths > 0 ? tenureMonths : 1);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('EMI Preview', style: theme.textTheme.titleSmall),
            const Divider(),
            _PreviewRow('Loan Amount', formatMoney(loanAmount.round(), 'INR')),
            _PreviewRow('Monthly EMI', formatMoney(emi.round(), 'INR')),
            _PreviewRow(
              'Total Payable',
              formatMoney((emi * tenureMonths).round(), 'INR'),
            ),
            _PreviewRow('Tenure', '$tenureMonths months'),
          ],
        ),
      ),
    );
  }

  double _pow(double base, int exp) {
    var result = 1.0;
    for (var i = 0; i < exp; i++) {
      result *= base;
    }
    return result;
  }
}

class _PreviewRow extends StatelessWidget {
  final String label;
  final String value;

  const _PreviewRow(this.label, this.value);

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
