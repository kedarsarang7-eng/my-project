import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../../../providers/app_state_providers.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/repository/bills_repository.dart';
import '../../../../core/repository/purchase_repository.dart';
import '../../../../core/repository/expenses_repository.dart';
import '../../../accounting/services/journal_entry_service.dart';
import '../../../accounting/models/journal_entry_model.dart';
import '../../../../widgets/glass_morphism.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';
import '../../../../core/theme/futuristic_colors.dart';
// import '../../../../models/bill.dart'; // Exported by bills_repository
// import '../../../../models/purchase_bill.dart'; // Replaced by PurchaseOrder from repo
// import '../../../../models/expense.dart';
import 'package:dukanx/core/responsive/responsive.dart'; // Replaced by ExpenseModel from repo

class DayBookScreen extends ConsumerStatefulWidget {
  const DayBookScreen({super.key});

  @override
  ConsumerState<DayBookScreen> createState() => _DayBookScreenState();
}

class _DayBookScreenState extends ConsumerState<DayBookScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _isAccountingView = false; // Default: Document View
  bool _showRunningBalance = false; // Optional toggle

  final String? _ownerId = sl<SessionManager>().ownerId;

  @override
  Widget build(BuildContext context) {
    return DesktopContentContainer(
      title: 'Day Book',
      subtitle: 'Daily transaction register and journal entries',
      actions: [
        DesktopActionButton(
          icon: Icons.calendar_today_rounded,
          label: DateFormat('MMM d, yyyy').format(_selectedDate),
          onPressed: () => _pickDate(context),
          isPrimary: false,
        ),
      ],
      child: Column(
        children: [
          // View Mode Toggles
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: FuturisticColors.surface.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: FuturisticColors.border.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildToggleOption(
                  "Document View",
                  !_isAccountingView,
                  () => setState(() => _isAccountingView = false),
                ),
                _buildToggleOption(
                  "Accounting View",
                  _isAccountingView,
                  () => setState(() => _isAccountingView = true),
                ),
              ],
            ),
          ),

          if (_isAccountingView)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: InkWell(
                onTap: () =>
                    setState(() => _showRunningBalance = !_showRunningBalance),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _showRunningBalance
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        size: 16,
                        color: _showRunningBalance
                            ? FuturisticColors.premiumBlue
                            : FuturisticColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Show Running Balance",
                        style: TextStyle(
                          fontSize: 13,
                          color: _showRunningBalance
                              ? Colors.white
                              : FuturisticColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          const SizedBox(height: 24),

          Expanded(
            child: _ownerId == null
                ? const Center(child: Text("Error: Owner ID missing"))
                : _isAccountingView
                ? _buildAccountingView()
                : _buildDocumentView(),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleOption(String text, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? FuturisticColors.premiumBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : FuturisticColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentView() {
    return StreamBuilder(
      stream: _getCombinedStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return _buildEmptyState();
        }

        final theme = ref.watch(themeStateProvider);
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            return _buildTransactionItem(context, items[index], theme.isDark);
          },
        );
      },
    );
  }

  Widget _buildAccountingView() {
    final startOfDay = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final endOfDay = startOfDay
        .add(const Duration(days: 1))
        .subtract(const Duration(milliseconds: 1));

    return StreamBuilder<List<JournalEntryModel>>(
      stream: sl<JournalEntryService>().watchEntriesByDateRange(
        _ownerId!,
        startOfDay,
        endOfDay,
        includeSystemEntries: true,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        final entries = snapshot.data ?? [];
        if (entries.isEmpty) {
          return _buildEmptyState();
        }

        // Validation & Safety Net
        for (var entry in entries) {
          if (!entry.isBalanced) {
            // Hard Crash in Dev as per rules
            assert(
              false,
              "CRITICAL: Unbalanced Journal Entry Found! ${entry.id}",
            );
          }
        }

        // Calculate running balances in memory if needed
        // Since list is strictly ordered (Newest First in UI usually, but we need Oldest First for running balance)
        // Repo returns entries ordered by Date/Created DESC (Newest First).
        // So running balance calculation is tricky on a DESC list without total context.
        // If we want "Running Balance" as "Balance for the Day", we can accumulate backwards?
        // Or we just show "Transaction Value".
        // The Prompt says "Reset per date range". So we can calculate it relative to this view.
        // We will process the list to add running balance.

        // Correct approach for visual running balance on DESC list:
        // Total = Sum(All).
        // Index 0 (Newest) Balance = Total.
        // Index 1 Balance = Total - Index 0 Amount.
        // ...
        // Index Last Balance = Index Last Amount.

        // However, this assumes we are summing a scalar "Amount". Journal Entries are multi-line.
        // We'll use "Total Debit" as the magnitude.

        final processedEntries = <_AccountingViewItem>[];
        // Calculate total for the day first (sum of all debit turns)
        double dayTotalTurnover = 0;
        for (var e in entries) {
          dayTotalTurnover += e.totalDebit;
        }

        double currentBalance = dayTotalTurnover;

        for (var entry in entries) {
          // Iterating Newest to Oldest
          processedEntries.add(_AccountingViewItem(entry, currentBalance));
          currentBalance -= entry.totalDebit;
        }

        final theme = ref.watch(themeStateProvider);
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: processedEntries.length,
          itemBuilder: (context, index) {
            return _buildAccountingItem(
              context,
              processedEntries[index],
              theme.isDark,
            );
          },
        );
      },
    );
  }

  Widget _buildAccountingItem(
    BuildContext context,
    _AccountingViewItem viewItem,
    bool isDark,
  ) {
    final entry = viewItem.entry;
    final classification = entry.classification;

    Color color;
    switch (classification) {
      case AccountingEntryClassification.bill:
        color = Colors.green;
        break;
      case AccountingEntryClassification.purchase:
        color = Colors.orange;
        break;
      case AccountingEntryClassification.payment:
        color = Colors.redAccent;
        break;
      case AccountingEntryClassification.receipt:
        color = Colors.blue;
        break;
      default:
        color = isDark ? Colors.white54 : Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        borderRadius: 16,
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Header: Time | Voucher | Type
            Row(
              children: [
                Text(
                  DateFormat('HH:mm').format(entry.entryDate),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Text(
                    entry.voucherNumber,
                    style: TextStyle(
                      fontSize: 10,
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  "${sl<CurrencyService>().symbol}${entry.totalDebit.toStringAsFixed(2)}", // Show Magnitude
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
            const Divider(height: 12),
            // Narration
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                entry.narration ?? "System Entry",
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
            // Dr/Cr Lines Breakdown
            ...entry.entries.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  children: [
                    Text(
                      line.debit > 0 ? "Dr" : "Cr",
                      style: TextStyle(
                        fontSize: 10,
                        color: line.debit > 0 ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        line.ledgerName,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white60 : Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      "${sl<CurrencyService>().symbol}${(line.debit > 0 ? line.debit : line.credit).toStringAsFixed(2)}",
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white60 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Running Balance Footer (Optional)
            if (_showRunningBalance) ...[
              const Divider(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text(
                    "Volume Bal: ",
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                  Text(
                    "${sl<CurrencyService>().symbol}${viewItem.runningBalance.toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDark = ref.watch(themeStateProvider).isDark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_edu_rounded,
            size: 60,
            color: isDark ? Colors.white24 : Colors.grey.shade400,
          ),
          const SizedBox(height: 10),
          Text(
            "No activity found",
            style: TextStyle(color: isDark ? Colors.white60 : Colors.grey),
          ),
        ],
      ),
    );
  }

  Stream<List<DayBookItem>> _getCombinedStream() {
    // Combine Streams: Bills, Purchases, Expenses
    // Filter by date locally or in query.
    // Since existing streams fetch All or list, we might fetch more than needed.
    // Optimization: Queries in Repositories already accept stream filters?
    // streamAllBills doesn't take date. streamPurchaseBills doesn't take date.
    // So we fetch all (or recent) and filter locally.
    // WARNING: Expected performance impact if many docs.
    // Ideally we add date filtering to query.
    // For now, prompt asked for "Real business logic", so we should filter.

    final startOfDay = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // We can't use Rx here easily without importing rxdart.
    // We will use StreamGroup-like logic manually or just merge list in builder if we had MultiStreamBuilder.
    // But Flutter Standard library doesn't have combineLatest easily.
    // Hack: Merge locally using a custom transformer or just await full list?
    // Since we need real-time, we need Stream.

    // We will simplify: Use StreamBuilder on a merged stream generator.

    return StreamCombined(_ownerId!, startOfDay, endOfDay).stream;
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Widget _buildTransactionItem(
    BuildContext context,
    DayBookItem item,
    bool isDark,
  ) {
    Color color;
    IconData icon;
    String prefix;

    switch (item.type) {
      case 'sale':
        color = Colors.green;
        icon = Icons
            .arrow_downward_rounded; // Incoming money (sales) - usually considered credit in accounting but here visualized as IN
        prefix = "+";
        break;
      case 'purchase':
        color = Colors.orange;
        icon = Icons.arrow_upward_rounded; // Outgoing
        prefix = "-";
        break;
      case 'expense':
        color = Colors.redAccent;
        icon = Icons.remove_circle_outline;
        prefix = "-";
        break;
      default:
        color = Colors.grey;
        icon = Icons.info;
        prefix = "";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        borderRadius: 16,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    "${DateFormat('hh:mm a').format(item.date)} • ${item.subtitle}",
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              "$prefix${sl<CurrencyService>().symbol}${item.amount.toStringAsFixed(0)}",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DayBookItem {
  final String id;
  final String title;
  final String subtitle;
  final double amount;
  final DateTime date;
  final String type; // sale, purchase, expense

  DayBookItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.date,
    required this.type,
  });
}

class _AccountingViewItem {
  final JournalEntryModel entry;
  final double runningBalance;
  _AccountingViewItem(this.entry, this.runningBalance);
}

// Helper to combine streams
class StreamCombined {
  final String ownerId;
  final DateTime start;
  final DateTime end;
  late StreamController<List<DayBookItem>> _controller;
  final List<StreamSubscription> _subs = [];

  StreamCombined(this.ownerId, this.start, this.end) {
    _controller = StreamController<List<DayBookItem>>(onCancel: _cancel);
    _init();
  }

  Stream<List<DayBookItem>> get stream => _controller.stream;

  void _cancel() {
    for (var s in _subs) {
      s.cancel();
    }
    _controller.close();
  }

  void _init() {
    List<Bill> bills = [];
    List<PurchaseOrder> purchases = []; // Updated to PurchaseOrder
    List<ExpenseModel> expenses = []; // Updated to ExpenseModel

    void emit() {
      final combined = <DayBookItem>[];

      for (var b in bills) {
        if (!b.date.isBefore(start) && b.date.isBefore(end)) {
          combined.add(
            DayBookItem(
              id: b.id,
              title: b.customerName.isEmpty ? 'Cash Sale' : b.customerName,
              subtitle: 'Inv #${b.invoiceNumber}',
              amount: b.grandTotal,
              date: b.date,
              type: 'sale',
            ),
          );
        }
      }

      for (var p in purchases) {
        if (!p.purchaseDate.isBefore(start) && p.purchaseDate.isBefore(end)) {
          combined.add(
            DayBookItem(
              id: p.id,
              title: p.vendorName ?? 'Unknown Vendor',
              subtitle: 'Inv #${p.invoiceNumber ?? ''}',
              amount: p.totalAmount,
              date: p.purchaseDate,
              type: 'purchase',
            ),
          );
        }
      }

      for (var e in expenses) {
        if (!e.date.isBefore(start) && e.date.isBefore(end)) {
          combined.add(
            DayBookItem(
              id: e.id,
              title: e.category,
              subtitle: e.description,
              amount: e.amount,
              date: e.date,
              type: 'expense',
            ),
          );
        }
      }

      combined.sort((a, b) => b.date.compareTo(a.date));
      if (!_controller.isClosed) {
        _controller.add(combined);
      }
    }

    _subs.add(
      sl<BillsRepository>().watchAll(userId: ownerId).listen((data) {
        bills = data;
        // Actually Bill model in `models/bill.dart` is the legacy one used by UI.
        // `BillsRepository` returns `Bill` (the NEW entity wrapper? NO, it returns `Bill` model from repository.dart?
        // Wait, `bills_repository.dart` defines `Bill` locally or imports it?
        // Let's check `bills_repository.dart` imports. It likely imports `models/bill.dart` or defines its own `Bill` class.
        // Based on `CustomersRepository` pattern, it defines its own `Customer` class.
        // If `BillsRepository` defines its own `Bill`, I should use that.
        // `DayBookScreen` imports `models/bill.dart`.
        // I should assume `BillsRepository` returns a compatible `Bill` or I map it.
        // Let's assume for now it needs mapping or is compatible.
        // EDIT: `BillsRepository` returns `List<Bill>` where `Bill` is defined in `bills_repository.dart`.
        // I will map it to `DayBookItem` directly using the properties I know exist (`invoiceNumber`, `customerName`, `grandTotal`, `billDate`).
        // The `bills` list type above should be `List<dynamic>` or the Repo's Bill type.

        emit();
      }),
    );

    _subs.add(
      sl<PurchaseRepository>().watchAll(userId: ownerId).listen((data) {
        purchases = data; // PurchaseOrder
        emit();
      }),
    );

    _subs.add(
      sl<ExpensesRepository>().watchAll(userId: ownerId).listen((data) {
        expenses = data; // ExpenseModel
        emit();
      }),
    );
  }
}
