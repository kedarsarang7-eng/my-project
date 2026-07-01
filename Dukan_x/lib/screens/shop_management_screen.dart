import 'package:flutter/material.dart';
import 'package:dukanx/core/responsive/responsive_layout.dart';
import '../core/di/service_locator.dart';
import '../services/connection_service.dart';
import '../models/customer.dart';

class ShopManagementScreen extends StatefulWidget {
  final Customer? customer;

  const ShopManagementScreen({super.key, this.customer});

  @override
  State<ShopManagementScreen> createState() => _ShopManagementScreenState();
}

class _ShopManagementScreenState extends State<ShopManagementScreen> {
  final _shopIdController = TextEditingController();
  bool _isLoading = false;
  List<String> _linkedShops = [];

  @override
  void initState() {
    super.initState();
    _loadLinkedShops();
  }

  Future<void> _loadLinkedShops() async {
    // With ConnectionService, we mostly look at the current user's connections.
    // If 'widget.customer' is supported, ConnectionService needs to support it.
    // Assuming current user context for now.

    setState(() => _isLoading = true);
    try {
      final connections = await sl<ConnectionService>()
          .getAcceptedConnections();
      if (mounted) {
        setState(() {
          _linkedShops = connections
              .map((m) => m['vendorId'] as String)
              .toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading shops: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _linkShop() async {
    final shopId = _shopIdController.text.trim();
    if (shopId.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await sl<ConnectionService>().linkShop(shopId);

      _shopIdController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request sent! Check back later.')),
        );
      }
      _loadLinkedShops();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to link shop: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _unlinkShop(String shopId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unlink Shop'),
        content: Text('Are you sure you want to unlink shop $shopId?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Unlink', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await sl<ConnectionService>().unlinkShop(shopId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shop unlinked successfully')),
        );
      }
      _loadLinkedShops();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to unlink: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _shopIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;

    final linkCard = Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Link a New Shop',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _shopIdController,
              decoration: const InputDecoration(
                labelText: 'Shop ID',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.store),
                helperText: 'Enter the ID provided by the shop owner',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _linkShop,
                icon: const Icon(Icons.add_link),
                label: Text(_isLoading ? 'Linking...' : 'Link Shop'),
              ),
            ),
          ],
        ),
      ),
    );

    final shopsList = _isLoading && _linkedShops.isEmpty
        ? const Center(child: Padding(
            padding: EdgeInsets.all(24.0),
            child: CircularProgressIndicator(),
          ))
        : _linkedShops.isEmpty
            ? const Center(child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text('No shops linked yet.'),
              ))
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _linkedShops.length,
                itemBuilder: (context, index) {
                  final shopId = _linkedShops[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.store),
                      ),
                      title: Text('Shop ID: $shopId'),
                      subtitle: const Text('Linked'),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete,
                          color: Colors.grey,
                        ),
                        onPressed: () => _unlinkShop(shopId),
                      ),
                    ),
                  );
                },
              );

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Shops')),
      body: ResponsiveContainer(
        child: isMobile
            ? SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    linkCard,
                    const SizedBox(height: 24),
                    const Text(
                      'Linked Shops',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    shopsList,
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: linkCard,
                    ),
                    const SizedBox(width: 32),
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Linked Shops',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          const SizedBox(height: 8),
                          shopsList,
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
