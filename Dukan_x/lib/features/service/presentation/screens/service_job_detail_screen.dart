/// Service Job Detail Screen
/// Shows complete job details with status timeline and actions
library;

import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/currency_service.dart';
import 'package:intl/intl.dart';
import 'package:dukanx/core/database/app_database.dart';
import '../../models/service_job.dart';
import '../../services/service_job_service.dart';
import '../../../../features/billing/presentation/screens/bill_creation_screen_v2.dart';
import '../../../../models/bill.dart'; // For BillItem
import '../../../../models/transaction_model.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class ServiceJobDetailScreen extends StatefulWidget {
  final ServiceJob job;
  const ServiceJobDetailScreen({super.key, required this.job});

  @override
  State<ServiceJobDetailScreen> createState() => _ServiceJobDetailScreenState();
}

class _ServiceJobDetailScreenState extends State<ServiceJobDetailScreen> {
  late ServiceJob _job;
  late ServiceJobService _service;
  final _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: sl<CurrencyService>().symbol,
  );
  final _dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

  @override
  void initState() {
    super.initState();
    _job = widget.job;
    _service = ServiceJobService(AppDatabase.instance);
  }

  Color _getStatusColor(ServiceJobStatus status) {
    switch (status) {
      case ServiceJobStatus.received:
        return Colors.blue;
      case ServiceJobStatus.diagnosed:
        return Colors.indigo;
      case ServiceJobStatus.waitingApproval:
        return Colors.amber;
      case ServiceJobStatus.approved:
        return Colors.teal;
      case ServiceJobStatus.waitingParts:
        return Colors.purple;
      case ServiceJobStatus.inProgress:
        return Colors.orange;
      case ServiceJobStatus.completed:
        return Colors.lightGreen;
      case ServiceJobStatus.ready:
        return Colors.green;
      case ServiceJobStatus.delivered:
        return Colors.grey;
      case ServiceJobStatus.cancelled:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(_job.status);
    return Scaffold(
      appBar: AppBar(
        title: Text(_job.jobNumber),
        actions: [
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              if (_job.status == ServiceJobStatus.received)
                const PopupMenuItem(
                  value: 'diagnose',
                  child: Text('Add Diagnosis'),
                ),
              if (_job.status == ServiceJobStatus.diagnosed)
                const PopupMenuItem(
                  value: 'estimate',
                  child: Text('Add Estimate'),
                ),
              if (_job.status == ServiceJobStatus.inProgress)
                const PopupMenuItem(
                  value: 'complete',
                  child: Text('Mark Complete'),
                ),
              if (_job.status == ServiceJobStatus.ready)
                const PopupMenuItem(
                  value: 'deliver',
                  child: Text('Mark Delivered'),
                ),
              if (_job.isActive)
                const PopupMenuItem(value: 'cancel', child: Text('Cancel Job')),
              if (_job.status == ServiceJobStatus.completed ||
                  _job.status == ServiceJobStatus.ready ||
                  _job.status == ServiceJobStatus.delivered)
                if (_job.billId == null)
                  const PopupMenuItem(
                    value: 'invoice',
                    child: Text('Generate Invoice'),
                  ),
            ],
          ),
        ],
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Status Card
            Card(
              color: statusColor.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.circle, color: statusColor, size: 16),
                    const SizedBox(width: 12),
                    Text(
                      _job.status.displayName,
                      style: TextStyle(
                        fontSize: responsiveValue<double>(
                          context,
                          mobile: 14.0,
                          tablet: 16.0,
                          desktop:
                              18.0, // PRESERVED: Desktop uses exactly 18 as before
                        ),
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                    const Spacer(),
                    if (_job.isUnderWarranty)
                      Chip(
                        label: const Text('WARRANTY'),
                        backgroundColor: Colors.green.withOpacity(0.2),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Customer Info
            _buildSection('Customer', Icons.person, [
              _buildInfoRow('Name', _job.customerName),
              _buildInfoRow('Phone', _job.customerPhone),
              if (_job.customerEmail != null)
                _buildInfoRow('Email', _job.customerEmail!),
            ]),

            // Device Info
            _buildSection('Device', Icons.phone_android, [
              _buildInfoRow('Type', _job.deviceType.displayName),
              _buildInfoRow('Brand / Model', '${_job.brand} ${_job.model}'),
              if (_job.imeiOrSerial != null)
                _buildInfoRow('IMEI/Serial', _job.imeiOrSerial!),
              if (_job.color != null) _buildInfoRow('Color', _job.color!),
            ]),

            // Problem
            _buildSection('Problem', Icons.warning_amber, [
              Text(_job.problemDescription),
              if (_job.symptoms.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _job.symptoms
                      .map(
                        (s) => Chip(
                          label: Text(s, style: const TextStyle(fontSize: 12)),
                        ),
                      )
                      .toList(),
                ),
              ],
            ]),

            // Diagnosis
            if (_job.diagnosis != null)
              _buildSection('Diagnosis', Icons.search, [Text(_job.diagnosis!)]),

            // Cost
            if (_job.grandTotal > 0)
              _buildSection('Cost', Icons.attach_money, [
                _buildInfoRow(
                  'Labor',
                  _currencyFormat.format(_job.actualLaborCost),
                ),
                _buildInfoRow(
                  'Parts',
                  _currencyFormat.format(_job.actualPartsCost),
                ),
                if (_job.discountAmount > 0)
                  _buildInfoRow(
                    'Discount',
                    '-${_currencyFormat.format(_job.discountAmount)}',
                  ),
                const Divider(),
                _buildInfoRow(
                  'Total',
                  _currencyFormat.format(_job.grandTotal),
                  bold: true,
                ),
                _buildInfoRow('Paid', _currencyFormat.format(_job.amountPaid)),
                _buildInfoRow(
                  'Balance',
                  _currencyFormat.format(_job.balanceAmount),
                  color: _job.balanceAmount > 0 ? Colors.red : Colors.green,
                ),
              ]),

            // Timeline
            _buildSection('Timeline', Icons.schedule, [
              _buildInfoRow('Received', _dateFormat.format(_job.receivedAt)),
              if (_job.expectedDelivery != null)
                _buildInfoRow(
                  'Expected',
                  _dateFormat.format(_job.expectedDelivery!),
                ),
              if (_job.completedAt != null)
                _buildInfoRow(
                  'Completed',
                  _dateFormat.format(_job.completedAt!),
                ),
              if (_job.deliveredAt != null)
                _buildInfoRow(
                  'Delivered',
                  _dateFormat.format(_job.deliveredAt!),
                ),
            ]),
          ],
        ),
      ),

      bottomNavigationBar: _job.isActive
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showUpdateStatusSheet(),
                        icon: const Icon(Icons.update),
                        label: const Text('Update Status'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _job.balanceAmount > 0
                            ? () => _recordPayment()
                            : null,
                        icon: const Icon(Icons.payment),
                        label: const Text('Record Payment'),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    bool bold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : null,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action) async {
    switch (action) {
      case 'diagnose':
        final diagnosis = await _showInputDialog(
          'Add Diagnosis',
          'What is the problem?',
        );
        if (diagnosis != null && diagnosis.isNotEmpty) {
          await _service.addDiagnosis(_job.id, diagnosis, userId: _job.userId);
          _refreshJob();
        }
        break;
      case 'complete':
        final workDone = await _showInputDialog(
          'Work Done',
          'Describe the work completed',
        );
        if (workDone != null) {
          await _service.completeJob(
            jobId: _job.id,
            userId: _job.userId,
            workDone: workDone,
            actualLaborCost: _job.estimatedLaborCost,
            actualPartsCost: _job.estimatedPartsCost,
          );
          _refreshJob();
        }
        break;
      case 'deliver':
        await _service.deliverJob(jobId: _job.id, userId: _job.userId);
        _refreshJob();
        break;
      case 'cancel':
        final reason = await _showInputDialog(
          'Cancel Reason',
          'Why is this job being cancelled?',
        );
        if (reason != null) {
          await _service.cancelJob(_job.id, reason, userId: _job.userId);
          _refreshJob();
        }
        break;
      case 'invoice':
        _generateInvoice();
        break;
    }
  }

  void _generateInvoice() {
    final items = <BillItem>[];

    // Add Labor
    if (_job.actualLaborCost > 0) {
      items.add(
        BillItem(
          productId: 'LABOR', // Special ID for labor
          productName: 'Service Labor Charge',
          qty: 1,
          price: _job.actualLaborCost,
          unit: 'job',
          gstRate: 18.0, // Standard service tax
          cgst: _job.actualLaborCost * 0.09,
          sgst: _job.actualLaborCost * 0.09,
        ),
      );
    }

    // Add Parts
    for (final part in _job.partsUsed) {
      items.add(
        BillItem(
          productId: part.productId ?? '',
          productName: part.partName,
          qty: part.quantity,
          price: part.unitCost,
          unit: part.unit,
          gstRate: 18.0, // Default to 18 if unknown, ideally fetch from product
          cgst: (part.unitCost * part.quantity) * 0.09,
          sgst: (part.unitCost * part.quantity) * 0.09,
        ),
      );
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BillCreationScreenV2(
          transactionType:
              TransactionType.sale, // Service is also a sale effectively
          initialItems: items,
          serviceJobId: _job.id,
          // Ideally pass customer if available
        ),
      ),
    ).then((_) => _refreshJob()); // Refresh to see linked bill status
  }

  Future<String?> _showInputDialog(String title, String hint) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: hint),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showUpdateStatusSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: EdgeInsets.all(
          responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Update Status',
              style: TextStyle(
                fontSize: responsiveValue<double>(
                  context,
                  mobile: 14.0,
                  tablet: 16.0,
                  desktop: 18.0, // PRESERVED: Desktop uses exactly 18 as before
                ),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ServiceJobStatus.values
                  .where(
                    (s) =>
                        s != ServiceJobStatus.cancelled &&
                        s != ServiceJobStatus.delivered,
                  )
                  .map(
                    (status) => ActionChip(
                      label: Text(status.displayName),
                      backgroundColor: _getStatusColor(status).withOpacity(0.2),
                      onPressed: () async {
                        Navigator.pop(context);
                        await _service.updateStatus(
                          _job.id,
                          status,
                          userId: _job.userId,
                        );
                        _refreshJob();
                      },
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _recordPayment() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Record Payment'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText:
                'Amount (Balance: ${_currencyFormat.format(_job.balanceAmount)})',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(controller.text) ?? 0;
              if (amount > 0) {
                Navigator.pop(context);
                await _service.recordPayment(
                  jobId: _job.id,
                  userId: _job.userId,
                  amount: amount,
                );
                _refreshJob();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _refreshJob() async {
    final updated = await _service.getServiceJob(_job.id, userId: _job.userId);
    if (updated != null && mounted) setState(() => _job = updated);
  }
}
