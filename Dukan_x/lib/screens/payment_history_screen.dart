import 'package:flutter/material.dart';
import 'package:dukanx/core/responsive/responsive_layout.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/di/service_locator.dart';
import '../core/repository/bills_repository.dart';
import '../core/session/session_manager.dart';
import '../providers/app_state_providers.dart';

class PaymentHistoryScreen extends ConsumerStatefulWidget {
  final String? customerId;
  final String? customerName;

  const PaymentHistoryScreen({super.key, this.customerId, this.customerName});

  @override
  ConsumerState<PaymentHistoryScreen> createState() =>
      _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends ConsumerState<PaymentHistoryScreen> {
  List<Bill> _bills = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBills();
  }

  Future<void> _loadBills() async {
    try {
      final ownerId = sl<SessionManager>().ownerId ?? '';
      final billsResult = await sl<BillsRepository>().getAll(
        userId: ownerId,
        customerId: widget.customerId,
      );

      // Bills are already filtered by customerId in repository call
      setState(() {
        _bills = billsResult.data ?? [];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading payment history: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeStateProvider);
    final palette = theme.palette;
    final isDark = theme.isDark;
    final isMobile = context.isMobile;

    // Calculate summary
    double totalBilled = 0;
    double totalPaid = 0;
    double totalOnlinePaid = 0;
    double totalCashPaid = 0;

    for (final bill in _bills) {
      totalBilled += bill.subtotal;
      totalPaid += bill.paidAmount;
      totalOnlinePaid += bill.onlinePaid;
      totalCashPaid += bill.cashPaid;
    }

    final totalPending = totalBilled - totalPaid;

    final summarySection = Container(
      padding: const EdgeInsets.all(16),
      color: isDark
          ? palette.royalBlue.withOpacity(0.1)
          : palette.royalBlue.withOpacity(0.05),
      child: Column(
        children: [
          // Summary Title
          Text(
            'Payment Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : palette.mutedGray,
            ),
          ),
          const SizedBox(height: 16),

          // Summary Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _buildSummaryCard(
                title: 'Total Billed',
                amount: totalBilled,
                color: palette.sunYellow,
                palette: palette,
                isDark: isDark,
              ),
              _buildSummaryCard(
                title: 'Total Paid',
                amount: totalPaid,
                color: palette.leafGreen,
                palette: palette,
                isDark: isDark,
              ),
              _buildSummaryCard(
                title: 'Cash Paid',
                amount: totalCashPaid,
                color: palette.royalBlue,
                palette: palette,
                isDark: isDark,
              ),
              _buildSummaryCard(
                title: 'Online Paid',
                amount: totalOnlinePaid,
                color: Colors.purple,
                palette: palette,
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Pending Amount
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.tomatoRed.withOpacity(0.1),
              border: Border.all(
                color: palette.tomatoRed.withOpacity(0.3),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pending Amount',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: palette.tomatoRed,
                  ),
                ),
                Text(
                  '₹${totalPending.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: palette.tomatoRed,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final billsSection = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bill Details (${_bills.length} bills)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : palette.mutedGray,
            ),
          ),
          const SizedBox(height: 12),
          _bills.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 48,
                          color: isDark
                              ? Colors.white24
                              : palette.darkGray,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No payment history yet',
                          style: TextStyle(
                            color: isDark
                                ? Colors.white54
                                : palette.darkGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _bills.length,
                  itemBuilder: (context, index) {
                    final bill = _bills[index];
                    final remaining =
                        bill.subtotal - bill.paidAmount;
                    final isPaid = bill.status == 'Paid';
                    final isPartial = bill.status == 'Partial';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : Colors.white,
                      elevation: isDark ? 0 : 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isDark
                              ? Colors.white10
                              : Colors.transparent,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            // Bill Header
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Bill #${bill.id.substring(0, 8)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: isDark
                                        ? Colors.white
                                        : palette.mutedGray,
                                  ),
                                ),
                                Container(
                                  padding:
                                      const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                  decoration: BoxDecoration(
                                    color: isPaid
                                        ? palette.leafGreen
                                              .withOpacity(0.1)
                                        : isPartial
                                        ? palette.sunYellow
                                              .withOpacity(0.1)
                                        : palette.tomatoRed
                                              .withOpacity(0.1),
                                    borderRadius:
                                        BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    bill.status,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isPaid
                                          ? palette.leafGreen
                                          : isPartial
                                          ? palette.sunYellow
                                          : palette.tomatoRed,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Bill Details
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Date: ${bill.date.day}/${bill.date.month}/${bill.date.year}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: palette.darkGray,
                                  ),
                                ),
                                Text(
                                  'Total: ₹${bill.subtotal.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : palette.mutedGray,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Payment Breakdown
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.black26
                                    : palette.offWhite,
                                borderRadius:
                                    BorderRadius.circular(4),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment
                                            .spaceBetween,
                                    children: [
                                      Text(
                                        '💵 Cash Paid:',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black,
                                        ),
                                      ),
                                      Text(
                                        '₹${bill.cashPaid.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontWeight:
                                              FontWeight.bold,
                                          fontSize: 12,
                                          color:
                                              palette.royalBlue,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment
                                            .spaceBetween,
                                    children: [
                                      Text(
                                        '💳 Online Paid:',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black,
                                        ),
                                      ),
                                      Text(
                                        '₹${bill.onlinePaid.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontWeight:
                                              FontWeight.bold,
                                          fontSize: 12,
                                          color: Colors.purple,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Remaining Due
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Remaining Due:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white70
                                        : palette.mutedGray,
                                  ),
                                ),
                                Text(
                                  '₹${remaining.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: remaining > 0
                                        ? palette.tomatoRed
                                        : palette.leafGreen,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Payment History',
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      ),
      backgroundColor: isDark ? const Color(0xFF0F172A) : palette.offWhite,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ResponsiveContainer(
              child: SingleChildScrollView(
                child: isMobile
                    ? Column(
                        children: [
                          summarySection,
                          billsSection,
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: summarySection,
                          ),
                          Expanded(
                            flex: 7,
                            child: billsSection,
                          ),
                        ],
                      ),
              ),
            ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required double amount,
    required Color color,
    required AppColorPalette palette,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white.withOpacity(0.8),
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white54 : palette.darkGray,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
