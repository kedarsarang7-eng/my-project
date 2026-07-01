import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/di/service_locator.dart';
import '../../../../core/services/currency_service.dart';
import '../../../core/session/session_manager.dart';
import '../services/financial_reports_service.dart';
import '../accounting.dart' as acc;
import '../../../widgets/desktop/enterprise_table.dart';
import '../../../widgets/desktop/desktop_content_container.dart';
import '../../../core/theme/futuristic_colors.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class AccountingReportsScreen extends StatefulWidget {
  const AccountingReportsScreen({super.key});

  @override
  State<AccountingReportsScreen> createState() =>
      _AccountingReportsScreenState();
}

class _AccountingReportsScreenState extends State<AccountingReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FinancialReportsService _service = FinancialReportsService();

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  // Report Data
  TrialBalanceReport? _trialBalance;
  ProfitLossReport? _profitLoss;
  BalanceSheetReport? _balanceSheet;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadCurrentReport();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) return;
    _loadCurrentReport();
  }

  Future<void> _loadCurrentReport() async {
    setState(() => _isLoading = true);
    try {
      final session = sl<SessionManager>();
      final userId = session.ownerId;
      if (userId == null) return;
      // Scope reports to the active business so a user owning multiple
      // businesses never sees cross-business aggregates. Falls back to the
      // user id when no separate business is active (single-tenant case).
      final businessId = session.currentBusinessId;

      switch (_tabController.index) {
        case 0: // Trial Balance
          final report = await _service.generateTrialBalance(
            userId: userId,
            asOfDate: _endDate,
            businessId: businessId,
          );
          setState(() => _trialBalance = report);
          break;
        case 1: // P&L
          final report = await _service.generateProfitLoss(
            userId: userId,
            startDate: _startDate,
            endDate: _endDate,
            businessId: businessId,
          );
          setState(() => _profitLoss = report);
          break;
        case 2: // Balance Sheet
          final report = await _service.generateBalanceSheet(
            userId: userId,
            asOfDate: _endDate,
            businessId: businessId,
          );
          setState(() => _balanceSheet = report);
          break;
      }
    } catch (e) {
      debugPrint('Error loading report: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: DesktopContentContainer(
          title: 'Financial Reports',
          subtitle: 'Balance Sheet, P&L, and Trial Balance',
          actions: [
            DesktopIconButton(
              icon: Icons.calendar_today,
              onPressed: _pickDateRange,
              tooltip: 'Filter Date',
            ),
            DesktopIconButton(
              icon: Icons.lock_clock,
              onPressed: _showLockDialog,
              tooltip: 'Lock Books',
            ),
          ],
          child: Column(
            children: [
              // Custom Tab Bar
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: FuturisticColors.surface.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: FuturisticColors.border.withOpacity(0.3),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: FuturisticColors.premiumBlue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: FuturisticColors.textSecondary,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  tabs: const [
                    Tab(text: 'Trial Balance'),
                    Tab(text: 'Profit & Loss'),
                    Tab(text: 'Balance Sheet'),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: FuturisticColors.premiumBlue,
                        ),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildTrialBalanceView(),
                          _buildProfitLossView(),
                          _buildBalanceSheetView(),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrialBalanceView() {
    if (_trialBalance == null) return const Center(child: Text("No Data"));

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader('Trial Balance', 'As of ${_formatDate(_endDate)}'),
          const SizedBox(height: 24),
          Expanded(
            child: EnterpriseTable<TrialBalanceItem>(
              columns: [
                EnterpriseTableColumn(
                  title: "Ledger Account",
                  valueBuilder: (item) => item.ledgerName,
                  widgetBuilder: (item) => Text(
                    item.ledgerName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                EnterpriseTableColumn(
                  title: "Debit",
                  isNumeric: true,
                  valueBuilder: (item) => item.debit,
                  widgetBuilder: (item) => Text(
                    _formatCurrency(item.debit),
                    style: const TextStyle(color: FuturisticColors.textPrimary),
                  ),
                ),
                EnterpriseTableColumn(
                  title: "Credit",
                  isNumeric: true,
                  valueBuilder: (item) => item.credit,
                  widgetBuilder: (item) => Text(
                    _formatCurrency(item.credit),
                    style: const TextStyle(color: FuturisticColors.textPrimary),
                  ),
                ),
              ],
              data: _trialBalance!.items,
            ),
          ),
          const SizedBox(height: 16),
          _buildTotalRow(
            'Total',
            _trialBalance!.totalDebit,
            _trialBalance!.totalCredit,
            isBalanced: _trialBalance!.isBalanced,
          ),
        ],
      ),
    );
  }

  Widget _buildProfitLossView() {
    if (_profitLoss == null) return const SizedBox();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(
            'Profit & Loss',
            '${_formatDate(_startDate)} to ${_formatDate(_endDate)}',
          ),
          const SizedBox(height: 16),
          _buildSectionTitle('Income'),
          ..._profitLoss!.incomeItems.map(
            (item) => _buildRow(item.ledgerName, item.amount, isIncome: true),
          ),
          const Divider(),
          _buildRow('Total Income', _profitLoss!.totalIncome, isBold: true),
          const SizedBox(height: 24),
          _buildSectionTitle('Expenses'),
          ..._profitLoss!.expenseItems.map(
            (item) => _buildRow(item.ledgerName, item.amount, isIncome: false),
          ),
          const Divider(),
          _buildRow('Total Expenses', _profitLoss!.totalExpenses, isBold: true),
          const SizedBox(height: 24),
          Card(
            color: _profitLoss!.isProfitable
                ? Colors.green.shade50
                : Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _profitLoss!.isProfitable ? 'NET PROFIT' : 'NET LOSS',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _formatCurrency(_profitLoss!.netProfit.abs()),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _profitLoss!.isProfitable
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceSheetView() {
    if (_balanceSheet == null) return const SizedBox();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader('Balance Sheet', 'As of ${_formatDate(_endDate)}'),
          const SizedBox(height: 16),
          _buildSectionTitle('Assets'),
          ..._balanceSheet!.assetItems.map(
            (item) => _buildRow(item.ledgerName, item.amount),
          ),
          const Divider(),
          _buildRow('Total Assets', _balanceSheet!.totalAssets, isBold: true),
          const SizedBox(height: 24),
          _buildSectionTitle('Liabilities'),
          ..._balanceSheet!.liabilityItems.map(
            (item) => _buildRow(item.ledgerName, item.amount),
          ),
          const Divider(),
          _buildRow(
            'Total Liabilities',
            _balanceSheet!.totalLiabilities,
            isBold: true,
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Equity'),
          ..._balanceSheet!.equityItems.map(
            (item) => _buildRow(item.ledgerName, item.amount),
          ),
          const Divider(),
          _buildRow('Total Equity', _balanceSheet!.totalEquity, isBold: true),
          const SizedBox(height: 24),
          Card(
            color: _balanceSheet!.isBalanced
                ? Colors.green.shade50
                : Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Balance Check',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  if (_balanceSheet!.isBalanced)
                    const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          "Balanced",
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        const Icon(Icons.error, color: Colors.red),
                        const SizedBox(width: 8),
                        Text(
                          "Diff: ${_formatCurrency(_balanceSheet!.totalAssets - _balanceSheet!.liabilitiesAndEquity)}",
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: responsiveValue<double>(
              context,
              mobile: 18,
              tablet: 20,
              desktop: 24,
            ),
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(subtitle, style: TextStyle(color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.grey[700],
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildRow(
    String label,
    double amount, {
    bool isBold = false,
    bool? isIncome,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            _formatCurrency(amount),
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: isIncome != null
                  ? (isIncome ? Colors.green : Colors.red)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(
    String label,
    double debit,
    double credit, {
    required bool isBalanced,
  }) {
    return Card(
      color: isBalanced ? Colors.green.shade50 : Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: Text(
                _formatCurrency(debit),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: Text(
                _formatCurrency(credit),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ... existing methods ...

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
      _loadCurrentReport();
    }
  }

  Future<void> _showLockDialog() async {
    final userId = sl<SessionManager>().ownerId;
    if (userId == null) return;

    final lockingService = sl<acc.LockingService>();
    final currentLock = await lockingService.getLockDate(userId);

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lock Books'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Prevent editing of financial records on or before a specific date.',
            ),
            const SizedBox(height: 16),
            if (currentLock != null)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock, size: 16, color: Colors.amber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Currently locked up to: ${_formatDate(currentLock)}',
                        style: TextStyle(
                          color: Colors.amber.shade900,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              const Text(
                'Books are currently unlocked.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            const SizedBox(height: 16),
            const Text('Select new lock date:'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.lock_outline),
            label: const Text('SET LOCK DATE'),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: currentLock ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );

              if (picked != null) {
                await lockingService.setLockDate(userId, picked);
                if (context.mounted) Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Books locked up to ${_formatDate(picked)}'),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) => DateFormat('dd MMM yyyy').format(d);
  String _formatCurrency(double d) => NumberFormat.currency(
    locale: 'en_IN',
    symbol: sl<CurrencyService>().symbol,
  ).format(d);
}
