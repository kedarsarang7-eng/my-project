// ============================================================================
// LIVE BILL SCREEN — Running bill for the table
// ============================================================================
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/pwa_api_service.dart';
import '../../widgets/pwa_offline_banner.dart';
import '../../widgets/pwa_state_widgets.dart';

class LiveBillScreen extends ConsumerStatefulWidget {
  final String vendorId;
  final String tableId;
  const LiveBillScreen({
    super.key,
    required this.vendorId,
    required this.tableId,
  });
  @override
  ConsumerState<LiveBillScreen> createState() => _LiveBillScreenState();
}

class _LiveBillScreenState extends ConsumerState<LiveBillScreen> {
  Map<String, dynamic> _bill = {};
  bool _isLoading = true;
  bool _loadError = false;
  Timer? _pollTimer;
  static const _orange = Color(0xFFEA580C);

  @override
  void initState() {
    super.initState();
    _load();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) => _load());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final bill = await PwaApiService.fetchBill(
      vendorId: widget.vendorId,
      tableId: widget.tableId,
    );
    if (mounted) {
      setState(() {
        _bill = bill ?? {};
        _loadError = bill == null;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = (_bill['items'] as List?) ?? [];
    final subtotal = (_bill['subtotal'] ?? 0).toDouble();
    final gst = (_bill['gst'] ?? 0).toDouble();
    final discount = (_bill['discount'] ?? 0).toDouble();
    final grand = (_bill['grandTotal'] ?? subtotal + gst).toDouble();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Your Bill',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? const Column(
              children: [
                PwaOfflineBanner(),
                Expanded(child: PwaSkeletonList(itemCount: 5)),
              ],
            )
          : _loadError
          ? Column(
              children: [
                const PwaOfflineBanner(),
                Expanded(
                  child: PwaErrorState(
                    title: 'Bill unavailable',
                    subtitle: 'Could not load running bill.',
                    onRetry: _load,
                  ),
                ),
              ],
            )
          : Column(
              children: [
                const PwaOfflineBanner(),
                Expanded(
                  child: items.isEmpty
                      ? PwaErrorState(
                          title: 'No items billed yet',
                          subtitle: 'Place order first, then bill appears here.',
                          onRetry: _load,
                        )
                      : CustomScrollView(
              slivers: [
                // ── Bill header ─────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _orange.withValues(alpha: 0.12),
                          _orange.withValues(alpha: 0.04),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _orange.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TOTAL AMOUNT DUE',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 11,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₹${grand.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _orange.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.receipt_long,
                            color: _orange,
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // ── Items ──────────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ORDER ITEMS',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF2E2E2E)),
                          ),
                          child: Column(
                            children: [
                              // Header
                              const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 4,
                                      child: Text(
                                        'Item',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        'Qty',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'Amount',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(
                                height: 1,
                                color: Color(0xFF2E2E2E),
                              ),
                              ...items.asMap().entries.map((e) {
                                final idx = e.key;
                                final item = e.value;
                                final amt =
                                    (item['price'] ?? 0).toDouble() *
                                    (item['qty'] ?? 1);
                                return Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 4,
                                            child: Text(
                                              item['name'] ?? '',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 1,
                                            child: Text(
                                              '${item['qty'] ?? 1}',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: Colors.grey[400],
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              '₹${amt.toStringAsFixed(0)}',
                                              textAlign: TextAlign.right,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (idx < items.length - 1)
                                      const Divider(
                                        height: 1,
                                        color: Color(0xFF242424),
                                      ),
                                  ],
                                );
                              }),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // ── Totals ─────────────────────────────────────────────────
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
                        _row('Subtotal', '₹${subtotal.toStringAsFixed(2)}'),
                        const SizedBox(height: 8),
                        _row('GST (5%)', '₹${gst.toStringAsFixed(2)}'),
                        if (discount > 0) ...[
                          const SizedBox(height: 8),
                          _row(
                            'Discount',
                            '−₹${discount.toStringAsFixed(2)}',
                            valueColor: Colors.green,
                          ),
                        ],
                        const Divider(height: 20, color: Color(0xFF2E2E2E)),
                        _row(
                          'Grand Total',
                          '₹${grand.toStringAsFixed(2)}',
                          highlight: true,
                        ),
                      ],
                    ),
                  ),
                ),
                // ── Pay note ──────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.2),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.green, size: 16),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Please pay at the counter or call your waiter. '
                            'UPI QR available at the billing desk.',
                            style: TextStyle(color: Colors.green, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
                ),
              ],
            ),
    );
  }

  Widget _row(
    String label,
    String value, {
    bool highlight = false,
    Color? valueColor,
  }) {
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
            color: valueColor ?? (highlight ? _orange : Colors.grey),
            fontSize: highlight ? 18 : 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
