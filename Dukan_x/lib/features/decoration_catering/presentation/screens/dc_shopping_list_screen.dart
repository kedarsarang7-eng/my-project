// ============================================================================
// DC Shopping List Screen
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/dc_models.dart';
import '../../data/repositories/dc_repository.dart';
import '../widgets/dc_ui_kit.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class DcShoppingListScreen extends ConsumerStatefulWidget {
  const DcShoppingListScreen({super.key});

  @override
  ConsumerState<DcShoppingListScreen> createState() =>
      _DcShoppingListScreenState();
}

class _DcShoppingListScreenState extends ConsumerState<DcShoppingListScreen> {
  String? _selectedEventId;
  bool _loading = false;
  List<DcShoppingListItem>? _items;
  int _guestCount = 0;
  double _totalCost = 0;
  String? _error;
  final Set<int> _checked = {};

  static const _orange = Color(0xFFD97706);

  @override
  Widget build(BuildContext context) {
    final bookingsAsync = ref.watch(dcBookingsProvider);

    return Scaffold(
      backgroundColor: DcColors.orangeLight,
      body: BoundedBox(
        maxWidth: 800,
        child: Column(
          children: [
            DcGradientHeader(
              icon: Icons.shopping_basket_rounded,
              title: 'Shopping List',
              subtitle: 'Auto-generated raw material list per event',
              color: _orange,
            ),
            Expanded(
              child: bookingsAsync.when(
                loading: () => Row(
                  children: [
                    Container(
                      width: 280,
                      color: Colors.white,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: 5,
                        itemBuilder: (ctx2, i2) => const DcCardSkeleton(),
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    const Expanded(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ],
                ),
                error: (e, _) => DcErrorState(
                  error: e,
                  onRetry: () => ref.invalidate(dcBookingsProvider),
                ),
                data: (bookings) {
                  final active =
                      bookings
                          .where(
                            (b) =>
                                b.status != EventStatus.cancelled &&
                                (b.includesCatering || b.includesDecoration),
                          )
                          .toList()
                        ..sort((a, b) => a.eventDate.compareTo(b.eventDate));

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 280, child: _buildEventPicker(active)),
                      const VerticalDivider(width: 1),
                      Expanded(child: _buildList()),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventPicker(List<EventBooking> bookings) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                const Icon(
                  Icons.event_available_rounded,
                  size: 14,
                  color: DcColors.muted,
                ),
                const SizedBox(width: 6),
                Text(
                  '${bookings.length} Events',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: DcColors.ink,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: bookings.length,
              itemBuilder: (_, i) {
                final b = bookings[i];
                final isSelected = b.id == _selectedEventId;
                return InkWell(
                  onTap: () => _loadList(b.id),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    color: isSelected ? _orange.withValues(alpha: 0.06) : null,
                    child: Row(
                      children: [
                        if (isSelected)
                          Container(
                            width: 3,
                            height: 40,
                            color: _orange,
                            margin: const EdgeInsets.only(right: 10),
                          ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                b.customerName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: isSelected
                                      ? _orange
                                      : const Color(0xFF1F2937),
                                ),
                              ),
                              Text(
                                '${b.eventTypeLabel} · ${DateFormat('d MMM').format(b.eventDate)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  if (b.includesCatering)
                                    _tag('Catering', Colors.orange),
                                  if (b.includesCatering &&
                                      b.includesDecoration)
                                    const SizedBox(width: 4),
                                  if (b.includesDecoration)
                                    _tag('Decor', _orange),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _tag(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
    ),
  );

  Widget _buildList() {
    if (_selectedEventId == null) {
      return DcEmptyState(
        icon: Icons.shopping_basket_outlined,
        title: 'Select an event',
        subtitle:
            'Choose an event from the left panel\nto auto-generate its shopping list',
        color: _orange,
      );
    }
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _orange),
            const SizedBox(height: 12),
            const Text(
              'Generating shopping list…',
              style: TextStyle(color: DcColors.muted),
            ),
          ],
        ),
      );
    }
    if (_error != null)
      return DcErrorState(
        error: _error!,
        onRetry: () => _loadList(_selectedEventId!),
      );
    if (_items == null || _items!.isEmpty) {
      return DcEmptyState(
        icon: Icons.checklist_rounded,
        title: 'No items generated',
        subtitle: 'This event has no catering or decoration items to list',
        color: _orange,
      );
    }

    final fmt = NumberFormat('#,##,###');
    final unchecked = _items!
        .where((i) => !_checked.contains(_items!.indexOf(i)))
        .length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _orange.withValues(alpha: 0.08),
                  _orange.withValues(alpha: 0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _orange.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                // Progress ring
                SizedBox(
                  width: 52,
                  height: 52,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: _items!.isEmpty
                            ? 0
                            : _checked.length / _items!.length,
                        strokeWidth: 5,
                        backgroundColor: _orange.withValues(alpha: 0.15),
                        color: DcColors.green,
                      ),
                      Text(
                        '${_items!.isEmpty ? 0 : (_checked.length / _items!.length * 100).round()}%',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: DcColors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$unchecked of ${_items!.length} remaining',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: DcColors.ink,
                      ),
                    ),
                    Text(
                      '$_guestCount guests · ≈ ₹${fmt.format(_totalCost.round())}',
                      style: TextStyle(
                        fontSize: 12,
                        color: _orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: _copyToClipboard,
                  icon: const Icon(Icons.copy_rounded, size: 14),
                  label: const Text('Copy List'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _orange,
                    side: BorderSide(color: _orange),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Items
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              children: _items!.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;
                final isDone = _checked.contains(idx);
                return InkWell(
                  onTap: () => setState(() {
                    if (isDone) {
                      _checked.remove(idx);
                    } else {
                      _checked.add(idx);
                    }
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isDone ? const Color(0xFFF0FDF4) : null,
                      border: entry.key < _items!.length - 1
                          ? const Border(
                              bottom: BorderSide(color: Color(0xFFE5E7EB)),
                            )
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isDone
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: isDone
                              ? const Color(0xFF059669)
                              : const Color(0xFFD1D5DB),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.item,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isDone
                                  ? const Color(0xFF9CA3AF)
                                  : const Color(0xFF1F2937),
                              decoration: isDone
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        Text(
                          '${item.qty % 1 == 0 ? item.qty.round() : item.qty} ${item.unit}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(width: 20),
                        SizedBox(
                          width: 80,
                          child: Text(
                            '≈ ₹${fmt.format(item.estimatedCost.round())}',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDone
                                  ? const Color(0xFF9CA3AF)
                                  : const Color(0xFF374151),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadList(String eventId) async {
    setState(() {
      _selectedEventId = eventId;
      _loading = true;
      _error = null;
      _items = null;
      _checked.clear();
    });
    try {
      final result = await ref
          .read(dcRepositoryProvider)
          .getShoppingList(eventId);
      if (mounted)
        setState(() {
          _items = result.items;
          _guestCount = result.guestCount;
          _totalCost = result.totalCost;
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    }
  }

  void _copyToClipboard() {
    if (_items == null) return;
    final lines = _items!
        .map((i) {
          final qty = i.qty % 1 == 0 ? '${i.qty.round()}' : '${i.qty}';
          return '[ ] ${i.item} — $qty ${i.unit}';
        })
        .join('\n');
    Clipboard.setData(
      ClipboardData(text: 'Shopping List ($_guestCount guests)\n\n$lines'),
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
  }
}
