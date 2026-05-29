// ============================================================================
// SPLIT BILL SCREEN — Split bill by # of guests or custom amounts
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/pos_providers.dart';

class SplitBillScreen extends ConsumerStatefulWidget {
  final String tableId;
  const SplitBillScreen({super.key, required this.tableId});
  @override
  ConsumerState<SplitBillScreen> createState() => _SplitBillScreenState();
}

class _SplitBillScreenState extends ConsumerState<SplitBillScreen> {
  static const _orange = Color(0xFFEA580C);
  int _guestCount = 2;
  List<TextEditingController> _customCtrls = [];
  bool _isEven = true;

  @override
  void initState() {
    super.initState();
    _updateControllers();
  }

  void _updateControllers() {
    final total = ref.read(cartTotalProvider) * 1.05; // +GST
    final perGuest = total / _guestCount;
    _customCtrls = List.generate(
      _guestCount,
      (i) => TextEditingController(text: perGuest.toStringAsFixed(2)),
    );
  }

  double get _totalFromCustom =>
      _customCtrls.fold(0.0, (s, c) => s + (double.tryParse(c.text) ?? 0));

  @override
  void dispose() {
    for (final c in _customCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cartTotal = ref.watch(cartTotalProvider);
    final gst = cartTotal * 0.05;
    final grandTotal = cartTotal + gst;
    final perGuest = grandTotal / _guestCount;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Split Bill',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Row(
        children: [
          // ── Config panel ────────────────────────────────────────────────
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SPLIT METHOD',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Toggle
                  Row(
                    children: [
                      _toggleChip(
                        'Even Split',
                        _isEven,
                        () => setState(() => _isEven = true),
                      ),
                      const SizedBox(width: 10),
                      _toggleChip(
                        'Custom Amounts',
                        !_isEven,
                        () => setState(() => _isEven = false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Guest count
                  const Text(
                    'NUMBER OF GUESTS',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _countButton(Icons.remove, () {
                        if (_guestCount > 2) {
                          setState(() {
                            _guestCount--;
                            _updateControllers();
                          });
                        }
                      }),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          '$_guestCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      _countButton(Icons.add, () {
                        if (_guestCount < 10) {
                          setState(() {
                            _guestCount++;
                            _updateControllers();
                          });
                        }
                      }),
                    ],
                  ),
                  if (!_isEven) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'CUSTOM AMOUNTS',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _guestCount,
                        itemBuilder: (ctx, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: _orange.withValues(alpha: 0.15),
                                child: Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    color: _orange,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _customCtrls[i],
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'Guest ${i + 1}',
                                    prefixText: '₹',
                                    prefixStyle: TextStyle(
                                      color: _orange,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ] else
                    const Spacer(),
                ],
              ),
            ),
          ),
          // ── Summary panel ───────────────────────────────────────────────
          Container(
            width: 280,
            color: const Color(0xFF1A1A1A),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'BILL SUMMARY',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                _row('Subtotal', '₹${cartTotal.toStringAsFixed(2)}'),
                const SizedBox(height: 8),
                _row('GST (5%)', '₹${gst.toStringAsFixed(2)}'),
                const Divider(height: 24, color: Color(0xFF2E2E2E)),
                _row(
                  'Grand Total',
                  '₹${grandTotal.toStringAsFixed(2)}',
                  highlight: true,
                ),
                const SizedBox(height: 24),
                // Per-guest breakdown
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _orange.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Per Guest',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                          Text(
                            _isEven ? '₹${perGuest.toStringAsFixed(2)}' : '—',
                            style: const TextStyle(
                              color: _orange,
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                            ),
                          ),
                        ],
                      ),
                      if (!_isEven) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total collected',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              '₹${_totalFromCustom.toStringAsFixed(2)}',
                              style: TextStyle(
                                color:
                                    (_totalFromCustom - grandTotal).abs() < 0.5
                                    ? Colors.green
                                    : Colors.red,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const Spacer(),
                // Guest receipt chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(
                    _guestCount,
                    (i) => Chip(
                      backgroundColor: const Color(0xFF242424),
                      avatar: CircleAvatar(
                        backgroundColor: _orange.withValues(alpha: 0.2),
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 10,
                            color: _orange,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      label: Text(
                        '₹${_isEven ? perGuest.toStringAsFixed(0) : (double.tryParse(_customCtrls[i].text) ?? 0).toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.print_outlined, size: 16),
                    label: const Text('Print Split Receipts'),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Printing split receipts…'),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF2E2E2E)),
                    ),
                    onPressed: () {
                      ref.read(cartProvider.notifier).clear();
                      context.go('/floor');
                    },
                    child: const Text('Close & Clear Table'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool highlight = false}) {
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
            color: highlight ? Colors.white : Colors.grey,
            fontSize: highlight ? 16 : 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _toggleChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? _orange.withValues(alpha: 0.15)
              : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? _orange : const Color(0xFF2E2E2E),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? _orange : Colors.grey,
            fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _countButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF242424),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF2E2E2E)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
