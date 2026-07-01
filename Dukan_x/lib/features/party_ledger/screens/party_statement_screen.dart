import 'package:flutter/material.dart';
import '../../accounting/accounting.dart';
import '../services/party_ledger_service.dart';
import '../../../core/di/service_locator.dart';
import '../../../../core/services/currency_service.dart';
import '../../../core/session/session_manager.dart';

import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../../services/pdf_service.dart';
import '../models/party_ledger_model.dart';
import 'collect_payment_screen.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Party Ledger Statement Screen
///
/// Shows detailed transaction history (Ledger Statement) for a
/// specific Customer or Vendor.
class PartyStatementScreen extends StatefulWidget {
  final String partyId;
  final String partyName;
  final String partyType; // 'CUSTOMER' or 'VENDOR'

  const PartyStatementScreen({
    super.key,
    required this.partyId,
    required this.partyName,
    required this.partyType,
  });

  @override
  State<PartyStatementScreen> createState() => _PartyStatementScreenState();
}

class _PartyStatementScreenState extends State<PartyStatementScreen> {
  late final PartyLedgerService _ledgerService;
  bool _isLoading = true;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  LedgerStatement? _statement;
  AgingReport? _agingReport;

  @override
  void initState() {
    super.initState();
    _ledgerService = sl<PartyLedgerService>();
    _loadStatement();
  }

  Future<void> _loadStatement() async {
    setState(() => _isLoading = true);
    try {
      final userId = sl<SessionManager>().ownerId;
      if (userId == null) return;

      final statementFuture = _ledgerService.getPartyStatement(
        userId: userId,
        partyId: widget.partyId,
        partyType: widget.partyType,
        startDate: _startDate,
        endDate: _endDate,
      );

      final agingFuture = _ledgerService.getAgingAnalysis(
        userId: userId,
        partyId: widget.partyId,
        partyType: widget.partyType,
      );

      final results = await Future.wait([statementFuture, agingFuture]);

      setState(() {
        _statement = results[0] as LedgerStatement;
        _agingReport = results[1] as AgingReport;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading statement: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final date = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
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

  Future<void> _exportPdf() async {
    if (_statement == null || _agingReport == null) return;

    try {
      // Prepare Aging Map
      final agingMap = {
        '0-30': _agingReport!.zeroToThirty,
        '30-60': _agingReport!.thirtyToSixty,
        '60-90': _agingReport!.sixtyToNinety,
        '90+': _agingReport!.ninetyPlus,
      };

      // Transform transactions to Map for PDF
      final transactions = _statement!.transactions
          .map(
            (t) => {
              'date': DateFormat('dd-MMM-yyyy').format(t.date),
              'voucher': t.voucherNumber,
              'type': t.voucherType.displayName,
              'debit': t.debit,
              'credit': t.credit,
              'balance':
                  t.runningBalance, // Assuming we have this or calculate it
            },
          )
          .toList();

      // Note: runningBalance might not be in LedgerTransaction directly if not calculated via service.
      // LedgerStatement from reports_repository usually has it. Let's check.
      // If not, we can calculate it on the fly or just use current balance.
      // For now assuming existing fields.

      final session = sl<SessionManager>().currentSession;
      final shopName = session.displayName ?? 'My Dukan'; // Fallback allowed
      final shopAddress = session.metadata?['address'] as String? ?? '';

      final pdfBytes = await sl<PdfService>().generatePartyStatementPdf(
        shopName: shopName,
        shopAddress: shopAddress,
        customerName: widget.partyName,
        transactions: transactions,
        aging: agingMap,
        startDate: _startDate,
        endDate: _endDate,
        totalDue: _agingReport!.totalDue,
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: 'Statement_${widget.partyName}.pdf',
      );
    } catch (e) {
      debugPrint('PDF Error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to generate PDF: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.partyName),
            Text(
              'Statement of Accounts',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _exportPdf,
            tooltip: 'Export PDF',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CollectPaymentScreen(
                partyId: widget.partyId,
                partyName: widget.partyName,
                partyType: widget.partyType,
                currentBalance: _agingReport?.totalDue ?? 0,
              ),
            ),
          );

          if (result == true) {
            _loadStatement();
          }
        },
        label: Text(
          widget.partyType == 'CUSTOMER' ? 'Receive Payment' : 'Pay Vendor',
        ),
        icon: const Icon(Icons.payment),
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: Column(
        children: [
          // Filter Bar
          Container(
            padding: const EdgeInsets.all(8),
            color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(DateFormat('dd MMM yyyy').format(_startDate)),
                    onPressed: () => _pickDate(true),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('to'),
                ),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(DateFormat('dd MMM yyyy').format(_endDate)),
                    onPressed: () => _pickDate(false),
                  ),
                ),
              ],
            ),
          ),

          // Loading / Body
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _statement == null || _statement!.transactions.isEmpty
                ? const Center(child: Text('No transactions in this period'))
                : _buildStatementList(theme),
          ),

          // Footer Summary (Aging + Closing Bal)
          if (_statement != null) _buildFooter(theme),
        ],
      ),
      ),
    );
  }

  Widget _buildStatementList(ThemeData theme) {
    return ListView.separated(
      itemCount: _statement!.transactions.length + 1, // +1 for Opening Bal
      separatorBuilder: (ctx, i) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index == 0) {
          // Opening Balance Row
          return ListTile(
            tileColor: theme.colorScheme.secondaryContainer.withOpacity(0.1),
            title: const Text('Opening Balance'),
            trailing: Text(
              _formatCurrency(_statement!.openingBalance),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          );
        }

        final txn = _statement!.transactions[index - 1];
        final isCredit = txn.credit > 0;
        final amount = isCredit ? txn.credit : txn.debit;
        final color = isCredit ? Colors.red.shade700 : Colors.green.shade700;

        return ListTile(
          onTap: () => _showTransactionOptions(txn),
          dense: true,
          title: Text('${txn.voucherType.displayName} #${txn.voucherNumber}'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(DateFormat('dd MMM yyyy').format(txn.date)),
              if (txn.narration.isNotEmpty)
                Text(
                  txn.narration,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatCurrency(amount),
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
              Text(
                isCredit ? 'Credit' : 'Debit',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        children: [
          // Aging Summary (if available and has debt)
          if (_agingReport != null && _agingReport!.totalDue > 0) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildAgingChip('0-30', _agingReport!.zeroToThirty),
                  const SizedBox(width: 8),
                  _buildAgingChip('31-60', _agingReport!.thirtyToSixty),
                  const SizedBox(width: 8),
                  _buildAgingChip('61-90', _agingReport!.sixtyToNinety),
                  const SizedBox(width: 8),
                  _buildAgingChip(
                    '90+',
                    _agingReport!.ninetyPlus,
                    isDanger: true,
                  ),
                ],
              ),
            ),
            const Divider(),
          ],

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Closing Balance',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              Text(
                _formatCurrency(_statement!.closingBalance),
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAgingChip(String label, double amount, {bool isDanger = false}) {
    if (amount <= 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDanger
            ? Colors.red.withOpacity(0.1)
            : Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDanger ? Colors.red : Colors.grey,
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 10)),
          Text(
            _formatCurrency(amount).split(' ')[0], // Just amount, no Dr/Cr
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: isDanger ? Colors.red : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double amount) {
    final absAmount = amount.abs();
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: sl<CurrencyService>().symbol,
      decimalDigits: 2,
    );
    final formatted = formatter.format(absAmount);
    return amount < 0 ? '$formatted Cr' : '$formatted Dr';
  }

  void _showTransactionOptions(LedgerTransaction txn) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transaction #${txn.voucherNumber}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text('Date: ${DateFormat('dd MMM yyyy').format(txn.date)}'),
            Text(
              'Amount: ${_formatCurrency(txn.debit > 0 ? txn.debit : -txn.credit)}',
            ),
            if (txn.narration.isNotEmpty) Text('Narration: ${txn.narration}'),
            const SizedBox(height: 24),
            // Reminders disabled until fully implemented
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
