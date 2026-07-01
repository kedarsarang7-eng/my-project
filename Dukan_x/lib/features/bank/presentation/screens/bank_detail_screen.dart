import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/repository/bank_repository.dart' as repo;
import '../../../../core/session/session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../providers/app_state_providers.dart';
import '../../../../widgets/glass_morphism.dart';
import 'package:intl/intl.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class BankDetailScreen extends ConsumerStatefulWidget {
  final repo.BankAccount account;

  const BankDetailScreen({super.key, required this.account});

  @override
  ConsumerState<BankDetailScreen> createState() => _BankDetailScreenState();
}

class _BankDetailScreenState extends ConsumerState<BankDetailScreen> {
  final String? _ownerId = sl<SessionManager>().ownerId;

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeStateProvider);
    final isDark = theme.isDark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(widget.account.bankName ?? 'Bank Details'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: Stack(
        children: [
          // Global Gradient Background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        const Color(0xFF0F2027),
                        const Color(0xFF203A43),
                        const Color(0xFF2C5364),
                      ]
                    : [const Color(0xFFDAE2F8), const Color(0xFFD6A4A4)],
              ),
            ),
          ),

          SafeArea(
            child: StreamBuilder<repo.BankAccount>(
              stream: sl<repo.BankRepository>().watchAccount(widget.account.id),
              initialData: widget.account,
              builder: (context, accountSnapshot) {
                final account = accountSnapshot.data ?? widget.account;

                return Center(
                  child: BoundedBox(
                    maxWidth: 800,
                    child: Column(
                      children: [
                        // Header Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          child: GlassContainer(
                            borderRadius: 20,
                            opacity: isDark ? 0.2 : 0.6,
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  Text(
                                    "Current Balance",
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "${sl<CurrencyService>().symbol} ${account.currentBalance.toStringAsFixed(2)}",
                                    style: TextStyle(
                                      fontSize: responsiveValue<double>(
                                        context,
                                        mobile: 28.0,
                                        tablet: 30.0,
                                        desktop: 32.0,
                                      ),
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildActionButton(
                                          context,
                                          "Deposit",
                                          Icons.arrow_downward_rounded,
                                          Colors.green,
                                          isDark,
                                          () => _showTransactionDialog(
                                            context,
                                            'CREDIT',
                                            isDark,
                                            account,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: _buildActionButton(
                                          context,
                                          "Withdraw",
                                          Icons.arrow_upward_rounded,
                                          Colors.redAccent,
                                          isDark,
                                          () => _showTransactionDialog(
                                            context,
                                            'DEBIT',
                                            isDark,
                                            account,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Transactions List
                        Expanded(
                          child: StreamBuilder<List<repo.BankTransaction>>(
                            stream: sl<repo.BankRepository>().watchTransactions(
                              account.id,
                            ),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              final txns = snapshot.data ?? [];

                              if (txns.isEmpty) {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.receipt_long_rounded,
                                        size: 60,
                                        color: isDark
                                            ? Colors.white24
                                            : Colors.grey.shade400,
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        "No transactions yet",
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white60
                                              : Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              return ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: txns.length,
                                itemBuilder: (context, index) {
                                  final txn = txns[index];
                                  final isCredit = txn.type == 'CREDIT';
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: GlassCard(
                                      borderRadius: 16,
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: isCredit
                                                  ? Colors.green.withOpacity(0.1)
                                                  : Colors.red.withOpacity(0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              isCredit
                                                  ? Icons.arrow_downward
                                                  : Icons.arrow_upward,
                                              color: isCredit
                                                  ? Colors.green
                                                  : Colors.red,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  txn.description ?? '',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: isDark
                                                        ? Colors.white
                                                        : Colors.black87,
                                                  ),
                                                ),
                                                Text(
                                                  DateFormat(
                                                    'MMM dd, yyyy • hh:mm a',
                                                  ).format(txn.date),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: isDark
                                                        ? Colors.white54
                                                        : Colors.grey,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            "${isCredit ? '+' : '-'} ₹${txn.amount.toStringAsFixed(0)}",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: isCredit
                                                  ? Colors.green
                                                  : Colors.red,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    bool isDark,
    VoidCallback onTap,
  ) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.2),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withOpacity(0.5)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showTransactionDialog(
    BuildContext context,
    String type,
    bool isDark,
    repo.BankAccount account,
  ) {
    final TextEditingController amountCtrl = TextEditingController();
    final TextEditingController descCtrl = TextEditingController();
    final isCredit = type == 'CREDIT';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          title: Text(
            isCredit ? "Deposit Money" : "Withdraw Money",
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  labelText: "Amount",
                  labelStyle: TextStyle(
                    color: isDark ? Colors.white70 : Colors.grey,
                  ),
                  prefixText: "${sl<CurrencyService>().symbol} ",
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: isCredit ? Colors.green : Colors.redAccent,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descCtrl,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  labelText: "Description / Note",
                  labelStyle: TextStyle(
                    color: isDark ? Colors.white70 : Colors.grey,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: isCredit ? Colors.green : Colors.redAccent,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isCredit ? Colors.green : Colors.redAccent,
              ),
              onPressed: () async {
                if (amountCtrl.text.isEmpty) return;

                final amount = double.tryParse(amountCtrl.text) ?? 0.0;
                if (amount <= 0) return;

                await sl<repo.BankRepository>().recordTransaction(
                  userId: _ownerId ?? '',
                  accountId: account.id,
                  amount: amount,
                  type: type,
                  category: isCredit ? 'DEPOSIT' : 'WITHDRAWAL',
                  description: descCtrl.text.isEmpty
                      ? (isCredit ? "Deposit" : "Withdrawal")
                      : descCtrl.text,
                  date: DateTime.now(),
                );
              },
              child: Text(isCredit ? "Deposit" : "Withdraw"),
            ),
          ],
        );
      },
    );
  }
}
