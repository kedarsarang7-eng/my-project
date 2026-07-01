import 'package:flutter/material.dart';
import '../core/di/service_locator.dart';
import '../core/repository/customers_repository.dart';

class CustomerProfileManagementScreen extends StatefulWidget {
  final String ownerId;

  const CustomerProfileManagementScreen({super.key, required this.ownerId});

  @override
  State<CustomerProfileManagementScreen> createState() =>
      _CustomerProfileManagementScreenState();
}

class _CustomerProfileManagementScreenState
    extends State<CustomerProfileManagementScreen> {
  @override
  void initState() {
    super.initState();
    // No explicit load needed with StreamBuilder
  }

  Future<void> _deleteCustomerProfile(Customer customer) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Customer Profile?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete ${customer.name}\'s profile?',
            ),
            const SizedBox(height: 16),
            const Text(
              '⚠️ WARNING: This action is permanent and cannot be undone.',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'All customer data including bills and payment history will be deleted.',
              style: TextStyle(color: Colors.orange, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await sl<CustomersRepository>().deleteCustomer(
        customer.id,
        userId: widget.ownerId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${customer.name}\'s profile deleted'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting profile: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Profile Management'),
        elevation: 0,
      ),
      body: StreamBuilder<List<Customer>>(
        stream: sl<CustomersRepository>().watchAll(userId: widget.ownerId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final customers = snapshot.data ?? [];

          if (customers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  const Text('No customers created yet'),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: customers.length,
            itemBuilder: (context, index) {
              final customer = customers[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade700,
                    child: Text(
                      customer.name.isNotEmpty
                          ? customer.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(customer.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        'Phone: ${customer.phone ?? 'N/A'}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        'Dues: ₹${customer.totalDues.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  trailing: PopupMenuButton(
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        child: const Text('View Details'),
                        onTap: () {
                          _showCustomerDetails(customer);
                        },
                      ),
                      PopupMenuItem(
                        child: const Text('Edit Profile'),
                        onTap: () {
                          Future.microtask(() => _showEditDialog(customer));
                        },
                      ),
                      PopupMenuItem(
                        child: const Text(
                          'Delete Profile',
                          style: TextStyle(color: Colors.red),
                        ),
                        onTap: () {
                          _deleteCustomerProfile(customer);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showCustomerDetails(Customer customer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${customer.name} - Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Name:', customer.name),
              _buildDetailRow('Phone:', customer.phone ?? 'N/A'),
              _buildDetailRow('Address:', customer.address ?? 'N/A'),
              _buildDetailRow(
                'Total Dues:',
                '₹${customer.totalDues.toStringAsFixed(2)}',
              ),
              // _buildDetailRow(
              //    'Cash Dues:', '₹${customer.cashDues.toStringAsFixed(2)}'), // Removed: Not in new model
              // _buildDetailRow(
              //    'Online Dues:', '₹${customer.onlineDues.toStringAsFixed(2)}'), // Removed: Not in new model
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );

    // Auto close after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    });
  }

  void _showEditDialog(Customer customer) {
    final nameCtrl = TextEditingController(text: customer.name);
    final phoneCtrl = TextEditingController(text: customer.phone ?? '');
    final addressCtrl = TextEditingController(text: customer.address ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Customer'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Name is required')),
                );
                return;
              }
              final updatedCustomer = customer.copyWith(
                name: nameCtrl.text,
                phone: phoneCtrl.text.isEmpty ? null : phoneCtrl.text,
                address: addressCtrl.text.isEmpty ? null : addressCtrl.text,
              );
              await sl<CustomersRepository>().updateCustomer(
                updatedCustomer,
                userId: widget.ownerId,
              );
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Customer updated')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
