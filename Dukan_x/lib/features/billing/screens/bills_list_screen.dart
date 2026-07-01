// ============================================================================
// BILLS LIST SCREEN - PREMIUM FUTURISTIC UI
// ============================================================================
// Uses sl<BillsRepository> for reactive offline-first data access
// All existing functionality preserved:
// - Status filtering, Bill details navigation, New bill creation
// ============================================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/services/currency_service.dart';
import '../../../core/repository/bills_repository.dart';
import '../../../core/session/session_manager.dart';
import '../../../core/theme/futuristic_colors.dart';
import '../../../widgets/modern_ui_components.dart';
import '../../../widgets/glass_morphism.dart';
import '../presentation/screens/bill_creation_screen_v2.dart';
import '../../../screens/bill_detail.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class BillsListScreen extends StatefulWidget {
  const BillsListScreen({super.key});

  @override
  State<BillsListScreen> createState() => _BillsListScreenState();
}

class _BillsListScreenState extends State<BillsListScreen> {
  final _billsRepo = sl<BillsRepository>();
  final _session = sl<SessionManager>();

  String _statusFilter = 'ALL';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userId = _session.ownerId;

    if (userId == null) {
      return Scaffold(
        backgroundColor: isDark
            ? FuturisticColors.darkBackground
            : FuturisticColors.background,
        body: const Center(child: Text('Authentication Required')),
      );
    }

    return Scaffold(
      backgroundColor: isDark
          ? FuturisticColors.darkBackground
          : FuturisticColors.background,
      appBar: _buildPremiumAppBar(context, isDark),
      body: BoundedBox(
        maxWidth: 800,
        child: StreamBuilder<List<Bill>>(
          stream: _billsRepo.watchAll(userId: userId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    FuturisticColors.primary,
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return _buildErrorState(snapshot.error.toString());
            }

            final bills = snapshot.data ?? [];
            final filtered = _statusFilter == 'ALL'
                ? bills
                : bills.where((b) => b.status == _statusFilter).toList();

            if (filtered.isEmpty) {
              return _buildEmptyState(isDark);
            }

            return _buildBillsList(filtered, isDark);
          },
        ),
      ),
      floatingActionButton: _buildPremiumFAB(),
    );
  }

  PreferredSizeWidget _buildPremiumAppBar(BuildContext context, bool isDark) {
    return AppBar(
      elevation: 0,
      backgroundColor: isDark
          ? FuturisticColors.darkSurface
          : FuturisticColors.surface,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: AppGradients.primaryGradient,
              borderRadius: BorderRadius.circular(AppBorderRadius.md),
              boxShadow: AppShadows.glowShadow(FuturisticColors.primary),
            ),
            child: const Icon(
              Icons.receipt_long,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            'Sales Invoices',
            style: AppTypography.headlineMedium.copyWith(
              color: isDark
                  ? FuturisticColors.darkTextPrimary
                  : FuturisticColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: AppSpacing.md),
          decoration: BoxDecoration(
            color: FuturisticColors.secondary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(AppBorderRadius.md),
            border: Border.all(
              color: FuturisticColors.secondary.withOpacity(0.3),
            ),
          ),
          child: IconButton(
            icon: Icon(Icons.filter_list, color: FuturisticColors.secondary),
            onPressed: _showFilterSheet,
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumFAB() {
    return Container(
      decoration: BoxDecoration(
        gradient: AppGradients.primaryGradient,
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        boxShadow: AppShadows.glowShadow(FuturisticColors.primary),
      ),
      child: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BillCreationScreenV2()),
          );
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'NEW BILL',
          style: AppTypography.labelLarge.copyWith(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildBillsList(List<Bill> bills, bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: bills.length,
      itemBuilder: (context, index) => _buildBillCard(bills[index], isDark),
    );
  }

  Widget _buildBillCard(Bill bill, bool isDark) {
    final currencyFormat = NumberFormat.currency(symbol: sl<CurrencyService>().symbol, decimalDigits: 2);
    final dateFormat = DateFormat('dd MMM, hh:mm a');

    Color statusColor;
    Gradient statusGradient;
    switch (bill.status) {
      case 'PAID':
        statusColor = FuturisticColors.success;
        statusGradient = AppGradients.primaryGradient;
        break;
      case 'PENDING':
        statusColor = FuturisticColors.warning;
        statusGradient = const LinearGradient(
          colors: [Color(0xFFFFD600), Color(0xFFFF9800)],
        );
        break;
      case 'PARTIAL':
        statusColor = FuturisticColors.accent2;
        statusGradient = AppGradients.secondaryGradient;
        break;
      default:
        statusColor = FuturisticColors.textMuted;
        statusGradient = AppGradients.glassGradient;
    }

    return ModernCard(
      backgroundColor: isDark
          ? FuturisticColors.darkSurface
          : FuturisticColors.surface,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => BillDetailScreen(bill: bill)),
        );
      },
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bill.invoiceNumber,
                    style: AppTypography.labelLarge.copyWith(
                      color: isDark
                          ? FuturisticColors.darkTextPrimary
                          : FuturisticColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    dateFormat.format(bill.billDate),
                    style: AppTypography.labelSmall.copyWith(
                      color: isDark
                          ? FuturisticColors.darkTextSecondary
                          : FuturisticColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  gradient: statusGradient,
                  borderRadius: BorderRadius.circular(AppBorderRadius.xxl),
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  bill.status,
                  style: AppTypography.labelSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          Divider(
            height: AppSpacing.lg,
            color: isDark
                ? FuturisticColors.darkDivider
                : FuturisticColors.divider,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bill.customerName.isEmpty
                        ? 'Walk-in Customer'
                        : bill.customerName,
                    style: AppTypography.labelMedium.copyWith(
                      color: isDark
                          ? FuturisticColors.darkTextPrimary
                          : FuturisticColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${bill.items.length} items',
                    style: AppTypography.labelSmall.copyWith(
                      color: isDark
                          ? FuturisticColors.darkTextSecondary
                          : FuturisticColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Text(
                currencyFormat.format(bill.grandTotal),
                style: AppTypography.headlineMedium.copyWith(
                  color: FuturisticColors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          if (!bill.isSynced)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Row(
                children: [
                  Icon(
                    Icons.sync_problem,
                    size: 14,
                    color: FuturisticColors.warning,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Pending Sync',
                    style: AppTypography.labelSmall.copyWith(
                      color: FuturisticColors.warning,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: GlassContainer(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        borderRadius: AppBorderRadius.xxl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                gradient: AppGradients.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: AppShadows.glowShadow(FuturisticColors.primary),
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                size: 48,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No invoices found',
              style: AppTypography.headlineMedium.copyWith(
                color: isDark
                    ? FuturisticColors.darkTextPrimary
                    : FuturisticColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Create your first sale invoice',
              style: AppTypography.bodyMedium.copyWith(
                color: isDark
                    ? FuturisticColors.darkTextSecondary
                    : FuturisticColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Text('Error: $error', style: const TextStyle(color: Colors.red)),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['ALL', 'PENDING', 'PAID', 'PARTIAL'].map((status) {
            return ListTile(
              title: Text(status),
              onTap: () {
                setState(() => _statusFilter = status);
                Navigator.pop(context);
              },
              trailing: _statusFilter == status
                  ? const Icon(Icons.check, color: Colors.blue)
                  : null,
            );
          }).toList(),
        ),
      ),
    );
  }
}
