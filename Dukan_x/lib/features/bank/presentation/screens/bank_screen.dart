import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/repository/bank_repository.dart' as repo;
import '../../../../core/session/session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';
import '../../../../widgets/desktop/empty_state.dart';
import '../../../../widgets/desktop/premium_form_section.dart';
import 'bank_detail_screen.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Bank Accounts Screen - Redesigned for Desktop
///
/// Features:
/// - No standalone Scaffold - integrates with EnterpriseDesktopShell
/// - Grid layout for bank cards (credit-card style)
/// - Premium glassmorphism effects
/// - Desktop-optimized "Add Account" dialog
class BankScreen extends ConsumerStatefulWidget {
  const BankScreen({super.key});

  @override
  ConsumerState<BankScreen> createState() => _BankScreenState();
}

class _BankScreenState extends ConsumerState<BankScreen> {
  final String? _ownerId = sl<SessionManager>().ownerId;

  @override
  Widget build(BuildContext context) {
    // Use local variable for null promotion
    final userId = _ownerId;
    if (userId == null) {
      return const EmptyStateWidget(
        icon: Icons.account_balance_outlined,
        title: 'Authentication Error',
        description: 'Unable to verify user identity. Please relogin.',
      );
    }

    return StreamBuilder<List<repo.BankAccount>>(
      stream: sl<repo.BankRepository>().watchAccounts(userId: userId),
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final accounts = snapshot.data ?? [];

        return DesktopContentContainer(
          title: 'Bank Accounts',
          subtitle: 'Manage your business bank accounts and liquidity',
          actions: [
            DesktopActionButton(
              icon: Icons.add_rounded,
              label: 'Add Bank Account',
              onPressed: () => _showAddBankDialog(context),
              isPrimary: true,
              color: FuturisticColors.premiumBlue,
            ),
          ],
          child: isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color: FuturisticColors.premiumBlue,
                  ),
                )
              : accounts.isEmpty
              ? EmptyStateWidget(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'No Accounts Linked',
                  description:
                      'Add your primary business account to start tracking cash flow.',
                  buttonLabel: 'Add First Account',
                  onButtonPressed: () => _showAddBankDialog(context),
                )
              : GridView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: responsiveValue<int>(context, mobile: 1, tablet: 2, desktop: 3),
                    childAspectRatio: 1.6, // Credit card ratio
                    crossAxisSpacing: 24,
                    mainAxisSpacing: 24,
                  ),
                  itemCount: accounts.length,
                  itemBuilder: (context, index) {
                    return _buildBankCard(context, accounts[index]);
                  },
                ),
        );
      },
    );
  }

  Widget _buildBankCard(BuildContext context, repo.BankAccount account) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BankDetailScreen(account: account),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                FuturisticColors.premiumBlue.withOpacity(0.2),
                FuturisticColors.premiumBlue.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: FuturisticColors.premiumBlue.withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: FuturisticColors.premiumBlue.withOpacity(0.1),
                blurRadius: 24,
                spreadRadius: -4,
              ),
            ],
          ),
          child: Stack(
            children: [
              // Decorative circles
              Positioned(
                right: -20,
                top: -20,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.03),
                  ),
                ),
              ),
              Positioned(
                right: -60,
                bottom: -60,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: FuturisticColors.premiumBlue.withOpacity(0.05),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                account.bankName ?? 'Unknown Bank',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                account.accountName,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: FuturisticColors.textSecondary,
                                  letterSpacing: 0.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.account_balance,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ],
                    ),

                    // Balance
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Available Balance",
                          style: TextStyle(
                            fontSize: 11,
                            color: FuturisticColors.textSecondary.withOpacity(
                              0.8,
                            ),
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "${sl<CurrencyService>().symbol} ${account.currentBalance.toStringAsFixed(2)}",
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),

                    // Footer (Account Number & IFSC)
                    Row(
                      children: [
                        Text(
                          _formatAccountNumber(account.accountNumber),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                            color: Colors.white70,
                            letterSpacing: 2.0,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: FuturisticColors.premiumBlue.withOpacity(
                              0.15,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            account.ifsc ?? 'NO IFSC',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: FuturisticColors.premiumBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatAccountNumber(String? accNum) {
    if (accNum == null || accNum.isEmpty) return '****';
    if (accNum.length <= 4) return '**** $accNum';
    return '**** **** ${accNum.substring(accNum.length - 4)}';
  }

  void _showAddBankDialog(BuildContext context) {
    final bankNameCtrl = TextEditingController();
    final accountNameCtrl = TextEditingController();
    final accountNumCtrl = TextEditingController();
    final ifscCtrl = TextEditingController();
    final balanceCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: FuturisticColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: responsiveValue<double>(context, mobile: double.infinity, tablet: 500, desktop: 500),
          padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: FuturisticColors.premiumBlue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.account_balance_outlined,
                      color: FuturisticColors.premiumBlue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Link Bank Account',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Add details to track your business finances',
                          style: TextStyle(
                            fontSize: 13,
                            color: FuturisticColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: FuturisticColors.textSecondary,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Form
              PremiumFormSection(
                title: 'Account Details',
                columns: responsiveValue<int>(context, mobile: 1, tablet: 2, desktop: 2),
                children: [
                  PremiumTextField(
                    label: 'Bank Name',
                    hint: 'e.g., HDFC Bank',
                    controller: bankNameCtrl,
                    prefixIcon: Icons.business,
                  ),
                  PremiumTextField(
                    label: 'Account Name',
                    hint: 'e.g., Primary Business',
                    controller: accountNameCtrl,
                    prefixIcon: Icons.label_outline,
                  ),
                  PremiumTextField(
                    label: 'Account Number',
                    hint: 'Enter account number',
                    controller: accountNumCtrl,
                    keyboardType: TextInputType.number,
                    prefixIcon: Icons.numbers,
                  ),
                  PremiumTextField(
                    label: 'IFSC Code',
                    hint: 'e.g., HDFC0001234',
                    controller: ifscCtrl,
                    prefixIcon: Icons.code,
                  ),
                  PremiumTextField(
                    label: 'Opening Balance (₹)',
                    hint: '0.00',
                    controller: balanceCtrl,
                    keyboardType: TextInputType.number,
                    prefixIcon: Icons.currency_rupee,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: FuturisticColors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () async {
                      if (bankNameCtrl.text.isEmpty ||
                          balanceCtrl.text.isEmpty) {
                        return;
                      }

                      await sl<repo.BankRepository>().createAccount(
                        userId: _ownerId ?? '',
                        accountName: accountNameCtrl.text,
                        accountNumber: accountNumCtrl.text,
                        bankName: bankNameCtrl.text,
                        openingBalance:
                            double.tryParse(balanceCtrl.text) ?? 0.0,
                      );
                      if (context.mounted) Navigator.pop(context);
                    },
                    icon: const Icon(Icons.link, size: 18),
                    label: const Text('Link Account'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FuturisticColors.premiumBlue,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
