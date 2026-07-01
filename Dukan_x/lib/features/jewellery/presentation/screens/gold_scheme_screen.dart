// Gold Scheme / Chit Fund Management Screen
// Feature 4: Complete UI for Gold Scheme Management

import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../data/models/gold_scheme_model.dart';
import '../../data/repositories/gold_scheme_repository.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class GoldSchemeScreen extends StatefulWidget {
  const GoldSchemeScreen({super.key});

  @override
  State<GoldSchemeScreen> createState() => _GoldSchemeScreenState();
}

class _GoldSchemeScreenState extends State<GoldSchemeScreen> {
  final GoldSchemeRepository _repository = GoldSchemeRepository(
    sl(),
    sl<SessionManager>(),
  );

  List<GoldScheme> _schemes = [];
  List<SchemeTemplate> _templates = [];
  GoldSchemeStatistics? _statistics;
  bool _isLoading = true;
  String? _error;
  String _selectedFilter = 'all';

  final List<String> _filters = [
    'all',
    'active',
    'completed',
    'overdue',
    'redeemed',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _repository.initialize();

      List<GoldScheme> schemes;

      switch (_selectedFilter) {
        case 'active':
          schemes = await _repository.getSchemes(status: SchemeStatus.active);
          break;
        case 'completed':
          schemes = await _repository.getSchemes(
            status: SchemeStatus.completed,
          );
          break;
        case 'overdue':
          schemes = await _repository.getOverdueSchemes();
          break;
        case 'redeemed':
          schemes = await _repository.getSchemes(status: SchemeStatus.redeemed);
          break;
        default:
          schemes = await _repository.getSchemes(includeCompleted: true);
      }

      final templates = await _repository.getTemplates();
      final stats = await _repository.getStatistics();

      setState(() {
        _schemes = schemes;
        _templates = templates;
        _statistics = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load schemes: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _createNewScheme() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => CreateGoldSchemeDialog(templates: _templates),
    );

    if (result == true) {
      await _loadData();
    }
  }

  void _showSchemeDetails(GoldScheme scheme) {
    showDialog(
      context: context,
      builder: (context) => GoldSchemeDetailDialog(
        scheme: scheme,
        onRecordPayment: _recordPayment,
        onRedeem: _redeemScheme,
      ),
    );
  }

  Future<void> _recordPayment(GoldScheme scheme, int installmentNumber) async {
    final result = await showDialog<int>(
      context: context,
      builder: (context) => RecordPaymentDialog(
        scheme: scheme,
        installmentNumber: installmentNumber,
      ),
    );

    if (result != null) {
      try {
        await _repository.recordPayment(
          scheme.id,
          installmentNumber,
          paidAmountPaisa: result,
          paymentMode: 'Cash',
        );
        await _loadData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment recorded successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        _showError('Failed to record payment: $e');
      }
    }
  }

  Future<void> _redeemScheme(GoldScheme scheme) async {
    if (!scheme.canRedeem) {
      _showError('Scheme not eligible for redemption yet');
      return;
    }

    final result = await showDialog<RedemptionType>(
      context: context,
      builder: (context) => RedeemSchemeDialog(scheme: scheme),
    );

    if (result != null) {
      try {
        await _repository.redeemScheme(
          RedeemSchemeRequest(schemeId: scheme.id, redemptionType: result),
        );
        await _loadData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Scheme redeemed successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        _showError('Failed to redeem scheme: $e');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      body: BoundedBox(
        maxWidth: 800,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _buildErrorWidget()
            : isDesktop
            ? _buildDesktopLayout()
            : _buildMobileLayout(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewScheme,
        backgroundColor: const Color(0xFFD4AF37),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('NEW SCHEME', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(_error!, style: TextStyle(color: Colors.red[700])),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        SizedBox(
          width: 300,
          child: Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildStatsPanel()),
            ],
          ),
        ),
        Expanded(
          child: Column(
            children: [
              _buildFilterBar(),
              Expanded(
                child: _schemes.isEmpty
                    ? _buildEmptyState()
                    : _buildDataTable(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeader()),
        SliverToBoxAdapter(child: _buildStatsCards()),
        SliverToBoxAdapter(child: _buildFilterBar()),
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            if (index >= _schemes.length) return null;
            return _buildMobileCard(_schemes[index]);
          }, childCount: _schemes.length),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFD4AF37),
            const Color(0xFFD4AF37).withOpacity(0.8),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.savings, color: Colors.white, size: 32),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gold Savings Schemes',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Chit fund & gold accumulation plans',
                        style: TextStyle(fontSize: 14, color: Colors.white70),
                      ),
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

  Widget _buildStatsPanel() {
    if (_statistics == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildStatItem(
            'Total Schemes',
            _statistics!.totalSchemes.toString(),
            Icons.account_balance,
            Colors.blue,
          ),
          _buildStatItem(
            'Active',
            _statistics!.activeSchemes.toString(),
            Icons.trending_up,
            Colors.green,
          ),
          _buildStatItem(
            'Completed',
            _statistics!.completedSchemes.toString(),
            Icons.check_circle,
            Colors.purple,
          ),
          _buildStatItem(
            'Redeemed',
            _statistics!.redeemedSchemes.toString(),
            Icons.redeem,
            Colors.teal,
          ),
          _buildStatItem(
            'Overdue',
            _statistics!.schemesOverdue.toString(),
            Icons.warning,
            Colors.orange,
          ),
          const Divider(height: 32),
          _buildRevenueStat(),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withOpacity(0.3)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(label, style: const TextStyle(fontSize: 13)),
        trailing: Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildRevenueStat() {
    if (_statistics == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFD4AF37).withOpacity(0.2),
            const Color(0xFFD4AF37).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total Collections',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            '₹${_statistics!.displayTotalPaid.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFFD4AF37),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bonus Given: ₹${_statistics!.displayTotalBonus.toStringAsFixed(0)}',
            style: TextStyle(fontSize: 12, color: Colors.green[700]),
          ),
          Text(
            'Outstanding: ₹${_statistics!.displayTotalOutstanding.toStringAsFixed(0)}',
            style: TextStyle(fontSize: 12, color: Colors.orange[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    if (_statistics == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total',
                  _statistics!.totalSchemes.toString(),
                  Icons.account_balance,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Active',
                  _statistics!.activeSchemes.toString(),
                  Icons.trending_up,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Redeemed',
                  _statistics!.redeemedSchemes.toString(),
                  Icons.redeem,
                  Colors.teal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Overdue',
                  _statistics!.schemesOverdue.toString(),
                  Icons.warning,
                  Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _filters.map((filter) {
            final isSelected = _selectedFilter == filter;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(
                  filter.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : Colors.grey[700],
                  ),
                ),
                selected: isSelected,
                onSelected: (_) {
                  setState(() => _selectedFilter = filter);
                  _loadData();
                },
                selectedColor: const Color(0xFFD4AF37),
                backgroundColor: isDark
                    ? const Color(0xFF0F172A)
                    : Colors.grey[100],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDataTable() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 16,
            columns: const [
              DataColumn(label: Text('Scheme #')),
              DataColumn(label: Text('Customer')),
              DataColumn(label: Text('Progress')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Amount')),
              DataColumn(label: Text('Actions')),
            ],
            rows: _schemes.map((scheme) => _buildDataRow(scheme)).toList(),
          ),
        ),
      ),
    );
  }

  DataRow _buildDataRow(GoldScheme scheme) {
    final progress = scheme.progressPercent;
    final isOverdue = scheme.hasOverduePayments;

    return DataRow(
      cells: [
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              scheme.schemeNumber,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
        ),
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                scheme.customerName,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              if (scheme.customerPhone != null)
                Text(
                  scheme.customerPhone!,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
            ],
          ),
        ),
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${scheme.completedInstallments}/${scheme.totalInstallments}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 80,
                child: LinearProgressIndicator(
                  value: progress / 100,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isOverdue ? Colors.red : const Color(0xFFD4AF37),
                  ),
                ),
              ),
            ],
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: scheme.status.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              scheme.status.displayName,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: scheme.status.color,
              ),
            ),
          ),
        ),
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '₹${scheme.displayTotalPaid.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                'of ₹${scheme.displayTotalSchemeValue.toStringAsFixed(0)}',
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.visibility, size: 20),
                onPressed: () => _showSchemeDetails(scheme),
                tooltip: 'View',
              ),
              if (scheme.status == SchemeStatus.active) ...[
                IconButton(
                  icon: const Icon(
                    Icons.payment,
                    size: 20,
                    color: Colors.green,
                  ),
                  onPressed: () {
                    final nextPayment = scheme.nextPaymentDue;
                    if (nextPayment != null) {
                      _recordPayment(scheme, nextPayment.installmentNumber);
                    }
                  },
                  tooltip: 'Record Payment',
                ),
              ],
              if (scheme.canRedeem)
                IconButton(
                  icon: const Icon(
                    Icons.redeem,
                    size: 20,
                    color: Color(0xFFD4AF37),
                  ),
                  onPressed: () => _redeemScheme(scheme),
                  tooltip: 'Redeem',
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileCard(GoldScheme scheme) {
    final isOverdue = scheme.hasOverduePayments;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isOverdue ? Colors.red : Colors.grey[200]!),
      ),
      child: InkWell(
        onTap: () => _showSchemeDetails(scheme),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      scheme.schemeNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.status.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      scheme.status.displayName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: scheme.status.color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                scheme.customerName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (scheme.customerPhone != null)
                Text(
                  scheme.customerPhone!,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Progress',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: scheme.progressPercent / 100,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isOverdue ? Colors.red : const Color(0xFFD4AF37),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${scheme.completedInstallments}/${scheme.totalInstallments} installments',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${scheme.displayTotalPaid.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFD4AF37),
                        ),
                      ),
                      Text(
                        'paid',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
              if (isOverdue) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, size: 16, color: Colors.red),
                      const SizedBox(width: 8),
                      Text(
                        '${scheme.overduePaymentsCount} overdue payments',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No gold schemes yet',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first savings scheme',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _createNewScheme,
            icon: const Icon(Icons.add),
            label: const Text('CREATE SCHEME'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// Placeholder dialogs - would be fully implemented
class CreateGoldSchemeDialog extends StatelessWidget {
  final List<SchemeTemplate> templates;

  const CreateGoldSchemeDialog({super.key, required this.templates});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create New Gold Scheme'),
      content: const Text(
        'Full implementation would include template selection, customer search, installment configuration, etc.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('CREATE'),
        ),
      ],
    );
  }
}

class GoldSchemeDetailDialog extends StatelessWidget {
  final GoldScheme scheme;
  final Function(GoldScheme, int) onRecordPayment;
  final Function(GoldScheme) onRedeem;

  const GoldSchemeDetailDialog({
    super.key,
    required this.scheme,
    required this.onRecordPayment,
    required this.onRedeem,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Scheme #${scheme.schemeNumber}'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Customer: ${scheme.customerName}'),
            Text('Status: ${scheme.status.displayName}'),
            Text(
              'Progress: ${scheme.completedInstallments}/${scheme.totalInstallments}',
            ),
            Text('Total Paid: ₹${scheme.displayTotalPaid.toStringAsFixed(2)}'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CLOSE'),
        ),
      ],
    );
  }
}

class RecordPaymentDialog extends StatelessWidget {
  final GoldScheme scheme;
  final int installmentNumber;

  const RecordPaymentDialog({
    super.key,
    required this.scheme,
    required this.installmentNumber,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Record Payment - Installment #$installmentNumber'),
      content: Text(
        'Amount: ₹${scheme.displayInstallmentAmount.toStringAsFixed(2)}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          onPressed: () =>
              Navigator.pop(context, (scheme.installmentAmountPaisa).round()),
          child: const Text('CONFIRM'),
        ),
      ],
    );
  }
}

class RedeemSchemeDialog extends StatelessWidget {
  final GoldScheme scheme;

  const RedeemSchemeDialog({super.key, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Redeem Gold Scheme'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Total Value: ₹${scheme.displayTotalSchemeValue.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 16),
          ...RedemptionType.values.map(
            (type) => ListTile(
              title: Text(type.displayName),
              onTap: () => Navigator.pop(context, type),
            ),
          ),
        ],
      ),
    );
  }
}
