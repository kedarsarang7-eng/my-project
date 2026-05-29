// ============================================================================
// ORDER BAG SCREEN — Review cart + place order
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/pwa_providers.dart';
import '../../utils/pwa_haptics.dart';
import '../../widgets/pwa_offline_banner.dart';

class OrderBagScreen extends ConsumerStatefulWidget {
  final String vendorId;
  final String tableId;
  const OrderBagScreen({
    super.key,
    required this.vendorId,
    required this.tableId,
  });
  @override
  ConsumerState<OrderBagScreen> createState() => _OrderBagScreenState();
}

class _OrderBagScreenState extends ConsumerState<OrderBagScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _isRouting = false;
  static const _orange = Color(0xFFEA580C);

  Future<void> _continueToPayment() async {
    final cart = ref.read(pwaCartProvider);
    if (cart.isEmpty) return;
    if (_isRouting) return;
    setState(() => _isRouting = true);
    await PwaHaptics.tap();
    if (!mounted) return;
    await context.push(
      '/payment',
      extra: {
        'vendorId': widget.vendorId,
        'tableId': widget.tableId,
        'customerName': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
      },
    );
    if (mounted) setState(() => _isRouting = false);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(pwaCartProvider);
    final total = cart.fold(0.0, (s, i) => s + i.price * i.qty);
    final gst = total * 0.05;
    final grand = total + gst;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Your Order',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: cart.isEmpty
          ? const Column(
              children: [
                PwaOfflineBanner(),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.shopping_bag_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Your bag is empty',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : Column(
              children: [
                const PwaOfflineBanner(),
                Expanded(
                  child: CustomScrollView(
              slivers: [
                // ── Items ─────────────────────────────────────────────────
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _buildItemRow(cart[i], i),
                    childCount: cart.length,
                  ),
                ),
                // ── Note field ────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(color: Color(0xFF2E2E2E)),
                        const SizedBox(height: 8),
                        const Text(
                          'Your Details (optional)',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _nameCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Name',
                            prefixIcon: const Icon(
                              Icons.person_outline,
                              color: Colors.grey,
                            ),
                            filled: true,
                            fillColor: const Color(0xFF1A1A1A),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Color(0xFF2E2E2E),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Color(0xFF2E2E2E),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: _orange),
                            ),
                            labelStyle: const TextStyle(color: Colors.grey),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Phone (for order updates)',
                            prefixIcon: const Icon(
                              Icons.phone_outlined,
                              color: Colors.grey,
                            ),
                            filled: true,
                            fillColor: const Color(0xFF1A1A1A),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Color(0xFF2E2E2E),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Color(0xFF2E2E2E),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: _orange),
                            ),
                            labelStyle: const TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // ── Bill summary ──────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF2E2E2E)),
                    ),
                    child: Column(
                      children: [
                        _billRow('Subtotal', '₹${total.toStringAsFixed(2)}'),
                        const SizedBox(height: 8),
                        _billRow('GST (5%)', '₹${gst.toStringAsFixed(2)}'),
                        const Divider(height: 20, color: Color(0xFF2E2E2E)),
                        _billRow(
                          'Grand Total',
                          '₹${grand.toStringAsFixed(2)}',
                          highlight: true,
                        ),
                      ],
                    ),
                  ),
                ),
                // ── Spacer for button ─────────────────────────────────────
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
                ),
              ],
            ),
      bottomNavigationBar: cart.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A1A),
                border: Border(top: BorderSide(color: Color(0xFF2E2E2E))),
              ),
              child: ElevatedButton(
                onPressed: _isRouting ? null : _continueToPayment,
                child: _isRouting
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Opening Payment…',
                            style: TextStyle(fontSize: 15),
                          ),
                        ],
                      )
                    : const Text('Continue to Payment'),
              ),
            ),
    );
  }

  Widget _buildItemRow(PwaCartItem item, int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2E2E2E)),
      ),
      child: Row(
        children: [
          // Veg indicator
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              border: Border.all(
                color: item.isVeg ? Colors.green : Colors.red,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Center(
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: item.isVeg ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '₹${(item.price * item.qty).toStringAsFixed(0)}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          // Qty row
          Row(
            children: [
              _btn(Icons.remove, () {
                PwaHaptics.tap();
                ref
                    .read(pwaCartProvider.notifier)
                    .decrementById(item.menuItemId);
              }),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '${item.qty}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _btn(Icons.add, () {
                PwaHaptics.tap();
                ref.read(pwaCartProvider.notifier).add(item);
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, VoidCallback fn) {
    return GestureDetector(
      onTap: fn,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: _orange.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: _orange, size: 16),
      ),
    );
  }

  Widget _billRow(String label, String value, {bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: highlight ? Colors.white : Colors.grey,
            fontSize: highlight ? 15 : 13,
            fontWeight: highlight ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: highlight ? _orange : Colors.grey,
            fontSize: highlight ? 18 : 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
