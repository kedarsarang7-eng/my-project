// ============================================================================
// BILL RIGHT PANEL — Bill Summary & Payment
// ============================================================================
// Contains:
//   - Tabs: Bill Summary | Payment
//   - TotalsPanel: Subtotal, Discount, Tax, Shipping, Grand Total
//   - PaymentPanel: Method dropdown, Amount, Reference
//   - Action buttons: Save as Draft | Generate Invoice & Print | Send via Email | Cancel
// All amounts are passed in and recalculated reactively in parent.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'bill_creation_tokens.dart';

class BillRightPanel extends StatefulWidget {
  final double subtotal;
  final double discountAmount;
  final double taxAmount;
  final double shipping;
  final double grandTotal;

  final List<String> paymentMethods;
  final String selectedPaymentMethod;
  final double paymentAmount;
  final String paymentReference;

  final ValueChanged<String> onPaymentMethodChanged;
  final ValueChanged<double> onPaymentAmountChanged;
  final ValueChanged<String> onPaymentReferenceChanged;
  final ValueChanged<double> onShippingChanged;

  final bool isSaving;
  final VoidCallback onSaveDraft;
  final VoidCallback onGenerateAndPrint;
  final VoidCallback onSendEmail;
  final VoidCallback onCancel;

  const BillRightPanel({
    super.key,
    required this.subtotal,
    required this.discountAmount,
    required this.taxAmount,
    required this.shipping,
    required this.grandTotal,
    required this.paymentMethods,
    required this.selectedPaymentMethod,
    required this.paymentAmount,
    required this.paymentReference,
    required this.onPaymentMethodChanged,
    required this.onPaymentAmountChanged,
    required this.onPaymentReferenceChanged,
    required this.onShippingChanged,
    required this.isSaving,
    required this.onSaveDraft,
    required this.onGenerateAndPrint,
    required this.onSendEmail,
    required this.onCancel,
  });

  @override
  State<BillRightPanel> createState() => _BillRightPanelState();
}

class _BillRightPanelState extends State<BillRightPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  late TextEditingController _amountCtrl;
  late TextEditingController _refCtrl;
  late TextEditingController _shippingCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _amountCtrl = TextEditingController(
      text: widget.paymentAmount == 0
          ? ''
          : widget.paymentAmount.toStringAsFixed(2),
    );
    _refCtrl = TextEditingController(text: widget.paymentReference);
    _shippingCtrl = TextEditingController(
      text: widget.shipping == 0 ? '' : widget.shipping.toStringAsFixed(2),
    );
  }

  @override
  void didUpdateWidget(BillRightPanel old) {
    super.didUpdateWidget(old);
    if (old.paymentAmount != widget.paymentAmount) {
      final formatted = widget.paymentAmount == 0
          ? ''
          : widget.paymentAmount.toStringAsFixed(2);
      if (_amountCtrl.text != formatted) _amountCtrl.text = formatted;
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _amountCtrl.dispose();
    _refCtrl.dispose();
    _shippingCtrl.dispose();
    super.dispose();
  }

  // Payment amount validation
  bool get _amountExceedsTotal {
    final entered = double.tryParse(_amountCtrl.text) ?? 0;
    return entered > widget.grandTotal && widget.grandTotal > 0;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: BillTokens.cardBackground,
        borderRadius:
            BorderRadius.circular(BillTokens.cardRadius),
        border: Border.all(color: BillTokens.borderColor),
        boxShadow: BillTokens.cardShadow,
      ),
      child: Column(
        children: [
          // ── Tabs ──────────────────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: BillTokens.borderColor),
              ),
            ),
            child: TabBar(
              controller: _tabCtrl,
              labelColor: BillTokens.primaryBlue,
              unselectedLabelColor: BillTokens.textSecondary,
              indicatorColor: BillTokens.primaryBlue,
              indicatorWeight: 2,
              labelStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'Bill Summary'),
                Tab(text: 'Payment'),
              ],
            ),
          ),

          // ── Tab bodies ────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildSummaryTab(),
                _buildPaymentTab(),
              ],
            ),
          ),

          // ── Action buttons ────────────────────────────────────────────────
          _buildActionButtons(),
        ],
      ),
    );
  }

  // ── Bill Summary Tab ─────────────────────────────────────────────────────
  Widget _buildSummaryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(BillTokens.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Totals', style: BillTokens.sectionLabel),
          const SizedBox(height: 12),

          _totalRow('Subtotal', widget.subtotal),
          const SizedBox(height: 8),
          _totalRow('Discount', widget.discountAmount),
          const SizedBox(height: 8),
          _totalRow('Tax (e.g., VAT/GST)', widget.taxAmount),
          const SizedBox(height: 8),
          _shippingRow(),
          const Divider(height: 24, color: BillTokens.borderColor),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('GRAND TOTAL', style: BillTokens.grandTotalLabel),
              Text(
                '₹ ${widget.grandTotal.toStringAsFixed(2)}',
                style: BillTokens.grandTotalValue,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: BillTokens.totalLabel),
        Text(
          '₹ ${amount.toStringAsFixed(2)}',
          style: BillTokens.tableBody,
        ),
      ],
    );
  }

  Widget _shippingRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Shipping', style: BillTokens.totalLabel),
        SizedBox(
          width: 80,
          height: 28,
          child: TextField(
            controller: _shippingCtrl,
            style: BillTokens.tableBody,
            textAlign: TextAlign.right,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: BillTokens.compactInput(hint: '0.00'),
            onEditingComplete: () {
              widget.onShippingChanged(
                  double.tryParse(_shippingCtrl.text) ?? 0);
            },
            onTapOutside: (_) {
              widget.onShippingChanged(
                  double.tryParse(_shippingCtrl.text) ?? 0);
            },
          ),
        ),
      ],
    );
  }

  // ── Payment Tab ───────────────────────────────────────────────────────────
  Widget _buildPaymentTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(BillTokens.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Add Payment', style: BillTokens.sectionLabel),
          const SizedBox(height: 12),

          // Payment Method
          const Text(
            'Payment Method',
            style: TextStyle(fontSize: 12, color: BillTokens.textSecondary),
          ),
          const SizedBox(height: 6),
          _PaymentMethodDropdown(
            value: widget.selectedPaymentMethod,
            options: widget.paymentMethods,
            onChanged: widget.onPaymentMethodChanged,
          ),

          const SizedBox(height: 12),

          // Amount
          const Text(
            'Amount',
            style: TextStyle(fontSize: 12, color: BillTokens.textSecondary),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _amountCtrl,
            style: BillTokens.tableBody,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: BillTokens.compactInput().copyWith(
              errorText: _amountExceedsTotal
                  ? 'Amount exceeds grand total'
                  : null,
              errorStyle:
                  const TextStyle(fontSize: 10, color: Colors.redAccent),
            ),
            onEditingComplete: () {
              widget.onPaymentAmountChanged(
                  double.tryParse(_amountCtrl.text) ?? 0);
            },
            onTapOutside: (_) {
              widget.onPaymentAmountChanged(
                  double.tryParse(_amountCtrl.text) ?? 0);
            },
          ),

          const SizedBox(height: 12),

          // Reference
          const Text(
            'Reference',
            style: TextStyle(fontSize: 12, color: BillTokens.textSecondary),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _refCtrl,
            style: BillTokens.tableBody,
            decoration: BillTokens.compactInput(hint: 'Cheque no., UTR, etc.'),
            onChanged: widget.onPaymentReferenceChanged,
          ),
        ],
      ),
    );
  }

  // ── Action Buttons ────────────────────────────────────────────────────────
  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: BillTokens.borderColor)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Save as Draft
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.isSaving ? null : widget.onSaveDraft,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: BillTokens.textPrimary,
                    side: const BorderSide(color: BillTokens.borderColor),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(BillTokens.buttonRadius)),
                    textStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Save as Draft'),
                ),
              ),
              const SizedBox(width: 8),
              // Generate Invoice & Print
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed:
                      widget.isSaving ? null : widget.onGenerateAndPrint,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BillTokens.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(BillTokens.buttonRadius)),
                    textStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  child: widget.isSaving
                      ? const SizedBox(
                          height: 14,
                          width: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Generate Invoice & Print'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Send via Email
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.isSaving ? null : widget.onSendEmail,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: BillTokens.primaryBlue,
                    side:
                        const BorderSide(color: BillTokens.primaryBlue),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(BillTokens.buttonRadius)),
                    textStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Send via Email'),
                ),
              ),
              const SizedBox(width: 8),
              // Cancel
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.isSaving ? null : widget.onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: BillTokens.textSecondary,
                    side: const BorderSide(color: BillTokens.borderColor),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(BillTokens.buttonRadius)),
                    textStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodDropdown extends StatelessWidget {
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  const _PaymentMethodDropdown({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveOptions =
        options.contains(value) ? options : [value, ...options];

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: BillTokens.borderColor),
        borderRadius: BorderRadius.circular(BillTokens.inputRadius),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          isDense: true,
          style: BillTokens.tableBody,
          icon: const Icon(Icons.keyboard_arrow_down,
              size: 16, color: BillTokens.textSecondary),
          hint: const Text('Cash, Card, Online, etc.',
              style: TextStyle(
                  color: BillTokens.textSecondary, fontSize: 12)),
          items: effectiveOptions
              .map((m) => DropdownMenuItem(value: m, child: Text(m)))
              .toList(),
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
        ),
      ),
    );
  }
}
