// ============================================================================
// DC Event Profitability Screen
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/dc_models.dart';
import '../../data/repositories/dc_repository.dart';
import '../widgets/dc_ui_kit.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class DcProfitabilityScreen extends ConsumerStatefulWidget {
  const DcProfitabilityScreen({super.key});

  @override
  ConsumerState<DcProfitabilityScreen> createState() =>
      _DcProfitabilityScreenState();
}

class _DcProfitabilityScreenState extends ConsumerState<DcProfitabilityScreen> {
  String? _selectedEventId;
  bool _loading = false;
  Map<String, dynamic>? _profitData;
  String? _error;

  static const _purple = Color(0xFF7C3AED);
  static const _green = Color(0xFF059669);
  static const _red = Color(0xFFDC2626);

  @override
  Widget build(BuildContext context) {
    final bookingsAsync = ref.watch(dcBookingsProvider);

    return Scaffold(
      backgroundColor: DcColors.surface,
      body: BoundedBox(
        maxWidth: 800,
        child: Column(
          children: [
            DcGradientHeader(
              icon: Icons.trending_up_rounded,
              title: 'Event Profitability',
              subtitle: 'Revenue vs expenses per event',
              color: _purple,
            ),
            Expanded(
              child: bookingsAsync.when(
                loading: () => Row(
                  children: [
                    Container(
                      width: 300,
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
                data: (bookings) => Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 300, child: _buildEventList(bookings)),
                    const VerticalDivider(width: 1),
                    Expanded(child: _buildDetail()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventList(List<EventBooking> bookings) {
    final completed = bookings
        .where(
          (b) =>
              b.status == EventStatus.completed ||
              b.status == EventStatus.confirmed,
        )
        .toList();
    completed.sort((a, b) => b.eventDate.compareTo(a.eventDate));

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                const Icon(
                  Icons.event_rounded,
                  size: 15,
                  color: DcColors.muted,
                ),
                const SizedBox(width: 6),
                Text(
                  '${completed.length} Events',
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
              itemCount: completed.length,
              itemBuilder: (_, i) {
                final b = completed[i];
                final isSelected = b.id == _selectedEventId;
                return InkWell(
                  onTap: () => _loadProfitability(b.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    color: isSelected ? _purple.withValues(alpha: 0.07) : null,
                    child: Row(
                      children: [
                        if (isSelected)
                          Container(
                            width: 3,
                            height: 36,
                            color: _purple,
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
                                      ? _purple
                                      : const Color(0xFF1F2937),
                                ),
                              ),
                              Text(
                                '${b.eventTypeLabel} · ${DateFormat('d MMM yyyy').format(b.eventDate)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: b.statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            b.statusLabel,
                            style: TextStyle(
                              fontSize: 10,
                              color: b.statusColor,
                              fontWeight: FontWeight.w600,
                            ),
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

  Widget _buildDetail() {
    if (_selectedEventId == null) {
      return DcEmptyState(
        icon: Icons.analytics_outlined,
        title: 'Select an event',
        subtitle:
            'Choose a completed or confirmed event\nfrom the left panel to view its profitability',
        color: _purple,
      );
    }
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _purple),
            const SizedBox(height: 12),
            const Text(
              'Loading profitability data…',
              style: TextStyle(color: DcColors.muted),
            ),
          ],
        ),
      );
    }
    if (_error != null)
      return DcErrorState(
        error: _error!,
        onRetry: () => _loadProfitability(_selectedEventId!),
      );
    if (_profitData == null) return const SizedBox();

    final fmt = NumberFormat('#,##,###');
    final data = _profitData!;
    final revenue = (data['totalRevenue'] as double?) ?? 0;
    final collected = (data['totalCollected'] as double?) ?? 0;
    final expenses = (data['totalExpenses'] as double?) ?? 0;
    final profit = (data['netProfit'] as double?) ?? 0;
    final margin = (data['marginPct'] as int?) ?? 0;
    final byCat = (data['expenseByCategory'] as Map<String, double>?) ?? {};
    final isProfit = profit >= 0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(
        responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Customer info bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_rounded, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 8),
                Text(
                  data['customerName'] as String? ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: Color(0xFF9CA3AF),
                ),
                const SizedBox(width: 4),
                Text(
                  () {
                    final dateStr = data['eventDate'] as String? ?? '';
                    final endDateStr = data['eventEndDate'] as String? ?? '';
                    if (endDateStr.isNotEmpty && endDateStr != dateStr) {
                      return '$dateStr – $endDateStr';
                    }
                    return dateStr;
                  }(),
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(
                  Icons.people_rounded,
                  size: 14,
                  color: Color(0xFF9CA3AF),
                ),
                const SizedBox(width: 4),
                Text(
                  '${data['guestCount']} guests',
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // KPI cards
          Row(
            children: [
              Expanded(
                child: _kpiCard(
                  'Total Revenue',
                  '₹${fmt.format(revenue.round())}',
                  Icons.receipt_rounded,
                  const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _kpiCard(
                  'Collected',
                  '₹${fmt.format(collected.round())}',
                  Icons.payments_rounded,
                  _green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _kpiCard(
                  'Total Expenses',
                  '₹${fmt.format(expenses.round())}',
                  Icons.shopping_cart_rounded,
                  const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _kpiCard(
                  'Net Profit',
                  '₹${fmt.format(profit.round())}',
                  isProfit
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  isProfit ? _green : _red,
                  subtitle: '$margin% margin',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Profit bar
          _buildProfitBar(collected, expenses),
          const SizedBox(height: 20),
          // Expense breakdown
          if (byCat.isNotEmpty) ...[
            const Text(
              'Expense Breakdown',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                children: byCat.entries.map((e) {
                  final pct = expenses > 0
                      ? (e.value / expenses * 100).round()
                      : 0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            e.key,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        SizedBox(
                          width: 120,
                          child: LinearProgressIndicator(
                            value: expenses > 0 ? e.value / expenses : 0,
                            backgroundColor: const Color(0xFFF3F4F6),
                            color: const Color(0xFFF59E0B),
                            borderRadius: BorderRadius.circular(4),
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$pct%',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 80,
                          child: Text(
                            '₹${fmt.format(e.value.round())}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kpiCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Icon(icon, color: color, size: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: color.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(fontSize: 11, color: DcColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfitBar(double collected, double expenses) {
    final total = collected + expenses;
    if (total == 0) return const SizedBox();
    final collectedFrac = (collected / total).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Revenue vs Expenses',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: [
                Expanded(
                  flex: (collectedFrac * 100).round(),
                  child: Container(height: 16, color: _green),
                ),
                Expanded(
                  flex: ((1 - collectedFrac) * 100).round(),
                  child: Container(height: 16, color: const Color(0xFFF59E0B)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _legend(_green, 'Collected'),
              const SizedBox(width: 16),
              _legend(const Color(0xFFF59E0B), 'Expenses'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(
        label,
        style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
      ),
    ],
  );

  Future<void> _loadProfitability(String eventId) async {
    setState(() {
      _selectedEventId = eventId;
      _loading = true;
      _error = null;
      _profitData = null;
    });
    try {
      final data = await ref
          .read(dcRepositoryProvider)
          .getEventProfitability(eventId);
      if (mounted)
        setState(() {
          _profitData = data;
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
}
