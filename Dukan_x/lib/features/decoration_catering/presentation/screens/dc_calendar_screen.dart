// ============================================================================
// DC Event Calendar Screen
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/dc_models.dart';
import '../../data/repositories/dc_repository.dart';
import '../widgets/dc_ui_kit.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class DcCalendarScreen extends ConsumerStatefulWidget {
  const DcCalendarScreen({super.key});

  @override
  ConsumerState<DcCalendarScreen> createState() => _DcCalendarScreenState();
}

class _DcCalendarScreenState extends ConsumerState<DcCalendarScreen> {
  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedDay;

  static const _purple = Color(0xFF7C3AED);

  @override
  Widget build(BuildContext context) {
    final bookingsAsync = ref.watch(dcBookingsProvider);

    return Scaffold(
      backgroundColor: DcColors.surface,
      body: BoundedBox(
        maxWidth: 800,
        child: bookingsAsync.when(
          loading: () => Column(
            children: [
              DcGradientHeader(
                icon: Icons.calendar_month_rounded,
                title: 'Event Calendar',
                subtitle: 'Monthly view of all scheduled events',
                color: _purple,
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: 5,
                  itemBuilder: (ctx2, i2) => const DcCardSkeleton(),
                ),
              ),
            ],
          ),
          error: (e, _) => Column(
            children: [
              DcGradientHeader(
                icon: Icons.calendar_month_rounded,
                title: 'Event Calendar',
                subtitle: 'Monthly view of all scheduled events',
                color: _purple,
              ),
              Expanded(
                child: DcErrorState(
                  error: e,
                  onRetry: () => ref.invalidate(dcBookingsProvider),
                ),
              ),
            ],
          ),
          data: (bookings) {
            final byDate = <String, List<EventBooking>>{};
            for (final b in bookings) {
              // For multi-day events, register the booking on each day in the range
              if (b.eventEndDate != null &&
                  b.eventEndDate!.isAfter(b.eventDate)) {
                var day = b.eventDate;
                while (!day.isAfter(b.eventEndDate!)) {
                  final key = DateFormat('yyyy-MM-dd').format(day);
                  byDate.putIfAbsent(key, () => []).add(b);
                  day = day.add(const Duration(days: 1));
                }
              } else {
                final key = DateFormat('yyyy-MM-dd').format(b.eventDate);
                byDate.putIfAbsent(key, () => []).add(b);
              }
            }
            return Column(
              children: [
                DcGradientHeader(
                  icon: Icons.calendar_month_rounded,
                  title: 'Event Calendar',
                  subtitle: '${bookings.length} events scheduled',
                  color: _purple,
                  actions: [
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        DateFormat('MMMM yyyy').format(_focusedMonth),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
                _buildMonthNav(),
                _buildLegend(),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildCalendarGrid(byDate),
                        if (_selectedDay != null)
                          _buildDayEvents(byDate, bookings),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLegend() {
    final statuses = [
      ('Inquiry', Colors.orange),
      ('Confirmed', Colors.blue),
      ('Ongoing', Colors.purple),
      ('Completed', DcColors.green),
      ('Cancelled', DcColors.red),
    ];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
      child: Row(
        children: statuses
            .map(
              (s) => Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: s.$2,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      s.$1,
                      style: const TextStyle(
                        fontSize: 10,
                        color: DcColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildMonthNav() => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
    child: Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          tooltip: 'Previous month',
          onPressed: () => setState(
            () => _focusedMonth = DateTime(
              _focusedMonth.year,
              _focusedMonth.month - 1,
            ),
          ),
          style: IconButton.styleFrom(foregroundColor: _purple),
        ),
        Expanded(
          child: Center(
            child: Text(
              DateFormat('MMMM yyyy').format(_focusedMonth),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: DcColors.ink,
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded),
          tooltip: 'Next month',
          onPressed: () => setState(
            () => _focusedMonth = DateTime(
              _focusedMonth.year,
              _focusedMonth.month + 1,
            ),
          ),
          style: IconButton.styleFrom(foregroundColor: _purple),
        ),
        Container(
          decoration: BoxDecoration(
            color: _purple.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: TextButton(
            onPressed: () => setState(() {
              _focusedMonth = DateTime.now();
              _selectedDay = null;
            }),
            style: TextButton.styleFrom(
              foregroundColor: _purple,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
            ),
            child: const Text(
              'Today',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildCalendarGrid(Map<String, List<EventBooking>> byDate) {
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final daysInMonth = DateTime(
      _focusedMonth.year,
      _focusedMonth.month + 1,
      0,
    ).day;
    final startWeekday = firstDay.weekday % 7; // 0=Sun
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8),
        ],
      ),
      child: Column(
        children: [
          // Day headers
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                  .map(
                    (d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const Divider(height: 1),
          // Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: responsiveValue<int>(
                context,
                mobile: 1,
                tablet: 2,
                desktop: 7, // PRESERVED: Desktop uses exactly 7 as before
              ),
              childAspectRatio: 1.2,
            ),
            itemCount: startWeekday + daysInMonth,
            itemBuilder: (ctx, idx) {
              if (idx < startWeekday) return const SizedBox();
              final day = idx - startWeekday + 1;
              final dateKey = DateFormat(
                'yyyy-MM-dd',
              ).format(DateTime(_focusedMonth.year, _focusedMonth.month, day));
              final events = byDate[dateKey] ?? [];
              final isToday = dateKey == today;
              final isSelected =
                  _selectedDay != null &&
                  DateFormat('yyyy-MM-dd').format(_selectedDay!) == dateKey;

              return GestureDetector(
                onTap: () => setState(
                  () => _selectedDay = DateTime(
                    _focusedMonth.year,
                    _focusedMonth.month,
                    day,
                  ),
                ),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _purple
                        : isToday
                        ? _purple.withValues(alpha: 0.1)
                        : null,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$day',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isToday || isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected
                              ? Colors.white
                              : isToday
                              ? _purple
                              : const Color(0xFF374151),
                        ),
                      ),
                      if (events.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ...events
                                .take(3)
                                .map(
                                  (e) => Container(
                                    width: 5,
                                    height: 5,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.white70
                                          : e.statusColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildDayEvents(
    Map<String, List<EventBooking>> byDate,
    List<EventBooking> allBookings,
  ) {
    final dateKey = DateFormat('yyyy-MM-dd').format(_selectedDay!);
    final events = byDate[dateKey] ?? [];
    final fmt = NumberFormat('#,##,###');

    return Expanded(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                DateFormat('EEEE, d MMMM yyyy').format(_selectedDay!),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF1F2937),
                ),
              ),
            ),
            const Divider(height: 1),
            if (events.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    'No events on this day',
                    style: TextStyle(color: Color(0xFF9CA3AF)),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: events.length,
                  separatorBuilder: (context2, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context2, i) {
                    final e = events[i];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: e.statusColor.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: e.statusColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 44,
                            decoration: BoxDecoration(
                              color: e.statusColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.customerName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  '${e.eventTypeLabel} · ${e.guestCount} guests · ${e.venue}'
                                  '${e.eventEndDate != null ? '\n${DateFormat("d MMM").format(e.eventDate)} – ${DateFormat("d MMM").format(e.eventEndDate!)}' : ''}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: e.statusColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  e.statusLabel,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: e.statusColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '₹${fmt.format(e.quotedAmount.round())}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF7C3AED),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
