// ============================================================================
// DECORATION & CATERING — DASHBOARD SCREEN
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/services/websocket_service.dart'
    show WebSocketService, WSEvent;
import '../../data/models/dc_models.dart';
import '../../data/repositories/dc_repository.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class DcDashboardScreen extends ConsumerStatefulWidget {
  const DcDashboardScreen({super.key});

  @override
  ConsumerState<DcDashboardScreen> createState() => _DcDashboardScreenState();
}

class _DcDashboardScreenState extends ConsumerState<DcDashboardScreen> {
  final List<void Function()> _wsUnsubs = [];

  static const _dcWsEvents = [
    'dc_invoice_created',
    'dc_event_created',
    'dc_event_updated',
    'dc_event_status_changed',
    'dc_payment_received',
    'dc_expense_added',
    'dc_inventory_low_stock',
  ];

  @override
  void initState() {
    super.initState();
    _attachWsListeners();
  }

  void _attachWsListeners() {
    try {
      final ws = sl<WebSocketService>();
      for (final eventName in _dcWsEvents) {
        void handler(WSEvent e) {
          if (!mounted) return;
          ref.invalidate(dcStatsProvider);
          ref.invalidate(dcBookingsProvider);
        }

        ws.subscribe(eventName, handler);
        _wsUnsubs.add(() => ws.unsubscribe(eventName, handler));
      }
    } catch (_) {
      // WS not available in offline mode — providers will refresh on navigation
    }
  }

  @override
  void dispose() {
    for (final unsub in _wsUnsubs) {
      unsub();
    }
    _wsUnsubs.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(dcStatsProvider);
    final bookingsAsync = ref.watch(dcBookingsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(
          responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            statsAsync.when(
              loading: () => _buildKpiSkeletons(),
              error: (e, _) => _buildError(e),
              data: (stats) => _buildKpiCards(context, stats),
            ),
            const SizedBox(height: 24),
            if (context.isMobile)
              Column(
                children: [
                  statsAsync.when(
                    loading: () => _chartSkeleton(),
                    error: (e, st) => const SizedBox(),
                    data: (stats) => _buildRevenueChart(context, stats),
                  ),
                  const SizedBox(height: 16),
                  statsAsync.when(
                    loading: () => _chartSkeleton(height: 200),
                    error: (e, st) => const SizedBox(),
                    data: (stats) => _buildDailyRevenueChart(context, stats),
                  ),
                  const SizedBox(height: 16),
                  statsAsync.when(
                    loading: () => _chartSkeleton(),
                    error: (e, st) => const SizedBox(),
                    data: (stats) => _buildEventTypeChart(context, stats),
                  ),
                  const SizedBox(height: 16),
                  bookingsAsync.when(
                    loading: () => _chartSkeleton(height: 320),
                    error: (e, st) => const SizedBox(),
                    data: (bookings) => _buildUpcomingEvents(context, bookings),
                  ),
                  const SizedBox(height: 16),
                  _buildQuickActions(context),
                ],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        statsAsync.when(
                          loading: () => _chartSkeleton(),
                          error: (e, st) => const SizedBox(),
                          data: (stats) => _buildRevenueChart(context, stats),
                        ),
                        const SizedBox(height: 16),
                        statsAsync.when(
                          loading: () => _chartSkeleton(height: 200),
                          error: (e, st) => const SizedBox(),
                          data: (stats) =>
                              _buildDailyRevenueChart(context, stats),
                        ),
                        const SizedBox(height: 16),
                        statsAsync.when(
                          loading: () => _chartSkeleton(),
                          error: (e, st) => const SizedBox(),
                          data: (stats) => _buildEventTypeChart(context, stats),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        bookingsAsync.when(
                          loading: () => _chartSkeleton(height: 320),
                          error: (e, st) => const SizedBox(),
                          data: (bookings) =>
                              _buildUpcomingEvents(context, bookings),
                        ),
                        const SizedBox(height: 16),
                        _buildQuickActions(context),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final now = DateTime.now();
    final headerTitle = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Event Command Center',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          DateFormat('EEEE, d MMMM yyyy').format(now),
          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
        ),
      ],
    );

    final headerButtons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _headerBtn(
          context,
          Icons.add_circle_outline,
          'New Booking',
          const Color(0xFF7C3AED),
          () {
            context.push('/dc/bookings/new');
          },
        ),
        const SizedBox(width: 8),
        _headerBtn(
          context,
          Icons.receipt_long_outlined,
          'New Invoice',
          const Color(0xFF059669),
          () {
            context.push('/dc/billing');
          },
        ),
      ],
    );

    if (context.isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          headerTitle,
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: headerButtons,
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [headerTitle, headerButtons],
    );
  }

  Widget _headerBtn(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildKpiCards(BuildContext context, DcDashboardStats stats) {
    final fmt = NumberFormat.currency(
      locale: 'en_IN',
      symbol: sl<CurrencyService>().symbol,
      decimalDigits: 0,
    );
    final cards = [
      _KpiData(
        'Total Bookings',
        '${stats.totalBookings}',
        Icons.event_note_rounded,
        const Color(0xFF7C3AED),
        null,
      ),
      _KpiData(
        'Upcoming Events',
        '${stats.upcomingEvents}',
        Icons.upcoming_rounded,
        const Color(0xFF2563EB),
        null,
      ),
      _KpiData(
        'Today\'s Events',
        '${stats.todayEvents}',
        Icons.today_rounded,
        stats.todayEvents > 0
            ? const Color(0xFFD97706)
            : const Color(0xFF6B7280),
        null,
      ),
      _KpiData(
        'Total Revenue',
        fmt.format(stats.totalRevenue),
        Icons.currency_rupee_rounded,
        const Color(0xFF059669),
        null,
      ),
      _KpiData(
        'Pending Dues',
        fmt.format(stats.pendingPayments),
        Icons.pending_actions_rounded,
        const Color(0xFFDC2626),
        null,
      ),
      _KpiData(
        'Monthly Profit',
        fmt.format(stats.monthlyProfit),
        Icons.trending_up_rounded,
        stats.monthlyProfit >= 0
            ? const Color(0xFF059669)
            : const Color(0xFFDC2626),
        null,
      ),
      _KpiData(
        'Active Staff',
        '${stats.activeStaff}',
        Icons.people_rounded,
        const Color(0xFF0891B2),
        null,
      ),
      _KpiData(
        'Low Stock Alerts',
        '${stats.lowStockAlerts}',
        Icons.warning_amber_rounded,
        stats.lowStockAlerts > 0
            ? const Color(0xFFD97706)
            : const Color(0xFF059669),
        null,
      ),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisExtent: 110,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: cards.length,
      itemBuilder: (ctx, i) => _buildKpiCard(cards[i]),
    );
  }

  Widget _buildKpiCard(_KpiData data) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(data.icon, color: data.color, size: 20),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.value,
                style: TextStyle(
                  fontSize: responsiveValue<double>(
                    context,
                    mobile: 18,
                    tablet: 20,
                    desktop: 22,
                  ),
                  fontWeight: FontWeight.bold,
                  color: data.color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                data.label,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueChart(BuildContext context, DcDashboardStats stats) {
    final entries = stats.revenueByMonth.entries.toList();
    final maxVal = entries.isEmpty
        ? 1.0
        : entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final fmt = NumberFormat.currency(
      locale: 'en_IN',
      symbol: sl<CurrencyService>().symbol,
      decimalDigits: 0,
    );

    return _card(
      context,
      title: 'Revenue Trend (Last 6 Months)',
      icon: Icons.bar_chart_rounded,
      child: SizedBox(
        height: 200,
        child: entries.isEmpty
            ? const Center(
                child: Text(
                  'No data',
                  style: TextStyle(color: Color(0xFF9CA3AF)),
                ),
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: entries.map((e) {
                  final pct = maxVal > 0 ? e.value / maxVal : 0.0;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            e.value > 0 ? fmt.format(e.value) : '',
                            style: const TextStyle(
                              fontSize: 8,
                              color: Color(0xFF6B7280),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 600),
                            height: (160 * pct).clamp(4.0, 160.0),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF7C3AED), Color(0xFFA78BFA)],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            e.key,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
      ),
    );
  }

  Widget _buildDailyRevenueChart(BuildContext context, DcDashboardStats stats) {
    final raw = stats.revenueByDay;
    if (raw.isEmpty) return const SizedBox();
    final entries = (raw.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key)));
    final maxVal = entries
        .map((e) => e.value)
        .fold(0.0, (a, b) => a > b ? a : b);
    final fmt = NumberFormat.currency(
      locale: 'en_IN',
      symbol: sl<CurrencyService>().symbol,
      decimalDigits: 0,
    );
    final visibleEntries = entries.length > 30
        ? entries.sublist(entries.length - 30)
        : entries;

    return _card(
      context,
      title: 'Daily Revenue (Last 30 Days)',
      icon: Icons.show_chart_rounded,
      child: SizedBox(
        height: 160,
        child: visibleEntries.every((e) => e.value == 0)
            ? const Center(
                child: Text(
                  'No invoices in this period',
                  style: TextStyle(color: Color(0xFF9CA3AF)),
                ),
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: visibleEntries.map((e) {
                  final pct = maxVal > 0 ? e.value / maxVal : 0.0;
                  final barH = (120 * pct).clamp(2.0, 120.0);
                  final dayLabel = e.key.length >= 10
                      ? e.key.substring(8)
                      : e.key;
                  return Expanded(
                    child: Tooltip(
                      message: '${e.key}: ${fmt.format(e.value)}',
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            height: barH,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              color: e.value > 0
                                  ? const Color(0xFF0891B2)
                                  : const Color(0xFFE5E7EB),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            int.tryParse(dayLabel) != null &&
                                    int.parse(dayLabel) % 5 == 0
                                ? dayLabel
                                : '',
                            style: const TextStyle(
                              fontSize: 8,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
      ),
    );
  }

  Widget _buildEventTypeChart(BuildContext context, DcDashboardStats stats) {
    final data = stats.bookingsByType;
    if (data.isEmpty) return const SizedBox();
    final total = data.values.fold(0, (s, v) => s + v);

    final colors = [
      const Color(0xFF7C3AED),
      const Color(0xFF2563EB),
      const Color(0xFF059669),
      const Color(0xFFD97706),
      const Color(0xFFDC2626),
      const Color(0xFF0891B2),
      const Color(0xFF9333EA),
    ];

    return _card(
      context,
      title: 'Bookings by Event Type',
      icon: Icons.donut_small_rounded,
      child: Column(
        children: data.entries.toList().asMap().entries.map((entry) {
          final idx = entry.key;
          final e = entry.value;
          final pct = total > 0 ? e.value / total : 0.0;
          final color = colors[idx % colors.length];
          final typeLabel = EventBooking(
            id: '',
            customerId: '',
            customerName: '',
            customerPhone: '',
            eventType: e.key,
            eventTitle: '',
            eventDate: DateTime.now(),
            venue: '',
            guestCount: 0,
            quotedAmount: 0,
            createdAt: DateTime.now(),
          ).eventTypeLabel;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(typeLabel, style: const TextStyle(fontSize: 12)),
                ),
                SizedBox(
                  width: 100,
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: color.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation(color),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${e.value}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildUpcomingEvents(
    BuildContext context,
    List<EventBooking> bookings,
  ) {
    final upcoming = bookings
        .where(
          (b) =>
              b.eventDate.isAfter(DateTime.now()) &&
              b.status != EventStatus.cancelled,
        )
        .take(6)
        .toList();

    return _card(
      context,
      title: 'Upcoming Events',
      icon: Icons.event_rounded,
      child: upcoming.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'No upcoming events',
                  style: TextStyle(color: Color(0xFF9CA3AF)),
                ),
              ),
            )
          : Column(
              children: upcoming
                  .map((b) => _upcomingEventTile(context, b))
                  .toList(),
            ),
    );
  }

  Widget _upcomingEventTile(BuildContext context, EventBooking b) {
    final daysLeft = b.eventDate.difference(DateTime.now()).inDays;
    return InkWell(
      onTap: () => context.push('/dc/bookings', extra: {'bookingId': b.id}),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: b.statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('d').format(b.eventDate),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: b.statusColor,
                    ),
                  ),
                  Text(
                    DateFormat('MMM').format(b.eventDate),
                    style: TextStyle(fontSize: 10, color: b.statusColor),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    b.eventTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    b.customerName,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  Text(
                    b.venue,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9CA3AF),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: b.statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
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
                const SizedBox(height: 4),
                Text(
                  daysLeft == 0
                      ? 'Today!'
                      : daysLeft == 1
                      ? 'Tomorrow'
                      : 'in $daysLeft days',
                  style: TextStyle(
                    fontSize: 10,
                    color: daysLeft <= 2 ? Colors.red : const Color(0xFF6B7280),
                    fontWeight: daysLeft <= 2
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return _card(
      context,
      title: 'Quick Actions',
      icon: Icons.flash_on_rounded,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _quickActionChip(
            context,
            Icons.event_available_rounded,
            'New Booking',
            const Color(0xFF7C3AED),
            '/dc/bookings/new',
          ),
          _quickActionChip(
            context,
            Icons.people_rounded,
            'Add Staff',
            const Color(0xFF059669),
            '/dc/staff',
          ),
          _quickActionChip(
            context,
            Icons.inventory_2_rounded,
            'Inventory',
            const Color(0xFF2563EB),
            '/dc/inventory',
          ),
          _quickActionChip(
            context,
            Icons.restaurant_menu_rounded,
            'Menu',
            const Color(0xFFD97706),
            '/dc/catering',
          ),
          _quickActionChip(
            context,
            Icons.palette_rounded,
            'Themes',
            const Color(0xFFDC2626),
            '/dc/decoration',
          ),
          _quickActionChip(
            context,
            Icons.bar_chart_rounded,
            'Reports',
            const Color(0xFF0891B2),
            '/dc/reports',
          ),
        ],
      ),
    );
  }

  Widget _quickActionChip(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
    String route,
  ) {
    return InkWell(
      onTap: () => context.push(route),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, size: 18, color: const Color(0xFF7C3AED)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }

  Widget _buildKpiSkeletons() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisExtent: 110,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: 8,
      itemBuilder: (ctx, i) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
    );
  }

  Widget _chartSkeleton({double height = 270}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }

  Widget _buildError(Object e) {
    return Center(
      child: Text('Error: $e', style: const TextStyle(color: Colors.red)),
    );
  }
}

class _KpiData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  const _KpiData(this.label, this.value, this.icon, this.color, this.subtitle);
}
