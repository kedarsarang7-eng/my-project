// ============================================================================
// EVENT BOOKING STATEMENT SCREEN - Phase 2.4
// ============================================================================
// Event bookings for Decoration & Catering
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/services/statements_service.dart';
import '../../../../widgets/glass_morphism.dart';
import '../../../../core/theme/futuristic_colors.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class EventBookingStatementScreen extends ConsumerStatefulWidget {
  const EventBookingStatementScreen({super.key});

  @override
  ConsumerState<EventBookingStatementScreen> createState() =>
      _EventBookingStatementScreenState();
}

class _EventBookingStatementScreenState
    extends ConsumerState<EventBookingStatementScreen> {
  final StatementsService _statementsService = sl<StatementsService>();

  bool _isLoading = true;
  EventBookingStatement? _statement;
  String? _error;

  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedStatus;

  final List<String> _statusOptions = ['All', 'CONFIRMED', 'PENDING', 'COMPLETED', 'CANCELLED'];

  @override
  void initState() {
    super.initState();
    _startDate = DateTime.now();
    _endDate = DateTime.now().add(const Duration(days: 90));
    _loadStatement();
  }

  Future<void> _loadStatement() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final statement = await _statementsService.generateEventBookingStatement(
        startDate: _startDate,
        endDate: _endDate,
        status: _selectedStatus == 'All' ? null : _selectedStatus,
      );

      setState(() {
        _statement = statement;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final date = await showDatePicker(
      context: context,
      initialDate: isStart ? (_startDate ?? DateTime.now()) : (_endDate ?? DateTime.now()),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      setState(() {
        if (isStart) {
          _startDate = date;
        } else {
          _endDate = date;
        }
      });
      _loadStatement();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Event Booking Statement',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Upcoming events overview',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _statement != null && _statement!.entries.isNotEmpty ? () {} : null,
            tooltip: 'Export PDF',
          ),
        ],
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: Column(
        children: [
          _buildFilterBar(isDark),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildError()
                    : _statement == null || _statement!.entries.isEmpty
                        ? _buildEmptyState()
                        : _buildStatementContent(isDark),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildFilterBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(bottom: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildDateButton(label: 'From', date: _startDate, onTap: () => _pickDate(true), isDark: isDark)),
              const SizedBox(width: 12),
              Icon(Icons.arrow_forward, color: isDark ? Colors.white60 : Colors.grey, size: 16),
              const SizedBox(width: 12),
              Expanded(child: _buildDateButton(label: 'To', date: _endDate, onTap: () => _pickDate(false), isDark: isDark)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedStatus ?? 'All',
                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      onChanged: (value) {
                        setState(() {
                          _selectedStatus = value == 'All' ? null : value;
                        });
                        _loadStatement();
                      },
                      items: _statusOptions.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _loadStatement,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FuturisticColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateButton({required String label, required DateTime? date, required VoidCallback onTap, required bool isDark}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.grey.shade600)),
            const SizedBox(height: 2),
            Text(
              date != null ? DateFormat('dd MMM yyyy').format(date) : 'Select Date',
              style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('Error loading statement', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadStatement, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_outlined, size: 64, color: Theme.of(context).disabledColor),
          const SizedBox(height: 16),
          Text('No bookings found', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Try adjusting the date range',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).disabledColor),
          ),
        ],
      ),
    );
  }

  Widget _buildStatementContent(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCards(isDark),
          const SizedBox(height: 24),
          _buildStatusDistribution(isDark),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Event Bookings',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                '${_statement!.entries.length} bookings',
                style: TextStyle(color: isDark ? Colors.white60 : Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._statement!.entries.map((entry) => _buildBookingEntry(entry, isDark)),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(bool isDark) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: responsiveValue<int>(context, mobile: 1, tablet: 2, desktop: 2),
      childAspectRatio: 1.3,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _buildSummaryCard('Total Bookings', '${_statement!.totalBookings}', '', Colors.blue, isDark),
        _buildSummaryCard('Confirmed', '${_statement!.confirmedCount}', 'Ready to go', Colors.green, isDark),
        _buildSummaryCard('Total Value', _formatCurrency(_statement!.totalBookingValue), 'All bookings', Colors.purple, isDark),
        _buildSummaryCard('Pending', '${_statement!.pendingCount}', 'Needs attention', Colors.orange, isDark),
      ],
    );
  }

  Widget _buildSummaryCard(String label, String value, String subtitle, Color color, bool isDark) {
    return GlassCard(
      borderRadius: 12,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.grey.shade600)),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: responsiveValue<double>(context, mobile: 16, tablet: 18, desktop: 20), fontWeight: FontWeight.bold, color: color)),
          if (subtitle.isNotEmpty)
            Text(subtitle, style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildStatusDistribution(bool isDark) {
    final total = _statement!.totalBookings;
    if (total == 0) return const SizedBox.shrink();

    return GlassCard(
      borderRadius: 12,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Status Distribution',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildDistributionBar('Confirmed', _statement!.confirmedCount, total, Colors.green),
          _buildDistributionBar('Pending', _statement!.pendingCount, total, Colors.orange),
          _buildDistributionBar('Completed', _statement!.completedCount, total, Colors.blue),
          _buildDistributionBar('Cancelled', _statement!.cancelledCount, total, Colors.red),
        ],
      ),
    );
  }

  Widget _buildDistributionBar(String label, int count, int total, Color color) {
    final percent = total > 0 ? (count / total) * 100 : 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: Text(label, style: const TextStyle(fontSize: 13))),
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percent / 100,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text('$count', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildBookingEntry(EventBookingEntry entry, bool isDark) {
    Color statusColor;
    switch (entry.status) {
      case 'CONFIRMED':
        statusColor = Colors.green;
        break;
      case 'PENDING':
        statusColor = Colors.orange;
        break;
      case 'COMPLETED':
        statusColor = Colors.blue;
        break;
      case 'CANCELLED':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.grey;
    }

    final daysUntil = entry.eventDate.difference(DateTime.now()).inDays;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withOpacity(0.5)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: statusColor.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(Icons.event, color: statusColor, size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Booking #${entry.bookingNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(entry.eventType, style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.grey.shade600)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                entry.status,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: isDark ? Colors.white54 : Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '${_formatDate(entry.eventDate)} (${daysUntil >= 0 ? 'in $daysUntil days' : '${daysUntil.abs()} days ago'})',
                    style: TextStyle(fontSize: 13, color: daysUntil < 3 && daysUntil >= 0 ? Colors.orange : (isDark ? Colors.white70 : Colors.black87)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    'Customer: ${entry.customerName}',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey.shade500),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Guests: ${entry.guestCount}',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey.shade500),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    'Total: ${_formatCurrency(entry.totalAmount)}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Advance: ${_formatCurrency(entry.advanceAmount)}',
                    style: TextStyle(fontSize: 12, color: Colors.green),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Pending: ${_formatCurrency(entry.pendingAmount)}',
                    style: TextStyle(fontSize: 12, color: entry.pendingAmount > 0 ? Colors.orange : Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
  }

  String _formatCurrency(double amount) {
    return sl<CurrencyService>().format(amount);
  }
}
