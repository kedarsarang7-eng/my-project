import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../../core/theme/futuristic_colors.dart';
import '../../models/pharmacy_dashboard_models.dart';
import '../../providers/pharmacy_dashboard_providers.dart';

class PharmacyDateRangeFilter extends ConsumerWidget {
  const PharmacyDateRangeFilter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(dateRangeFilterProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Filter Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: FuturisticColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.date_range_rounded,
              color: FuturisticColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // Filter Label
          Text(
            'Date Range:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: FuturisticColors.textSecondary,
            ),
          ),
          const SizedBox(width: 16),

          // Date Range Options
          Expanded(
            child: Row(
              children: DateRangeFilter.values.map((range) {
                final isSelected = filters.dateRange == range;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: _DateRangeButton(
                    label: range.displayName,
                    isSelected: isSelected,
                    onTap: () => _selectDateRange(ref, range),
                  ),
                );
              }).toList(),
            ),
          ),

          // Custom Date Range (if selected)
          if (filters.dateRange == DateRangeFilter.custom) ...[
            const SizedBox(width: 16),
            _CustomDateRangeButton(
              startDate: filters.customStartDate,
              endDate: filters.customEndDate,
              onDateRangeSelected: (start, end) {
                ref.read(dateRangeFilterProvider.notifier).update(
                  filters.copyWith(
                    dateRange: DateRangeFilter.custom,
                    customStartDate: start,
                    customEndDate: end,
                  ),
                );
                // Trigger refresh with new date range
                ref.read(pharmacyDashboardProvider.notifier).loadDashboardData();
              },
            ),
          ],

          // Refresh Button
          const SizedBox(width: 16),
          IconButton(
            onPressed: () {
              ref.read(pharmacyDashboardProvider.notifier).refreshAll();
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Dashboard',
            style: IconButton.styleFrom(
              backgroundColor: FuturisticColors.primary.withValues(alpha: 0.1),
              foregroundColor: FuturisticColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  void _selectDateRange(WidgetRef ref, DateRangeFilter range) {
    final current = ref.read(dateRangeFilterProvider);
    ref.read(dateRangeFilterProvider.notifier).update(
      current.copyWith(
        dateRange: range,
        customStartDate: null,
        customEndDate: null,
      ),
    );
  }
}
// ── Date Range Button Widget ─────────────────────────────────────────────────────

class _DateRangeButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _DateRangeButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? FuturisticColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? FuturisticColors.primary
                : FuturisticColors.textSecondary.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : FuturisticColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ── Custom Date Range Button Widget ─────────────────────────────────────────────

class _CustomDateRangeButton extends StatefulWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final Function(DateTime start, DateTime end) onDateRangeSelected;

  const _CustomDateRangeButton({
    required this.startDate,
    required this.endDate,
    required this.onDateRangeSelected,
  });

  @override
  State<_CustomDateRangeButton> createState() => _CustomDateRangeButtonState();
}

class _CustomDateRangeButtonState extends State<_CustomDateRangeButton> {
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    _startDate =
        widget.startDate ?? DateTime.now().subtract(const Duration(days: 30));
    _endDate = widget.endDate ?? DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _showDateRangePicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: FuturisticColors.info.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: FuturisticColors.info.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 14,
              color: FuturisticColors.info,
            ),
            const SizedBox(width: 6),
            Text(
              _formatDateRange(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: FuturisticColors.info,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateRange() {
    final startFormat =
        '${_startDate.day}/${_startDate.month}/${_startDate.year}';
    final endFormat = '${_endDate.day}/${_endDate.month}/${_endDate.year}';
    return '$startFormat - $endFormat';
  }

  Future<void> _showDateRangePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: FuturisticColors.primary),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });

      widget.onDateRangeSelected(_startDate, _endDate);
    }
  }
}
