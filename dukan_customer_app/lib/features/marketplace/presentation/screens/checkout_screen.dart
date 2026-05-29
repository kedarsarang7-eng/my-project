// ============================================================
// Dukan Customer App - Checkout Screen
// Order placement with address selection and payment
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/marketplace_models.dart';
import '../../providers/marketplace_providers.dart';
import '../../services/marketplace_api_service.dart';
import 'order_confirmation_screen.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  final String businessId;
  final Cart cart;

  const CheckoutScreen({super.key, required this.businessId, required this.cart});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  bool _isPlacingOrder = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedAddressId = ref.watch(selectedAddressIdProvider);
    final paymentMethod = ref.watch(paymentMethodProvider);
    final isExpress = ref.watch(isExpressDeliveryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Delivery Address Section
            _SectionTitle(icon: Icons.location_on, title: 'Delivery Address'),
            const SizedBox(height: 12),
            _buildAddressCard(context, selectedAddressId),
            
            const SizedBox(height: 24),
            
            // Delivery Options
            _SectionTitle(icon: Icons.local_shipping, title: 'Delivery Options'),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  RadioListTile<bool>(
                    title: const Text('Standard Delivery'),
                    subtitle: const Text('30-45 minutes'),
                    value: false,
                    groupValue: isExpress,
                    onChanged: (_) => ref.read(isExpressDeliveryProvider.notifier).state = false,
                    secondary: const Text('FREE'),
                  ),
                  const Divider(height: 1),
                  RadioListTile<bool>(
                    title: Row(
                      children: [
                        const Text('Express Delivery'),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'FAST',
                            style: TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                    subtitle: const Text('15-30 minutes'),
                    value: true,
                    groupValue: isExpress,
                    onChanged: (_) => ref.read(isExpressDeliveryProvider.notifier).state = true,
                    secondary: const Text('₹49'),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Payment Method
            _SectionTitle(icon: Icons.payment, title: 'Payment Method'),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  RadioListTile<PaymentMethod>(
                    title: const Row(
                      children: [
                        Icon(Icons.money),
                        SizedBox(width: 12),
                        Text('Cash on Delivery'),
                      ],
                    ),
                    value: PaymentMethod.cod,
                    groupValue: paymentMethod,
                    onChanged: (value) => ref.read(paymentMethodProvider.notifier).state = value!,
                  ),
                  const Divider(height: 1),
                  RadioListTile<PaymentMethod>(
                    title: Row(
                      children: [
                        Icon(Icons.account_balance_wallet, color: Colors.blue.shade700),
                        const SizedBox(width: 12),
                        const Text('Online Payment'),
                      ],
                    ),
                    subtitle: const Text('UPI, Cards, Net Banking'),
                    value: PaymentMethod.online,
                    groupValue: paymentMethod,
                    onChanged: (value) => ref.read(paymentMethodProvider.notifier).state = value!,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Order Summary
            _SectionTitle(icon: Icons.receipt, title: 'Order Summary'),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Items (${widget.cart.itemCount})', style: theme.textTheme.bodyMedium),
                        Text('₹${widget.cart.subtotal.toStringAsFixed(2)}', style: theme.textTheme.bodyMedium),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Taxes & Fees', style: theme.textTheme.bodyMedium),
                        Text('₹${widget.cart.taxAmount.toStringAsFixed(2)}', style: theme.textTheme.bodyMedium),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Delivery', style: theme.textTheme.bodyMedium),
                        Text(
                          isExpress ? '₹49.00' : 'FREE',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isExpress ? null : Colors.green,
                          ),
                        ),
                      ],
                    ),
                    if (widget.cart.discountAmount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Discount', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.green)),
                            Text('-₹${widget.cart.discountAmount.toStringAsFixed(2)}', 
                                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.green)),
                          ],
                        ),
                      ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Amount',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '₹${(widget.cart.total + (isExpress ? 49 : 0)).toStringAsFixed(2)}',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Special Instructions
            _SectionTitle(icon: Icons.note, title: 'Special Instructions'),
            const SizedBox(height: 12),
            TextField(
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Add any special instructions for the store...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (value) => ref.read(orderNotesProvider.notifier).state = value,
            ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -4))],
          ),
          child: SafeArea(
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: selectedAddressId == null || _isPlacingOrder
                    ? null
                    : () => _placeOrder(context),
                child: _isPlacingOrder
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('Place Order • ₹${(widget.cart.total + (isExpress ? 49 : 0)).toStringAsFixed(2)}'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddressCard(BuildContext context, String? selectedAddressId) {
    // Mock addresses - in real app, fetch from API
    final addresses = [
      DeliveryAddress(
        id: 'addr1',
        label: 'Home',
        addressLine1: '123 Main Street',
        addressLine2: 'Apt 4B',
        city: 'Mumbai',
        state: 'Maharashtra',
        pincode: '400001',
        contactName: 'John Doe',
        contactPhone: '9876543210',
      ),
      DeliveryAddress(
        id: 'addr2',
        label: 'Work',
        addressLine1: '456 Office Park',
        city: 'Mumbai',
        state: 'Maharashtra',
        pincode: '400051',
        contactName: 'John Doe',
        contactPhone: '9876543210',
      ),
    ];

    return Column(
      children: addresses.map((address) {
        final isSelected = selectedAddressId == address.id;
        return Card(
          elevation: isSelected ? 2 : 0,
          color: isSelected ? Colors.blue.shade50 : null,
          child: RadioListTile<String>(
            value: address.id,
            groupValue: selectedAddressId,
            onChanged: (value) => ref.read(selectedAddressIdProvider.notifier).state = value,
            title: Row(
              children: [
                Text(address.label, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Default',
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(address.addressLine1),
                if (address.addressLine2 != null) Text(address.addressLine2!),
                Text('${address.city}, ${address.state} - ${address.pincode}'),
                const SizedBox(height: 4),
                Text('${address.contactName} • ${address.contactPhone}'),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _placeOrder(BuildContext context) async {
    setState(() => _isPlacingOrder = true);

    try {
      final api = ref.read(marketplaceApiProvider);
      final addressId = ref.read(selectedAddressIdProvider)!;
      final paymentMethod = ref.read(paymentMethodProvider);
      final isExpress = ref.read(isExpressDeliveryProvider);
      final notes = ref.read(orderNotesProvider);

      final order = await api.placeOrder(
        widget.businessId,
        addressId: addressId,
        paymentMethod: paymentMethod,
        isExpress: isExpress,
        notes: notes.isNotEmpty ? notes : null,
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OrderConfirmationScreen(order: order),
          ),
        );
      }
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to place order: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isPlacingOrder = false);
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
