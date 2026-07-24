/// Bundle Sale Screen — Handset + Accessories Pricing
///
/// Renders a bundle sale form with:
/// - Separate stock, tax, and accounting lines per item
/// - Handset-accessory relationship preservation
/// - Total breakdown with per-line visibility
/// - Provider-neutral bundle discounts and loyalty integration
///
/// Requirements: 4.8, 10.10, 12.1–12.8
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../auth/tenant_context_resolver.dart';
import '../../widgets/mobile_shop_session_state.dart';
import 'commerce_ui_utils.dart';
import 'mobile_commerce_service.dart';

/// Bundle sale screen for handset + accessory combinations.
///
/// Gated by 'BUNDLES' feature policy. Supports offline queuing
/// for the sale operation.
class BundleSaleScreen extends StatefulWidget {
  /// The commerce service.
  final MobileCommerceService service;

  /// The tenant context resolver.
  final TenantContextResolver resolver;

  /// Optional pre-filled customer ID.
  final String? prefillCustomerId;

  /// Optional pre-filled invoice ID.
  final String? prefillInvoiceId;

  const BundleSaleScreen({
    super.key,
    required this.service,
    required this.resolver,
    this.prefillCustomerId,
    this.prefillInvoiceId,
  });

  @override
  State<BundleSaleScreen> createState() => _BundleSaleScreenState();
}

class _BundleSaleScreenState extends State<BundleSaleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerIdCtrl = TextEditingController();
  final _invoiceIdCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  final _loyaltyRefCtrl = TextEditingController();

  final List<_BundleLineEntry> _lines = [];
  bool _isSubmitting = false;
  CommerceOutcome? _lastOutcome;

  @override
  void initState() {
    super.initState();
    if (widget.prefillCustomerId != null) {
      _customerIdCtrl.text = widget.prefillCustomerId!;
    }
    if (widget.prefillInvoiceId != null) {
      _invoiceIdCtrl.text = widget.prefillInvoiceId!;
    }
    // Start with one handset line
    _addLine('handset');
  }

  @override
  void dispose() {
    _customerIdCtrl.dispose();
    _invoiceIdCtrl.dispose();
    _discountCtrl.dispose();
    _loyaltyRefCtrl.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  void _addLine(String lineType) {
    setState(() {
      _lines.add(_BundleLineEntry(lineType: lineType));
    });
  }

  void _removeLine(int index) {
    setState(() {
      _lines[index].dispose();
      _lines.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MobileShopSessionGuardWidget(
      resolver: widget.resolver,
      builder: (context, tenantContext) => FeaturePolicyGate(
        featureId: 'BUNDLES',
        service: widget.service,
        child: _buildContent(context, tenantContext),
      ),
    );
  }

  Widget _buildContent(BuildContext context, TenantContext tenantContext) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bundle Sale'),
        actions: [
          // Add accessory line
          PopupMenuButton<String>(
            onSelected: _addLine,
            icon: const Icon(Icons.add),
            tooltip: 'Add line item',
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'handset',
                child: ListTile(
                  leading: Icon(Icons.phone_android),
                  title: Text('Handset'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'accessory',
                child: ListTile(
                  leading: Icon(Icons.headphones),
                  title: Text('Accessory'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'service',
                child: ListTile(
                  leading: Icon(Icons.build_circle),
                  title: Text('Service'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
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

              // Customer & Invoice
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _customerIdCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Customer ID',
                        prefixIcon: Icon(Icons.person_outlined),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _invoiceIdCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Invoice ID',
                        prefixIcon: Icon(Icons.receipt_outlined),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Line items
              Text(
                'Bundle Items (${_lines.length})',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),

              ..._lines.asMap().entries.map((entry) {
                final index = entry.key;
                final line = entry.value;
                return _BundleLineCard(
                  key: ValueKey(line.id),
                  entry: line,
                  index: index,
                  onRemove: _lines.length > 1 ? () => _removeLine(index) : null,
                  onChanged: () => setState(() {}),
                );
              }),
              const SizedBox(height: 16),

              // Discount and loyalty
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _discountCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Bundle Discount (₹)',
                        prefixIcon: Icon(Icons.discount_outlined),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _loyaltyRefCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Loyalty Ref (optional)',
                        prefixIcon: Icon(Icons.card_giftcard_outlined),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Summary breakdown
              _BundleSummaryCard(
                lines: _lines,
                discountMinor: (int.tryParse(_discountCtrl.text) ?? 0) * 100,
              ),
              const SizedBox(height: 24),

              // Submit
              FilledButton.icon(
                onPressed: _isSubmitting ? null : () => _submit(tenantContext),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.shopping_cart_checkout_outlined),
                label: Text(
                  _isSubmitting ? 'Processing...' : 'Complete Bundle Sale',
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
      final lines = _lines
          .map(
            (l) => BundleLineItem(
              productId: l.productIdCtrl.text.trim(),
              productName: l.productNameCtrl.text.trim(),
              lineType: l.lineType,
              imei: l.imeiCtrl.text.isNotEmpty ? l.imeiCtrl.text.trim() : null,
              unitPriceMinor: (int.tryParse(l.priceCtrl.text) ?? 0) * 100,
              quantity: int.tryParse(l.quantityCtrl.text) ?? 1,
              taxMinor: (int.tryParse(l.taxCtrl.text) ?? 0) * 100,
              taxCategory: l.taxCategory,
              accountingCode: l.accountingCode,
            ),
          )
          .toList();

      final request = BundleSaleRequest(
        customerId: _customerIdCtrl.text.trim(),
        invoiceId: _invoiceIdCtrl.text.trim(),
        lines: lines,
        discountMinor: _discountCtrl.text.isNotEmpty
            ? (int.tryParse(_discountCtrl.text) ?? 0) * 100
            : null,
        loyaltyReference: _loyaltyRefCtrl.text.isNotEmpty
            ? _loyaltyRefCtrl.text.trim()
            : null,
        currency: 'INR',
      );

      final outcome = await widget.service.submitBundleSale(context, request);
      setState(() => _lastOutcome = outcome);
    } finally {
      setState(() => _isSubmitting = false);
    }
  }
}

// ─── Bundle Line Entry (State) ───────────────────────────────────────────────

class _BundleLineEntry {
  static int _counter = 0;

  final int id;
  final String lineType;
  final productIdCtrl = TextEditingController();
  final productNameCtrl = TextEditingController();
  final imeiCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final quantityCtrl = TextEditingController(text: '1');
  final taxCtrl = TextEditingController(text: '0');

  String taxCategory = 'GST_18';
  String accountingCode = 'SALE_DEVICE';

  _BundleLineEntry({required this.lineType}) : id = _counter++ {
    // Set accounting code based on line type
    switch (lineType) {
      case 'handset':
        accountingCode = 'SALE_DEVICE';
        taxCategory = 'GST_18';
      case 'accessory':
        accountingCode = 'SALE_ACCESSORY';
        taxCategory = 'GST_18';
      case 'service':
        accountingCode = 'SALE_SERVICE';
        taxCategory = 'GST_18';
    }
  }

  void dispose() {
    productIdCtrl.dispose();
    productNameCtrl.dispose();
    imeiCtrl.dispose();
    priceCtrl.dispose();
    quantityCtrl.dispose();
    taxCtrl.dispose();
  }

  int get totalMinor {
    final price = (int.tryParse(priceCtrl.text) ?? 0) * 100;
    final qty = int.tryParse(quantityCtrl.text) ?? 1;
    final tax = (int.tryParse(taxCtrl.text) ?? 0) * 100;
    return price * qty + tax;
  }
}

// ─── Bundle Line Card Widget ─────────────────────────────────────────────────

class _BundleLineCard extends StatelessWidget {
  final _BundleLineEntry entry;
  final int index;
  final VoidCallback? onRemove;
  final VoidCallback onChanged;

  const _BundleLineCard({
    super.key,
    required this.entry,
    required this.index,
    this.onRemove,
    required this.onChanged,
  });

  IconData get _typeIcon => switch (entry.lineType) {
    'handset' => Icons.phone_android,
    'accessory' => Icons.headphones,
    'service' => Icons.build_circle,
    _ => Icons.inventory_2,
  };

  String get _typeLabel => switch (entry.lineType) {
    'handset' => 'Handset',
    'accessory' => 'Accessory',
    'service' => 'Service',
    _ => 'Item',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(_typeIcon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '$_typeLabel #${index + 1}',
                  style: theme.textTheme.titleSmall,
                ),
                const Spacer(),
                // Accounting code chip
                Chip(
                  label: Text(
                    entry.accountingCode,
                    style: theme.textTheme.labelSmall,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                if (onRemove != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: onRemove,
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Remove',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),

            // Product fields
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: entry.productIdCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Product ID',
                      isDense: true,
                    ),
                    onChanged: (_) => onChanged(),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: entry.productNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Product Name',
                      isDense: true,
                    ),
                    onChanged: (_) => onChanged(),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // IMEI (for handsets only)
            if (entry.lineType == 'handset')
              TextFormField(
                controller: entry.imeiCtrl,
                decoration: const InputDecoration(
                  labelText: 'IMEI (15 digits)',
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(15),
                ],
                onChanged: (_) => onChanged(),
              ),
            if (entry.lineType == 'handset') const SizedBox(height: 8),

            // Price, Qty, Tax (separate lines)
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: entry.priceCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Price (₹)',
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => onChanged(),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 60,
                  child: TextFormField(
                    controller: entry.quantityCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Qty',
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => onChanged(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: entry.taxCtrl,
                    decoration: InputDecoration(
                      labelText: 'Tax (₹)',
                      isDense: true,
                      suffixText: entry.taxCategory,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => onChanged(),
                  ),
                ),
              ],
            ),

            // Line total
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Line total: ${formatMoney(entry.totalMinor, "INR")}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Bundle Summary Card ─────────────────────────────────────────────────────

class _BundleSummaryCard extends StatelessWidget {
  final List<_BundleLineEntry> lines;
  final int discountMinor;

  const _BundleSummaryCard({required this.lines, required this.discountMinor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Calculate totals by category
    int handsetTotal = 0;
    int accessoryTotal = 0;
    int serviceTotal = 0;
    int totalTax = 0;

    for (final line in lines) {
      final price = (int.tryParse(line.priceCtrl.text) ?? 0) * 100;
      final qty = int.tryParse(line.quantityCtrl.text) ?? 1;
      final tax = (int.tryParse(line.taxCtrl.text) ?? 0) * 100;
      final lineSubtotal = price * qty;
      totalTax += tax;

      switch (line.lineType) {
        case 'handset':
          handsetTotal += lineSubtotal;
        case 'accessory':
          accessoryTotal += lineSubtotal;
        case 'service':
          serviceTotal += lineSubtotal;
      }
    }

    final subtotal = handsetTotal + accessoryTotal + serviceTotal;
    final grandTotal = subtotal + totalTax - discountMinor;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bundle Summary', style: theme.textTheme.titleSmall),
            const Divider(),
            // Stock lines
            if (handsetTotal > 0)
              _SummaryLine('Handsets', formatMoney(handsetTotal, 'INR')),
            if (accessoryTotal > 0)
              _SummaryLine('Accessories', formatMoney(accessoryTotal, 'INR')),
            if (serviceTotal > 0)
              _SummaryLine('Services', formatMoney(serviceTotal, 'INR')),
            const Divider(height: 8),
            _SummaryLine('Subtotal', formatMoney(subtotal, 'INR')),
            // Tax line
            _SummaryLine('Tax (GST)', formatMoney(totalTax, 'INR')),
            // Discount
            if (discountMinor > 0)
              _SummaryLine(
                'Bundle Discount',
                '-${formatMoney(discountMinor, "INR")}',
                isNegative: true,
              ),
            const Divider(),
            // Grand total
            _SummaryLine('Total', formatMoney(grandTotal, 'INR'), isBold: true),
          ],
        ),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final bool isNegative;

  const _SummaryLine(
    this.label,
    this.value, {
    this.isBold = false,
    this.isNegative = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: isBold
                ? theme.textTheme.titleSmall
                : theme.textTheme.bodySmall,
          ),
          Text(
            value,
            style:
                (isBold
                        ? theme.textTheme.titleSmall
                        : theme.textTheme.bodyMedium)
                    ?.copyWith(
                      fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                      color: isNegative ? Colors.green : null,
                    ),
          ),
        ],
      ),
    );
  }
}
