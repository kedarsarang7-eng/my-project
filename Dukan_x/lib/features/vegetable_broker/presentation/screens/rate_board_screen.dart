import 'package:drift/drift.dart' hide Column, Table;
import 'package:flutter/material.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/responsive/adaptive_widgets.dart';

/// Rate Board Screen — displays per-vegetable min/max/avg rates for a selected
/// date, queried from the `rate_history` table.
///
/// Requirements: 11.4, 11.7
/// - For a selected date, display each vegetable's min, max, and average rate.
/// - If no rate entries exist for the selected date, display "No rates available
///   for this date".
///
/// Rates are stored as integer paise; displayed as rupees (÷ 100).
class RateBoardScreen extends StatefulWidget {
  const RateBoardScreen({super.key});

  @override
  State<RateBoardScreen> createState() => _RateBoardScreenState();
}

class _RateBoardScreenState extends State<RateBoardScreen> {
  late DateTime _selectedDate;
  bool _isLoading = true;
  List<_RateEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _loadRates();
  }

  Future<void> _loadRates() async {
    setState(() => _isLoading = true);

    final db = AppDatabase.instance;
    final sessionManager = sl<SessionManager>();
    final userId = sessionManager.userId ?? '';

    // The rate_date column stores DateTime as integer (seconds since epoch in Drift).
    // We need to match entries whose calendar date equals _selectedDate (ignoring time).
    final startOfDay = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // Drift stores DateTimeColumn as seconds since epoch (integer).
    final startEpoch = startOfDay.millisecondsSinceEpoch ~/ 1000;
    final endEpoch = endOfDay.millisecondsSinceEpoch ~/ 1000;

    try {
      final results = await db
          .customSelect(
            'SELECT vegetable, min_rate, max_rate, avg_rate '
            'FROM rate_history '
            'WHERE user_id = ? AND rate_date >= ? AND rate_date < ? '
            'ORDER BY vegetable ASC',
            variables: [
              Variable.withString(userId),
              Variable.withInt(startEpoch),
              Variable.withInt(endEpoch),
            ],
          )
          .get();

      setState(() {
        _entries = results.map((row) {
          return _RateEntry(
            vegetable: row.read<String>('vegetable'),
            minRate: row.read<int>('min_rate'),
            maxRate: row.read<int>('max_rate'),
            avgRate: row.read<int>('avg_rate'),
          );
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _entries = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final theme = Theme.of(context);
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(colorScheme: theme.colorScheme),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _loadRates();
    }
  }

  String _formatRupees(int paise) {
    final rupees = paise / 100;
    // Show two decimal places for currency
    return '₹${rupees.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rate Board'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRates,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: BoundedBox(
        maxWidth: 900,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Date picker row
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Text('Date:', style: theme.textTheme.titleMedium),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: colorScheme.outline),
                        borderRadius: BorderRadius.circular(8),
                        color: colorScheme.surfaceContainerLow,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatDate(_selectedDate),
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_drop_down,
                            color: colorScheme.onSurface,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _entries.isEmpty
                  ? _buildEmptyState(theme, colorScheme)
                  : _buildRateTable(theme, colorScheme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.show_chart,
            size: 64,
            color: colorScheme.onSurface.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No rates available for this date',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRateTable(ThemeData theme, ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Table(
        border: TableBorder.all(
          color: colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        columnWidths: const {
          0: FlexColumnWidth(2),
          1: FlexColumnWidth(1.5),
          2: FlexColumnWidth(1.5),
          3: FlexColumnWidth(1.5),
        },
        children: [
          // Header row
          TableRow(
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
            ),
            children: [
              _buildHeaderCell('Vegetable', theme, colorScheme),
              _buildHeaderCell('Min Rate', theme, colorScheme),
              _buildHeaderCell('Max Rate', theme, colorScheme),
              _buildHeaderCell('Avg Rate', theme, colorScheme),
            ],
          ),
          // Data rows
          ..._entries.asMap().entries.map((entry) {
            final index = entry.key;
            final rate = entry.value;
            final isEven = index.isEven;
            return TableRow(
              decoration: BoxDecoration(
                color: isEven
                    ? colorScheme.surface
                    : colorScheme.surfaceContainerLow,
              ),
              children: [
                _buildDataCell(rate.vegetable, theme, isBold: true),
                _buildDataCell(_formatRupees(rate.minRate), theme),
                _buildDataCell(_formatRupees(rate.maxRate), theme),
                _buildDataCell(_formatRupees(rate.avgRate), theme),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(
    String text,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }

  Widget _buildDataCell(String text, ThemeData theme, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

/// Internal model for a rate entry row.
class _RateEntry {
  final String vegetable;
  final int minRate;
  final int maxRate;
  final int avgRate;

  const _RateEntry({
    required this.vegetable,
    required this.minRate,
    required this.maxRate,
    required this.avgRate,
  });
}
