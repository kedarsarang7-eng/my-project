import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:intl/intl.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/session/session_manager.dart';
import '../../../billing/services/settlement_service.dart';

/// Settlement / Patti screen for the Mandi (vegetablesBroker) business type.
///
/// For a selected farmer and inclusive start/end date period, produces a
/// Settlement showing:
/// - Total sales amount
/// - Itemized deductions (commission, labor/hamali, weighing, market fee)
/// - Included lot identifiers
/// - Payment status
///
/// Requirement 11.3.
class SettlementScreen extends StatefulWidget {
  const SettlementScreen({super.key});

  @override
  State<SettlementScreen> createState() => _SettlementScreenState();
}

class _SettlementScreenState extends State<SettlementScreen> {
  final SessionManager _sessionManager = sl<SessionManager>();
  late final SettlementService _settlementService;

  // Farmer selection state.
  List<FarmerEntity> _farmers = [];
  FarmerEntity? _selectedFarmer;

  // Date range state.
  late DateTime _startDate;
  late DateTime _endDate;

  // Settlement result.
  SettlementData? _settlementData;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final db = sl<AppDatabase>();
    _settlementService = SettlementService(db);
    _endDate = DateTime.now();
    _startDate = _endDate.subtract(const Duration(days: 30));
    _loadFarmers();
  }

  Future<void> _loadFarmers() async {
    final userId = _sessionManager.userId ?? '';
    if (userId.isEmpty) return;

    final db = sl<AppDatabase>();
    final farmerList =
        await (db.select(db.farmers)
              ..where((t) => t.userId.equals(userId) & t.isActive.equals(true))
              ..orderBy([(t) => OrderingTerm(expression: t.name)]))
            .get();

    if (!mounted) return;
    setState(() {
      _farmers = farmerList;
    });
  }

  Future<void> _generateSettlement() async {
    if (_selectedFarmer == null) {
      setState(() => _error = 'Please select a farmer');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _settlementData = null;
    });

    try {
      final result = await _settlementService.generateSettlement(
        farmerId: _selectedFarmer!.id,
        startDate: _startDate,
        endDate: _endDate,
      );

      if (!mounted) return;

      if (result == null) {
        setState(() {
          _error = 'Farmer not found';
          _loading = false;
        });
        return;
      }

      setState(() {
        _settlementData = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to generate settlement: $e';
        _loading = false;
      });
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  String _formatDate(DateTime d) => DateFormat('dd MMM yyyy').format(d);

  String _formatPaise(int paise) {
    final rupees = paise / 100.0;
    return '₹${rupees.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settlement / Patti')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Farmer Selection & Date Range ---
            _buildFilterSection(theme, colorScheme),
            const SizedBox(height: 16),

            // --- Generate Button ---
            FilledButton.icon(
              onPressed: _loading ? null : _generateSettlement,
              icon: const Icon(Icons.receipt_long_rounded),
              label: const Text('Generate Settlement'),
            ),
            const SizedBox(height: 16),

            // --- Loading / Error / Result ---
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (_error != null)
              Card(
                color: colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _error!,
                    style: TextStyle(color: colorScheme.onErrorContainer),
                  ),
                ),
              ),
            if (_settlementData != null)
              _buildSettlementResult(theme, colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection(ThemeData theme, ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select Farmer & Period', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),

            // Farmer dropdown.
            DropdownButtonFormField<FarmerEntity>(
              value: _selectedFarmer,
              decoration: const InputDecoration(
                labelText: 'Farmer',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_rounded),
              ),
              items: _farmers.map((farmer) {
                return DropdownMenuItem(
                  value: farmer,
                  child: Text(farmer.name),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedFarmer = value);
              },
              hint: const Text('Select a farmer'),
            ),
            const SizedBox(height: 12),

            // Date range picker.
            InkWell(
              onTap: _pickDateRange,
              borderRadius: BorderRadius.circular(8),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Period',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.date_range_rounded),
                ),
                child: Text(
                  '${_formatDate(_startDate)} — ${_formatDate(_endDate)}',
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettlementResult(ThemeData theme, ColorScheme colorScheme) {
    final data = _settlementData!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Header ---
            Row(
              children: [
                Icon(Icons.receipt_long_rounded, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Settlement Patti',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildPaymentStatusChip(data.paymentStatus, colorScheme),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${data.farmerName} • ${_formatDate(data.periodStart)} to ${_formatDate(data.periodEnd)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const Divider(height: 24),

            // --- Total Sales ---
            _buildLineItem(
              theme,
              label: 'Total Sales',
              value: _formatPaise(data.totalSalesPaise),
              isBold: true,
              icon: Icons.trending_up_rounded,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 16),

            // --- Itemized Deductions ---
            Text(
              'Deductions',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _buildLineItem(
              theme,
              label: 'Commission',
              value: '- ${_formatPaise(data.totalCommissionPaise)}',
              color: colorScheme.error,
            ),
            _buildLineItem(
              theme,
              label: 'Labor / Hamali',
              value:
                  '- ${_formatPaise(data.totalHamaliPaise + data.totalLaborPaise)}',
              color: colorScheme.error,
            ),
            _buildLineItem(
              theme,
              label: '  └ Labor',
              value: '- ${_formatPaise(data.totalLaborPaise)}',
              isSubItem: true,
            ),
            _buildLineItem(
              theme,
              label: '  └ Hamali',
              value: '- ${_formatPaise(data.totalHamaliPaise)}',
              isSubItem: true,
            ),
            _buildLineItem(
              theme,
              label: 'Weighing',
              value: '- ${_formatPaise(data.totalWeighingPaise)}',
              color: colorScheme.error,
            ),
            _buildLineItem(
              theme,
              label: 'Market Fee',
              value: '- ${_formatPaise(data.totalMarketFeePaise)}',
              color: colorScheme.error,
            ),
            const Divider(height: 24),

            // --- Net Payable ---
            _buildLineItem(
              theme,
              label: 'Net Payable',
              value: _formatPaise(data.netPayablePaise),
              isBold: true,
              icon: Icons.account_balance_wallet_rounded,
              color: colorScheme.tertiary,
            ),
            const Divider(height: 24),

            // --- Included Lot Identifiers ---
            Text(
              'Included Lots (${data.includedLotIds.length})',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            if (data.includedLotIds.isEmpty)
              Text(
                'No lots in this period',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: data.includedLotIds.map((id) {
                  return Chip(
                    label: Text(
                      id.length > 12 ? '${id.substring(0, 12)}…' : id,
                      style: theme.textTheme.bodySmall,
                    ),
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineItem(
    ThemeData theme, {
    required String label,
    required String value,
    bool isBold = false,
    bool isSubItem = false,
    IconData? icon,
    Color? color,
  }) {
    final textStyle = isSubItem
        ? theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          )
        : isBold
        ? theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          )
        : theme.textTheme.bodyLarge;

    final valueStyle = isBold
        ? theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          )
        : isSubItem
        ? theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          )
        : theme.textTheme.bodyLarge?.copyWith(color: color);

    return Padding(
      padding: EdgeInsets.only(
        bottom: isSubItem ? 2 : 6,
        left: isSubItem ? 16 : 0,
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
          ],
          Expanded(child: Text(label, style: textStyle)),
          Text(value, style: valueStyle),
        ],
      ),
    );
  }

  Widget _buildPaymentStatusChip(String status, ColorScheme colorScheme) {
    Color chipColor;
    switch (status) {
      case 'PAID':
        chipColor = Colors.green;
        break;
      case 'PARTIAL':
        chipColor = Colors.orange;
        break;
      default: // PENDING
        chipColor = colorScheme.secondary;
    }
    return Chip(
      label: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: chipColor,
        ),
      ),
      side: BorderSide(color: chipColor.withValues(alpha: 0.3)),
      visualDensity: VisualDensity.compact,
    );
  }
}
