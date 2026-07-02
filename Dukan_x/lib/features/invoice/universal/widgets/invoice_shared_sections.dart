import 'package:flutter/material.dart';

import '../model/universal_invoice_data.dart';

/// Reusable invoice section components shared by BOTH the universal engine and
/// the dedicated templates (Pharmacy, Restaurant, Jewellery).
///
/// Phase 4 requirement: dedicated templates must REUSE these components rather
/// than copy-paste them. Only the business-specific product table is bespoke;
/// business info, customer info, tax, payment/summary, bank details, terms,
/// QR, and signature are all defined once here.
class InvoiceSharedSections {
  static Widget logo(BuildContext c, UniversalInvoiceData d) {
    if (d.logoImage != null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Image.memory(d.logoImage!, height: 56),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: CircleAvatar(radius: 24, child: Text(initials(d.shopName))),
    );
  }

  static Widget businessInfo(BuildContext c, UniversalInvoiceData d) {
    final t = Theme.of(c).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(d.shopName, style: t.titleLarge),
        if (d.tagline != null && d.tagline!.isNotEmpty) Text(d.tagline!),
        Text(d.address),
        Text('Mobile: ${d.mobile}'),
        if (d.gstin != null && d.gstin!.isNotEmpty) Text('GSTIN: ${d.gstin}'),
        if (d.drugLicenseNumber != null && d.drugLicenseNumber!.isNotEmpty)
          Text('DL No: ${d.drugLicenseNumber}'),
        const Divider(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text('Invoice #${d.invoiceNumber}'), Text(date(d.date))],
        ),
      ],
    );
  }

  static Widget customerInfo(BuildContext c, UniversalInvoiceData d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Bill To:', style: bold(c)),
        Text(d.customerName.isEmpty ? 'Walk-in Customer' : d.customerName),
        if (d.customerMobile.isNotEmpty) Text(d.customerMobile),
        if (d.customerAddress != null && d.customerAddress!.isNotEmpty)
          Text(d.customerAddress!),
        if (d.customerGstin != null && d.customerGstin!.isNotEmpty)
          Text('GSTIN: ${d.customerGstin}'),
      ],
    );
  }

  static Widget shipping(BuildContext c, UniversalInvoiceData d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ship To:', style: bold(c)),
        Text(d.shippingAddress ?? d.customerAddress ?? '-'),
        if (d.transportDetails != null && d.transportDetails!.isNotEmpty)
          Text('Transport: ${d.transportDetails}'),
      ],
    );
  }

  static Widget tax(BuildContext c, UniversalInvoiceData d) {
    return Align(
      alignment: Alignment.centerRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!d.isInterState) ...[
            Text('CGST: ${money(d.totalCgst)}'),
            Text('SGST: ${money(d.totalSgst)}'),
          ],
          if (d.isInterState) Text('IGST: ${money(d.totalIgst)}'),
          Text('Tax Total: ${money(d.totalTax)}'),
        ],
      ),
    );
  }

  static Widget discount(BuildContext c, UniversalInvoiceData d) {
    if (d.totalDiscount <= 0) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerRight,
      child: Text('Discount: -${money(d.totalDiscount)}'),
    );
  }

  /// Shared payment + invoice-summary component.
  static Widget payment(BuildContext c, UniversalInvoiceData d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Text('TOTAL: ${money(d.grandTotal)}', style: bold(c)),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Mode: ${d.paymentMode}'),
            Text('Paid: ${money(d.paidAmount)}'),
            Text('Due: ${money(d.dueAmount)}'),
          ],
        ),
      ],
    );
  }

  static Widget bankDetails(BuildContext c, UniversalInvoiceData d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Bank Details:', style: bold(c)),
        Text('Bank: ${d.bankName ?? '-'}'),
        Text('A/C: ${d.bankAccountNumber ?? '-'}'),
        Text('IFSC: ${d.bankIfsc ?? '-'}'),
      ],
    );
  }

  static Widget warranty(BuildContext c, UniversalInvoiceData d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Warranty:', style: bold(c)),
        Text(
          d.warrantyTerms ??
              'Warranty valid only with original invoice. Terms apply.',
        ),
      ],
    );
  }

  static Widget serialImei(BuildContext c, UniversalInvoiceData d) {
    return Text(
      'IMEI / Serial numbers recorded above are required for warranty claims.',
      style: Theme.of(c).textTheme.bodySmall,
    );
  }

  static Widget notes(BuildContext c, UniversalInvoiceData d) {
    if (d.notes == null || d.notes!.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Notes:', style: bold(c)),
        Text(d.notes!),
      ],
    );
  }

  static Widget terms(BuildContext c, UniversalInvoiceData d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Terms & Conditions:', style: bold(c)),
        Text(d.terms ?? 'Thank you for your business!'),
      ],
    );
  }

  static Widget qr(BuildContext c, UniversalInvoiceData d) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(border: Border.all()),
          child: const Icon(Icons.qr_code_2, size: 40),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            d.upiId != null && d.upiId!.isNotEmpty
                ? 'Scan to Pay: ${d.upiId}'
                : 'Scan to Pay',
          ),
        ),
      ],
    );
  }

  static Widget signature(BuildContext c, UniversalInvoiceData d) {
    return Align(
      alignment: Alignment.centerRight,
      child: Column(
        children: [
          if (d.signatureImage != null)
            Image.memory(d.signatureImage!, height: 40)
          else
            const SizedBox(height: 40, width: 120, child: Divider()),
          const Text('Authorized Signatory'),
        ],
      ),
    );
  }

  static Widget watermark(BuildContext c, UniversalInvoiceData d) {
    return Transform.rotate(
      angle: -0.5,
      child: Text(
        d.watermarkText ?? 'DRAFT',
        style: Theme.of(c).textTheme.displayLarge?.copyWith(
          color: Colors.grey.withValues(alpha: 0.15),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ── shared formatting helpers ──
  static TextStyle? bold(BuildContext c) =>
      Theme.of(c).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold);

  static String money(double v) => '\u20B9${v.toStringAsFixed(2)}';

  static String date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}
