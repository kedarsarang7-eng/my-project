// ============================================================================
// KOT PREVIEW SCREEN — Review cart then punch KOT
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../providers/pos_providers.dart';
import '../../models/cart_item.dart';
import '../../services/pos_api_service.dart';

class KotPreviewScreen extends ConsumerStatefulWidget {
  const KotPreviewScreen({super.key});
  @override
  ConsumerState<KotPreviewScreen> createState() => _KotPreviewScreenState();
}

class _KotPreviewScreenState extends ConsumerState<KotPreviewScreen> {
  bool _isSending = false;
  static const _orange = Color(0xFFEA580C);

  Future<void> _punchKot() async {
    final cart = ref.read(cartProvider);
    final session = ref.read(vendorSessionProvider);
    final tableId = ref.read(activeTableIdProvider);
    final tableNumber = ref.read(activeTableNumberProvider);
    if (cart.isEmpty || session == null) return;

    setState(() => _isSending = true);

    final kotData = {
      'id': const Uuid().v4(),
      'vendorId': session.vendorId,
      'tableId': tableId,
      'tableNumber': tableNumber,
      'kotNumber': DateTime.now().millisecondsSinceEpoch % 10000,
      'staffId': session.staffName,
      'status': 'pending',
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
      'items': cart
          .map(
            (i) => {
              'menuItemId': i.menuItemId,
              'itemName': i.itemName,
              'qty': i.qty,
              'variationName': i.variationName,
              'addons': i.addons,
              'specialInstructions': i.specialInstructions,
            },
          )
          .toList(),
    };

    final ok = await PosApiService.postKot(kotData);

    if (mounted) {
      setState(() => _isSending = false);
      if (ok) {
        ref.read(cartProvider.notifier).clear();
        context.go('/floor');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('KOT #${kotData['kotNumber']} sent to kitchen!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Offline — KOT saved locally'),
            backgroundColor: Colors.amber,
          ),
        );
        ref.read(cartProvider.notifier).clear();
        context.go('/floor');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final tableNumber = ref.watch(activeTableNumberProvider);
    final total = ref.watch(cartTotalProvider);
    final gst = total * 0.05;
    final grandTotal = total + gst;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'KOT Preview — Table $tableNumber',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Row(
        children: [
          // ── Items list ──────────────────────────────────────────────────
          Expanded(
            flex: 6,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  color: const Color(0xFF1A1A1A),
                  child: const Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Text(
                          'ITEM',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          'QTY',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'PRICE',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFF2E2E2E)),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: cart.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: Color(0xFF2E2E2E)),
                    itemBuilder: (ctx, i) => _buildItemRow(cart[i], i),
                  ),
                ),
              ],
            ),
          ),
          // ── Summary + Action ────────────────────────────────────────────
          Container(
            width: 300,
            color: const Color(0xFF1A1A1A),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ORDER SUMMARY',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                _summaryRow('Subtotal', '₹${total.toStringAsFixed(2)}'),
                const SizedBox(height: 8),
                _summaryRow('GST (5%)', '₹${gst.toStringAsFixed(2)}'),
                const Divider(height: 24, color: Color(0xFF2E2E2E)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Grand Total',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      '₹${grandTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: _orange,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Table + staff info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF242424),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF2E2E2E)),
                  ),
                  child: Column(
                    children: [
                      _infoRow(Icons.table_restaurant, 'Table $tableNumber'),
                      const SizedBox(height: 8),
                      _infoRow(Icons.access_time, _formatTime(DateTime.now())),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    icon: _isSending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send, size: 18),
                    label: Text(
                      _isSending ? 'Sending…' : 'Send to Kitchen',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed: _isSending ? null : _punchKot,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _orange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(CartItem item, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itemName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (item.specialInstructions != null &&
                    item.specialInstructions!.isNotEmpty)
                  Text(
                    '📝 ${item.specialInstructions}',
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '${item.qty}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '₹${(item.price * item.qty).toStringAsFixed(0)}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: _orange,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13)),
      ],
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
