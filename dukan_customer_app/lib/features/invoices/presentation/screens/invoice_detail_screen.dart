import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:dukanx_shared/dukanx_shared.dart';
import '../../data/invoice_repository.dart';

class InvoiceDetailScreen extends ConsumerWidget {
  final String invoiceId;
  const InvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoice = ref.watch(invoiceDetailProvider(invoiceId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice'),
        actions: [
          invoice.whenData((inv) => IconButton(
                icon: const Icon(Icons.picture_as_pdf_rounded),
                tooltip: 'Download PDF',
                onPressed: () => _downloadPdf(context, inv),
              )).valueOrNull ?? const SizedBox.shrink(),
        ],
      ),
      body: invoice.when(
        data: (inv) => _InvoiceDetailBody(invoice: inv),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorStateWidget(
          message: 'Could not load invoice',
          onRetry: () => ref.invalidate(invoiceDetailProvider(invoiceId)),
        ),
      ),
    );
  }

  Future<void> _downloadPdf(BuildContext context, CustomerInvoice inv) async {
    try {
      final pdf = await CustomerInvoicePdfService.generate(inv);
      await Printing.sharePdf(
        bytes: pdf,
        filename: 'Invoice-${inv.invoiceNumber}.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: $e')),
        );
      }
    }
  }
}

class _InvoiceDetailBody extends StatelessWidget {
  final CustomerInvoice invoice;
  const _InvoiceDetailBody({required this.invoice});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeaderCard(invoice: invoice),
          const SizedBox(height: 16),
          _ItemsCard(invoice: invoice),
          const SizedBox(height: 16),
          _TotalsCard(invoice: invoice),
          if (invoice.notes != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Notes', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Text(invoice.notes!),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final CustomerInvoice invoice;
  const _HeaderCard({required this.invoice});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  invoice.vendorBusinessName ?? invoice.vendorName,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                InvoiceStatusBadge(status: invoice.status),
              ],
            ),
            const SizedBox(height: 8),
            _Row('Invoice #', invoice.invoiceNumber),
            _Row('Date', DateFormatter.format(invoice.invoiceDate)),
            if (invoice.dueDate != null)
              _Row('Due Date', DateFormatter.format(invoice.dueDate!)),
            if (invoice.vendorPhone != null)
              _Row('Phone', invoice.vendorPhone!),
          ],
        ),
      ),
    );
  }
}

class _ItemsCard extends StatelessWidget {
  final CustomerInvoice invoice;
  const _ItemsCard({required this.invoice});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Items',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    )),
          ),
          ...invoice.items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500)),
                          Text(
                            '${item.quantity} ${item.unit} × ${CurrencyFormatter.format(item.unitPrice)}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Text(CurrencyFormatter.format(item.total),
                        style:
                            const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  final CustomerInvoice invoice;
  const _TotalsCard({required this.invoice});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _Row('Subtotal', CurrencyFormatter.format(invoice.subtotal)),
            if (invoice.discountAmount > 0)
              _Row('Discount',
                  '- ${CurrencyFormatter.format(invoice.discountAmount)}'),
            if (invoice.taxAmount > 0)
              _Row('Tax', CurrencyFormatter.format(invoice.taxAmount)),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        )),
                Text(CurrencyFormatter.format(invoice.totalAmount),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        )),
              ],
            ),
            if (invoice.paidAmount > 0) ...[
              const SizedBox(height: 4),
              _Row('Paid', CurrencyFormatter.format(invoice.paidAmount),
                  valueColor: const Color(0xFF43A047)),
              _Row('Balance Due', CurrencyFormatter.format(invoice.balanceDue),
                  bold: true, valueColor: const Color(0xFFE53935)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  const _Row(this.label, this.value, {this.bold = false, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          Text(value,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                color: valueColor,
              )),
        ],
      ),
    );
  }
}
