import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/session/session_manager.dart';
import '../../models/delivery_challan_model.dart';
import '../../data/repositories/delivery_challan_repository.dart';
import '../../services/delivery_challan_service.dart';
import 'create_delivery_challan_screen.dart';
import 'package:dukanx/core/responsive/responsive.dart'; // To be created

class DeliveryChallanListScreen extends StatelessWidget {
  const DeliveryChallanListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = sl<SessionManager>();
    final userId = session.ownerId;

    if (userId == null) {
      return const Scaffold(body: Center(child: Text('User not logged in')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Delivery Challans')),
      body: BoundedBox(
        maxWidth: 800,
        child: StreamBuilder<List<DeliveryChallan>>(
        stream: sl<DeliveryChallanRepository>().watchAll(userId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final challans = snapshot.data ?? [];

          if (challans.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.local_shipping_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Delivery Challans created yet',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: challans.length,
            itemBuilder: (context, index) {
              final dc = challans[index];
              return _DeliveryChallanCard(challan: dc);
            },
          );
        },
      ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CreateDeliveryChallanScreen(),
            ),
          );
        },
        label: const Text('Create Challan'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

class _DeliveryChallanCard extends StatelessWidget {
  final DeliveryChallan challan;

  const _DeliveryChallanCard({required this.challan});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: sl<CurrencyService>().symbol, decimalDigits: 2);
    final dateFormat = DateFormat('dd MMM yyyy');

    Color statusColor;
    switch (challan.status) {
      case DeliveryChallanStatus.draft:
        statusColor = Colors.grey;
        break;
      case DeliveryChallanStatus.sent:
        statusColor = Colors.blue;
        break;
      case DeliveryChallanStatus.converted:
        statusColor = Colors.green;
        break;
      case DeliveryChallanStatus.cancelled:
        statusColor = Colors.red;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  challan.challanNumber,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withOpacity(0.5)),
                  ),
                  child: Text(
                    challan.status.name.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  challan.customerName ?? 'Unknown Customer',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  dateFormat.format(challan.challanDate),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const Spacer(),
                Text(
                  currencyFormat.format(challan.grandTotal),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            if (challan.status != DeliveryChallanStatus.converted &&
                challan.status != DeliveryChallanStatus.cancelled) ...[
              const Divider(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _convertToInvoice(context),
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('Convert to Invoice'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue.shade700,
                  ),
                ),
              ),
            ],
            if (challan.transportMode != null) ...[
              const SizedBox(height: 8),
              Text(
                'Transport: ${challan.transportMode} • ${challan.vehicleNumber ?? ""}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _convertToInvoice(BuildContext context) async {
    final confirmation = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Convert to Invoice?'),
        content: const Text(
          'This will create a Tax Invoice from this Challan and mark it as Converted. Tracking of goods will move to the Invoice.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Convert'),
          ),
        ],
      ),
    );

    if (confirmation == true && context.mounted) {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final service = sl<DeliveryChallanService>();
      final bill = await service.convertToInvoice(challan);

      if (context.mounted) {
        Navigator.pop(context); // Hide loading

        if (bill != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Invoice ${bill.invoiceNumber} created successfully',
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to convert to invoice')),
          );
        }
      }
    }
  }
}
