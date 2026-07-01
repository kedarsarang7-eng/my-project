// ============================================================================
// DECORATION & CATERING — REPORTS & ANALYTICS SCREEN
// ============================================================================

import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/currency_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../data/models/dc_models.dart';
import '../../data/repositories/dc_repository.dart';
import '../../services/dc_pdf_service.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class DcReportsScreen extends ConsumerStatefulWidget {
  const DcReportsScreen({super.key});

  @override
  ConsumerState<DcReportsScreen> createState() => _DcReportsScreenState();
}

class _DcReportsScreenState extends ConsumerState<DcReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  DateTime _dateFrom = DateTime.now().subtract(const Duration(days: 30));
  DateTime _dateTo = DateTime.now();
  bool _exportingPdf = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: Column(
        children: [
          _buildHeader(context),
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabs,
              labelColor: const Color(0xFF0891B2),
              unselectedLabelColor: const Color(0xFF6B7280),
              indicatorColor: const Color(0xFF0891B2),
              isScrollable: true,
              tabs: const [
                Tab(text: 'Revenue Report'),
                Tab(text: 'Event Report'),
                Tab(text: 'Staff Report'),
                Tab(text: 'Expense Report'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _RevenueReportTab(dateFrom: _dateFrom, dateTo: _dateTo),
                _EventReportTab(dateFrom: _dateFrom, dateTo: _dateTo),
                _StaffReportTab(),
                _ExpenseReportTab(dateFrom: _dateFrom, dateTo: _dateTo),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy');
    final headerTitle = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reports & Analytics',
          style: TextStyle(
            fontSize: responsiveValue<double>(context, mobile: 18, tablet: 20, desktop: 22),
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Revenue, events, staff and expense reports',
          style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
      ],
    );

    final headerButtons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dateBtn('From: ${fmt.format(_dateFrom)}', () async {
          final d = await showDatePicker(
            context: context,
            initialDate: _dateFrom,
            firstDate: DateTime(2020),
            lastDate: DateTime.now(),
          );
          if (d != null) setState(() => _dateFrom = d);
        }),
        const SizedBox(width: 8),
        _dateBtn('To: ${fmt.format(_dateTo)}', () async {
          final d = await showDatePicker(
            context: context,
            initialDate: _dateTo,
            firstDate: DateTime(2020),
            lastDate: DateTime.now(),
          );
          if (d != null) setState(() => _dateTo = d);
        }),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: _exportingPdf ? null : () => _exportToPdf(context),
          icon: _exportingPdf
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.picture_as_pdf_rounded, size: 16),
          label: Text(_exportingPdf ? 'Generating…' : 'Export PDF'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0891B2),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );

    return Container(
      padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
      color: Colors.white,
      child: context.isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                headerTitle,
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: headerButtons,
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                headerTitle,
                headerButtons,
              ],
            ),
    );
  }

  Widget _dateBtn(String label, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.calendar_today_rounded, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF374151),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
    );
  }

  Future<void> _exportToPdf(BuildContext context) async {
    setState(() => _exportingPdf = true);
    try {
      final repo = ref.read(dcRepositoryProvider);
      final fromStr = '${_dateFrom.year.toString().padLeft(4, '0')}-${_dateFrom.month.toString().padLeft(2, '0')}-${_dateFrom.day.toString().padLeft(2, '0')}';
      final toStr   = '${_dateTo.year.toString().padLeft(4, '0')}-${_dateTo.month.toString().padLeft(2, '0')}-${_dateTo.day.toString().padLeft(2, '0')}';

      final bookingsRaw = await repo.getInvoices(limit: 200);
      final expensesRaw = await repo.getExpensesRaw(from: fromStr, to: toStr);
      final staffRaw    = await repo.getStaffRaw();

      final pdfBytes = await DcPdfService.generateReport(
        dateFrom: fromStr,
        dateTo:   toStr,
        bookings: bookingsRaw,
        expenses: expensesRaw,
        staff:    staffRaw,
      );

      await Printing.layoutPdf(
        onLayout: (_) async => pdfBytes,
        name: 'DC_Report_${fromStr}_to_$toStr.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }
}

// ---------------------------------------------------------------------------
// Revenue Report Tab
// ---------------------------------------------------------------------------
class _RevenueReportTab extends ConsumerWidget {
  final DateTime dateFrom;
  final DateTime dateTo;
  const _RevenueReportTab({required this.dateFrom, required this.dateTo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(dcBookingsProvider);
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: sl<CurrencyService>().symbol, decimalDigits: 0);

    return bookingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (bookings) {
        final inRange = bookings.where((b) =>
            b.eventDate.isAfter(dateFrom) && b.eventDate.isBefore(dateTo)).toList();
        final totalQuoted = inRange.fold<double>(0, (s, b) => s + b.quotedAmount);
        final totalCollected = inRange.fold<double>(0, (s, b) => s + b.advancePaid);
        final totalPending = inRange.fold<double>(0, (s, b) => s + b.balanceDue);
        final confirmed = inRange.where((b) => b.status == EventStatus.confirmed || b.status == EventStatus.completed).length;

        return SingleChildScrollView(
          padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (context.isMobile)
                Column(
                  children: [
                    _kpiCard(context, 'Total Quoted', fmt.format(totalQuoted), Icons.request_quote_rounded, const Color(0xFF2563EB)),
                    const SizedBox(height: 12),
                    _kpiCard(context, 'Collected', fmt.format(totalCollected), Icons.check_circle_rounded, const Color(0xFF059669)),
                    const SizedBox(height: 12),
                    _kpiCard(context, 'Pending', fmt.format(totalPending), Icons.pending_actions_rounded, const Color(0xFFDC2626)),
                    const SizedBox(height: 12),
                    _kpiCard(context, 'Confirmed Events', '$confirmed', Icons.event_available_rounded, const Color(0xFF7C3AED)),
                  ],
                )
              else
                Row(children: [
                  Expanded(child: _kpiCard(context, 'Total Quoted', fmt.format(totalQuoted), Icons.request_quote_rounded, const Color(0xFF2563EB))),
                  const SizedBox(width: 14),
                  Expanded(child: _kpiCard(context, 'Collected', fmt.format(totalCollected), Icons.check_circle_rounded, const Color(0xFF059669))),
                  const SizedBox(width: 14),
                  Expanded(child: _kpiCard(context, 'Pending', fmt.format(totalPending), Icons.pending_actions_rounded, const Color(0xFFDC2626))),
                  const SizedBox(width: 14),
                  Expanded(child: _kpiCard(context, 'Confirmed Events', '$confirmed', Icons.event_available_rounded, const Color(0xFF7C3AED))),
                ]),
              const SizedBox(height: 24),
              _buildRevenueTable(inRange, fmt),
            ],
          ),
        );
      },
    );
  }

  Widget _kpiCard(BuildContext context, String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(fontSize: responsiveValue<double>(context, mobile: 16, tablet: 18, desktop: 20), fontWeight: FontWeight.bold, color: color)),
              Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueTable(List<EventBooking> bookings, NumberFormat fmt) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Booking Revenue Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          const Divider(height: 1),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF9FAFB)),
              columns: const [
                DataColumn(label: Text('Event', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('Customer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('Quoted', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('Collected', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('Balance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              ],
              rows: bookings.map((b) => DataRow(
                cells: [
                  DataCell(Text(b.eventTitle, style: const TextStyle(fontSize: 12))),
                  DataCell(Text(b.customerName, style: const TextStyle(fontSize: 12))),
                  DataCell(Text(DateFormat('d MMM yy').format(b.eventDate), style: const TextStyle(fontSize: 12))),
                  DataCell(Text(fmt.format(b.quotedAmount), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                  DataCell(Text(fmt.format(b.advancePaid), style: const TextStyle(fontSize: 12, color: Color(0xFF059669), fontWeight: FontWeight.w500))),
                  DataCell(Text(fmt.format(b.balanceDue), style: TextStyle(fontSize: 12, color: b.balanceDue > 0 ? const Color(0xFFDC2626) : const Color(0xFF059669), fontWeight: FontWeight.w500))),
                  DataCell(Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: b.statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                    child: Text(b.statusLabel, style: TextStyle(fontSize: 10, color: b.statusColor, fontWeight: FontWeight.w600)),
                  )),
                ],
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Event Report Tab
// ---------------------------------------------------------------------------
class _EventReportTab extends ConsumerWidget {
  final DateTime dateFrom;
  final DateTime dateTo;
  const _EventReportTab({required this.dateFrom, required this.dateTo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(dcBookingsProvider);
    return bookingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (bookings) {
        final statusCounts = <EventStatus, int>{};
        final typeCounts = <EventType, int>{};
        for (final b in bookings) {
          statusCounts[b.status] = (statusCounts[b.status] ?? 0) + 1;
          typeCounts[b.eventType] = (typeCounts[b.eventType] ?? 0) + 1;
        }
        return SingleChildScrollView(
          padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
          child: context.isMobile
              ? Column(
                  children: [
                    _buildStatusBreakdown(statusCounts, bookings.length),
                    const SizedBox(height: 16),
                    _buildTypeBreakdown(typeCounts, bookings.length),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildStatusBreakdown(statusCounts, bookings.length)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildTypeBreakdown(typeCounts, bookings.length)),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildStatusBreakdown(Map<EventStatus, int> counts, int total) {
    final colors = {
      EventStatus.inquiry: Colors.orange,
      EventStatus.confirmed: Colors.blue,
      EventStatus.ongoing: Colors.purple,
      EventStatus.completed: Colors.green,
      EventStatus.cancelled: Colors.red,
    };
    return _reportCard('Bookings by Status', Icons.pie_chart_rounded, Column(
      children: counts.entries.map((e) {
        final pct = total > 0 ? e.value / total : 0.0;
        final color = colors[e.key]!;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(e.key.name.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
                  const Spacer(),
                  Text('${e.value} (${(pct * 100).toStringAsFixed(0)}%)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: pct,
                backgroundColor: color.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
            ],
          ),
        );
      }).toList(),
    ));
  }

  Widget _buildTypeBreakdown(Map<EventType, int> counts, int total) {
    final colors = [const Color(0xFF7C3AED), const Color(0xFF2563EB), const Color(0xFF059669), const Color(0xFFD97706), const Color(0xFFDC2626), const Color(0xFF0891B2), const Color(0xFF9333EA)];
    final entries = counts.entries.toList();
    return _reportCard('Bookings by Event Type', Icons.event_rounded, Column(
      children: entries.asMap().entries.map((entry) {
        final idx = entry.key;
        final e = entry.value;
        final pct = total > 0 ? e.value / total : 0.0;
        final color = colors[idx % colors.length];
        final label = EventBooking(id: '', customerId: '', customerName: '', customerPhone: '', eventType: e.key, eventTitle: '', eventDate: DateTime.now(), venue: '', guestCount: 0, quotedAmount: 0, createdAt: DateTime.now()).eventTypeLabel;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
              SizedBox(
                width: 80,
                child: LinearProgressIndicator(value: pct, backgroundColor: color.withValues(alpha: 0.1), valueColor: AlwaysStoppedAnimation(color), minHeight: 6, borderRadius: BorderRadius.circular(3)),
              ),
              const SizedBox(width: 8),
              Text('${e.value}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        );
      }).toList(),
    ));
  }

  Widget _reportCard(String title, IconData icon, Widget child) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Icon(icon, size: 18, color: const Color(0xFF0891B2)),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ]),
          ),
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Staff Report Tab
// ---------------------------------------------------------------------------
class _StaffReportTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(dcStaffProvider);
    return staffAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (staff) {
        final byRole = <StaffRole, int>{};
        final totalWage = staff.fold<double>(0, (s, m) => s + m.dailyWage);
        for (final s in staff) {
          byRole[s.role] = (byRole[s.role] ?? 0) + 1;
        }
        return SingleChildScrollView(
          padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (context.isMobile)
                Column(
                  children: [
                    _statCard(context, 'Total Staff', '${staff.length}', const Color(0xFF2563EB), isExpanded: false),
                    const SizedBox(height: 12),
                    _statCard(context, 'Available', '${staff.where((s) => s.isAvailable).length}', const Color(0xFF059669), isExpanded: false),
                    const SizedBox(height: 12),
                    _statCard(context, 'Daily Wage Budget', '₹${NumberFormat('#,##,###').format(totalWage)}', const Color(0xFF7C3AED), isExpanded: false),
                  ],
                )
              else
                Row(children: [
                  _statCard(context, 'Total Staff', '${staff.length}', const Color(0xFF2563EB)),
                  const SizedBox(width: 14),
                  _statCard(context, 'Available', '${staff.where((s) => s.isAvailable).length}', const Color(0xFF059669)),
                  const SizedBox(width: 14),
                  _statCard(context, 'Daily Wage Budget', '₹${NumberFormat('#,##,###').format(totalWage)}', const Color(0xFF7C3AED)),
                ]),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Staff by Role', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                    const Divider(height: 1),
                    ...byRole.entries.map((e) {
                      final roleStaff = staff.where((s) => s.role == e.key).toList();
                      final dummy = DcStaff(id: '', name: '', phone: '', role: e.key, dailyWage: 0);
                      final avgWage = roleStaff.isEmpty ? 0.0 : roleStaff.fold<double>(0, (s, m) => s + m.dailyWage) / roleStaff.length;
                      return ListTile(
                        leading: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(color: dummy.roleColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                          child: Icon(Icons.person_rounded, color: dummy.roleColor, size: 18),
                        ),
                        title: Text(dummy.roleLabel, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        subtitle: Text('Avg wage: ₹${avgWage.toStringAsFixed(0)}/day', style: const TextStyle(fontSize: 11)),
                        trailing: Text('${e.value}', style: TextStyle(fontSize: responsiveValue<double>(context, mobile: 16, tablet: 18, desktop: 20), fontWeight: FontWeight.bold, color: dummy.roleColor)),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statCard(BuildContext context, String label, String value, Color color, {bool isExpanded = true}) {
    final container = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(fontSize: responsiveValue<double>(context, mobile: 18, tablet: 20, desktop: 24), fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        ],
      ),
    );

    if (isExpanded) {
      return Expanded(child: container);
    }
    return SizedBox(
      width: double.infinity,
      child: container,
    );
  }
}

// ---------------------------------------------------------------------------
// Expense Report Tab
// ---------------------------------------------------------------------------
class _ExpenseReportTab extends ConsumerWidget {
  final DateTime dateFrom;
  final DateTime dateTo;
  const _ExpenseReportTab({required this.dateFrom, required this.dateTo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final from = '${dateFrom.year.toString().padLeft(4, '0')}-${dateFrom.month.toString().padLeft(2, '0')}-${dateFrom.day.toString().padLeft(2, '0')}';
    final to   = '${dateTo.year.toString().padLeft(4, '0')}-${dateTo.month.toString().padLeft(2, '0')}-${dateTo.day.toString().padLeft(2, '0')}';
    final expensesAsync = ref.watch(dcExpensesFilteredProvider((from: from, to: to)));
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: sl<CurrencyService>().symbol, decimalDigits: 0);

    return expensesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (expenses) {
        final total = expenses.fold<double>(0, (s, e) => s + e.amount);
        final byCat = <String, double>{};
        for (final e in expenses) {
          byCat[e.category] = (byCat[e.category] ?? 0) + e.amount;
        }
        return SingleChildScrollView(
          padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)]),
                child: Row(children: [
                  const Icon(Icons.money_off_rounded, color: Color(0xFFDC2626)),
                  const SizedBox(width: 8),
                  Text('Total Expenses: ${fmt.format(total)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFDC2626))),
                ]),
              ),
              const SizedBox(height: 16),
              if (context.isMobile)
                Column(
                  children: [
                    _buildExpenseTable(expenses, fmt),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)]),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('By Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 12),
                          ...byCat.entries.map((e) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(children: [
                              Expanded(child: Text(e.key, style: const TextStyle(fontSize: 12))),
                              Text(fmt.format(e.value), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                            ]),
                          )),
                        ],
                      ),
                    ),
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildExpenseTable(expenses, fmt)),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 240,
                      child: Container(
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)]),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('By Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 12),
                            ...byCat.entries.map((e) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(children: [
                                Expanded(child: Text(e.key, style: const TextStyle(fontSize: 12))),
                                Text(fmt.format(e.value), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                              ]),
                            )),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExpenseTable(List<DcExpense> expenses, NumberFormat fmt) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(padding: EdgeInsets.all(16), child: Text('Expense Entries', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
          const Divider(height: 1),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF9FAFB)),
              columns: const [
                DataColumn(label: Text('Title', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('Method', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              ],
              rows: expenses.map((e) => DataRow(cells: [
                DataCell(Text(e.title, style: const TextStyle(fontSize: 12))),
                DataCell(Text(e.category, style: const TextStyle(fontSize: 12))),
                DataCell(Text(fmt.format(e.amount), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)))),
                DataCell(Text(_methodLabel(e.paymentMethod), style: const TextStyle(fontSize: 12))),
                DataCell(Text(DateFormat('d MMM yy').format(e.date), style: const TextStyle(fontSize: 12))),
              ])).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _methodLabel(PaymentMethod m) {
    switch (m) {
      case PaymentMethod.cash: return 'Cash';
      case PaymentMethod.upi: return 'UPI';
      case PaymentMethod.card: return 'Card';
      case PaymentMethod.cheque: return 'Cheque';
      case PaymentMethod.bankTransfer: return 'Bank Transfer';
    }
  }
}
