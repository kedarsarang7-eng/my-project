import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/repository/expenses_repository.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';
import '../../../../widgets/desktop/futuristic_kpi_card.dart';
import '../../../../widgets/desktop/enterprise_table.dart';
import '../../../../widgets/desktop/empty_state.dart';
import '../../../../widgets/desktop/premium_form_section.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Expenses Screen - Redesigned for Desktop
///
/// Features:
/// - No standalone Scaffold - integrates with EnterpriseDesktopShell
/// - KPI summary cards at top
/// - Enterprise table with sorting and pagination
/// - Premium add expense dialog
class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = sessionManager.userId ?? '';

    if (userId.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.account_circle_outlined,
        title: 'Not Logged In',
        description: 'Please log in to view your expenses.',
      );
    }

    return StreamBuilder<List<ExpenseModel>>(
      stream: sl<ExpensesRepository>().watchAll(userId: userId),
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final expenses = snapshot.data ?? [];

        // Calculate totals for KPI cards
        final now = DateTime.now();
        final todayExpenses = expenses
            .where(
              (e) =>
                  e.date.day == now.day &&
                  e.date.month == now.month &&
                  e.date.year == now.year,
            )
            .fold<double>(0, (sum, e) => sum + e.amount);

        final monthExpenses = expenses
            .where((e) => e.date.month == now.month && e.date.year == now.year)
            .fold<double>(0, (sum, e) => sum + e.amount);

        final totalExpenses = expenses.fold<double>(
          0,
          (sum, e) => sum + e.amount,
        );

        return DesktopContentContainer(
          title: 'Expenses',
          subtitle: 'Track and manage your business expenses',
          actions: [
            DesktopActionButton(
              icon: Icons.add_rounded,
              label: 'Add Expense',
              onPressed: () => _showAddExpenseDialog(context, userId),
              isPrimary: true,
              color: FuturisticColors.error,
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // KPI Cards Row
              KpiCardRow(
                cards: [
                  FuturisticKpiCard(
                    label: 'Today\'s Expenses',
                    value: '₹${_formatAmount(todayExpenses)}',
                    icon: Icons.today_rounded,
                    accentColor: FuturisticColors.error,
                  ),
                  FuturisticKpiCard(
                    label: 'This Month',
                    value: '₹${_formatAmount(monthExpenses)}',
                    icon: Icons.calendar_month_rounded,
                    accentColor: FuturisticColors.warning,
                  ),
                  FuturisticKpiCard(
                    label: 'Total Expenses',
                    value: '₹${_formatAmount(totalExpenses)}',
                    icon: Icons.account_balance_wallet_rounded,
                    accentColor: FuturisticColors.textSecondary,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Expenses Table
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: FuturisticColors.surface.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: FuturisticColors.premiumBlue.withOpacity(0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Table Header
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.white.withOpacity(0.05),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              'Recent Expenses',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${expenses.length} entries',
                              style: TextStyle(
                                fontSize: 13,
                                color: FuturisticColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Table Body
                      Expanded(
                        child: isLoading
                            ? Center(
                                child: CircularProgressIndicator(
                                  color: FuturisticColors.premiumBlue,
                                ),
                              )
                            : expenses.isEmpty
                            ? CompactEmptyState(
                                icon: Icons.money_off_outlined,
                                message: 'No expenses recorded yet',
                                actionLabel: 'Add First Expense',
                                onAction: () =>
                                    _showAddExpenseDialog(context, userId),
                              )
                            : EnterpriseTable<ExpenseModel>(
                                data: expenses,
                                columns: [
                                  EnterpriseTableColumn<ExpenseModel>(
                                    title: 'Date',
                                    valueBuilder: (e) => e.date,
                                    widgetBuilder: (e) => Text(
                                      DateFormat('MMM dd, yyyy').format(e.date),
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  EnterpriseTableColumn<ExpenseModel>(
                                    title: 'Category',
                                    valueBuilder: (e) => e.category,
                                    widgetBuilder: (e) => Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: FuturisticColors.error
                                                .withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Icon(
                                            _getCategoryIcon(e.category),
                                            size: 16,
                                            color: FuturisticColors.error,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          e.category,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  EnterpriseTableColumn<ExpenseModel>(
                                    title: 'Description',
                                    valueBuilder: (e) => e.description,
                                    widgetBuilder: (e) => Text(
                                      e.description,
                                      style: TextStyle(
                                        color: FuturisticColors.textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  EnterpriseTableColumn<ExpenseModel>(
                                    title: 'Amount',
                                    valueBuilder: (e) => e.amount,
                                    isNumeric: true,
                                    widgetBuilder: (e) => Text(
                                      '₹${_formatAmount(e.amount)}',
                                      style: const TextStyle(
                                        color: FuturisticColors.error,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                                actionsBuilder: (expense) => [
                                  IconButton(
                                    icon: Icon(
                                      Icons.delete_outline,
                                      color: FuturisticColors.textSecondary,
                                      size: 18,
                                    ),
                                    tooltip: 'Delete',
                                    onPressed: () =>
                                        _confirmDelete(context, expense),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(2);
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'rent':
        return Icons.home_outlined;
      case 'salary':
        return Icons.people_outline;
      case 'utilities':
        return Icons.bolt_outlined;
      case 'transport':
        return Icons.directions_car_outlined;
      case 'food':
        return Icons.restaurant_outlined;
      case 'inventory':
        return Icons.inventory_2_outlined;
      default:
        return Icons.receipt_long_outlined;
    }
  }

  void _confirmDelete(BuildContext context, ExpenseModel expense) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FuturisticColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Expense',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete this ${expense.category} expense of ₹${expense.amount.toStringAsFixed(2)}?',
          style: TextStyle(color: FuturisticColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: FuturisticColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              sl<ExpensesRepository>().deleteExpense(
                id: expense.id,
                userId: expense.ownerId,
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: FuturisticColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddExpenseDialog(BuildContext context, String userId) {
    final categoryController = TextEditingController();
    final descriptionController = TextEditingController();
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: FuturisticColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 480,
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
                      color: FuturisticColors.error.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.add_card_rounded,
                      color: FuturisticColors.error,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add New Expense',
                          style: TextStyle(
                            fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
                  ),
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Record a new business expense',
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

              // Form Fields
              PremiumFormSection(
                title: 'Expense Details',
                columns: 1,
                children: [
                  PremiumTextField(
                    label: 'Category',
                    hint: 'e.g., Rent, Salary, Utilities',
                    controller: categoryController,
                    prefixIcon: Icons.category_outlined,
                  ),
                  PremiumTextField(
                    label: 'Description',
                    hint: 'Brief description of the expense',
                    controller: descriptionController,
                    prefixIcon: Icons.notes_outlined,
                  ),
                  PremiumTextField(
                    label: 'Amount (₹)',
                    hint: 'Enter amount',
                    controller: amountController,
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
                    onPressed: () {
                      final amount =
                          double.tryParse(amountController.text) ?? 0;
                      if (categoryController.text.isNotEmpty && amount > 0) {
                        sl<ExpensesRepository>().createExpense(
                          ownerId: userId,
                          category: categoryController.text,
                          description: descriptionController.text,
                          amount: amount,
                        );
                        Navigator.pop(context);
                      }
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Expense'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FuturisticColors.error,
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
