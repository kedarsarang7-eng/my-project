import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/ac_screen_wrapper.dart';

/// Online Payments Screen - Razorpay Integration
class AcPaymentsScreen extends ConsumerStatefulWidget {
  const AcPaymentsScreen({super.key});

  @override
  ConsumerState<AcPaymentsScreen> createState() => _AcPaymentsScreenState();
}

class _AcPaymentsScreenState extends ConsumerState<AcPaymentsScreen> {
  String _selectedTab = 'pending';
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return AcScreenWrapper(
      title: 'Online Payments',
      actions: [
        FilledButton.icon(
          onPressed: () => _showCollectPaymentDialog(),
          icon: const Icon(Icons.payment),
          label: const Text('Collect Payment'),
        ),
      ],
      child: Column(
        children: [
          // Stats Cards
          _buildPaymentStats(),
          const SizedBox(height: 16),
          // Tabs
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'pending', label: Text('Pending')),
              ButtonSegment(value: 'completed', label: Text('Completed')),
              ButtonSegment(value: 'failed', label: Text('Failed')),
              ButtonSegment(value: 'refunded', label: Text('Refunded')),
            ],
            selected: {_selectedTab},
            onSelectionChanged: (set) =>
                setState(() => _selectedTab = set.first),
          ),
          const SizedBox(height: 16),
          Expanded(child: _buildPaymentsList()),
        ],
      ),
    );
  }

  Widget _buildPaymentStats() {
    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(
                    Icons.account_balance_wallet,
                    color: Colors.green,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₹1,25,000',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Text('Collected Today', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.pending, color: Colors.orange, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    '₹45,500',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Text('Pending', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.receipt, color: Colors.blue, size: 32),
                  const SizedBox(height: 8),
                  Text('48', style: Theme.of(context).textTheme.titleLarge),
                  const Text('Transactions', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentsList() {
    return ListView.builder(
      itemCount: 15,
      itemBuilder: (context, index) {
        final statuses = ['pending', 'completed', 'failed', 'refunded'];
        final status = statuses[index % statuses.length];
        final colors = {
          'pending': Colors.orange,
          'completed': Colors.green,
          'failed': Colors.red,
          'refunded': Colors.purple,
        };

        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: colors[status]!.withOpacity(0.2),
              child: Icon(
                status == 'completed'
                    ? Icons.check
                    : status == 'failed'
                    ? Icons.close
                    : status == 'refunded'
                    ? Icons.replay
                    : Icons.access_time,
                color: colors[status],
              ),
            ),
            title: Text('INV-${2024000 + index}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Student: ${index + 1}'),
                Text('Razorpay Order: order_${index}ABCDEF'),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${(index + 1) * 1500}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Chip(
                  label: Text(
                    status.toUpperCase(),
                    style: const TextStyle(fontSize: 10),
                  ),
                  backgroundColor: colors[status]?.withOpacity(0.2),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCollectPaymentDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Collect Payment'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(
                  labelText: 'Student',
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Amount (₹)',
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Description',
                  prefixIcon: Icon(Icons.description),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _initiateRazorpayPayment();
            },
            icon: const Icon(Icons.payment),
            label: const Text('Generate Payment Link'),
          ),
        ],
      ),
    );
  }

  void _initiateRazorpayPayment() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Razorpay Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.qr_code, size: 100),
            const SizedBox(height: 16),
            const Text('Payment Link Generated'),
            const SizedBox(height: 8),
            Text(
              'Order ID: order_${DateTime.now().millisecondsSinceEpoch}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.content_copy),
                  label: const Text('Copy Link'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.share),
                  label: const Text('Share'),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
