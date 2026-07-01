// ============================================================================
// CUSTOMER DETAIL SCREEN
// ============================================================================
// Comprehensive customer detail view with action buttons, aging analysis,
// and transaction tabs. This is the main screen for managing a single customer.
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/repository/customers_repository.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/services/customer_enforcement_service.dart';
import '../../../../providers/app_state_providers.dart';
import '../../data/repositories/customer_repository.dart';

// Widgets
import '../widgets/customer_action_buttons.dart';
import '../widgets/customer_aging_widget.dart';
import '../widgets/credit_limit_dialog.dart';
import '../widgets/customer_qr_dialog.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';

// Screens
import '../../../billing/presentation/screens/bill_creation_screen_v2.dart';
import 'customer_ledger_screen.dart';
import 'customer_payment_screen.dart';
import '../../../party_ledger/services/party_ledger_service.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class CustomerDetailScreen extends ConsumerStatefulWidget {
  final String customerId;

  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  ConsumerState<CustomerDetailScreen> createState() =>
      _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends ConsumerState<CustomerDetailScreen> {
  Customer? _customer;
  bool _isLoading = true;
  CustomerAgingData _agingData = CustomerAgingData.empty();

  /// Live rolled-up balance from GET /customers/{id}/profile (Part 2).
  /// Null until fetched; the financial summary falls back to the local
  /// [Customer] totals when null or zero — so the screen renders fully
  /// even offline or before the profile call resolves.
  CustomerProfileBalance? _liveBalance;

  @override
  void initState() {
    super.initState();
    _loadCustomer();
  }

  Future<void> _loadCustomer() async {
    setState(() => _isLoading = true);

    final repo = sl<CustomersRepository>();
    final result = await repo.getById(widget.customerId);

    if (result.isSuccess && result.data != null) {
      setState(() {
        _customer = result.data;
        _isLoading = false;
      });
      _loadAgingData();
      _loadLiveBalance();
    } else {
      setState(() => _isLoading = false);
    }
  }

  /// Fetch fresh rolled-up totals from the backend. Best-effort: any failure
  /// (offline, missing DI, HTTP error) is swallowed so offline use and tests
  /// are unaffected. Only overlays when the backend actually has data.
  Future<void> _loadLiveBalance() async {
    try {
      final repo = CustomerRepository(sl<ApiClient>());
      final balance = await repo.getCustomerProfileBalance(widget.customerId);
      if (mounted && balance != null) {
        setState(() => _liveBalance = balance);
      }
    } catch (_) {
      // Offline or ApiClient unavailable — keep using local Customer totals.
    }
  }

  /// Effective totals: prefer the live backend rollup when available and
  /// non-trivial, otherwise fall back to the offline-first Customer fields.
  double get _effectiveTotalBilled =>
      (_liveBalance != null && _liveBalance!.totalBilled > 0)
      ? _liveBalance!.totalBilled
      : (_customer?.totalBilled ?? 0);
  double get _effectiveTotalPaid =>
      (_liveBalance != null && _liveBalance!.totalPaid > 0)
      ? _liveBalance!.totalPaid
      : (_customer?.totalPaid ?? 0);
  double get _effectiveOutstanding => (_liveBalance != null)
      ? _liveBalance!.outstanding
      : (_customer?.totalDues ?? 0);

  Future<void> _loadAgingData() async {
    if (_customer == null) return;

    try {
      final userId = sl<SessionManager>().ownerId ?? '';
      final ledgerService = sl<PartyLedgerService>();

      final report = await ledgerService.getAgingAnalysis(
        userId: userId,
        partyId: widget.customerId,
        partyType: 'CUSTOMER',
      );

      // Map AgingReport to UI model
      // Note: Counts are not currently returned by service, setting to 0 or 1 if amount > 0
      setState(() {
        _agingData = CustomerAgingData(
          current: report.buckets[0].amount,
          due31to60: report.buckets[1].amount,
          due61to90: report.buckets[2].amount,
          overdue90Plus: report.buckets[3].amount,
          currentCount: report.buckets[0].amount > 0 ? 1 : 0,
          due31to60Count: report.buckets[1].amount > 0 ? 1 : 0,
          due61to90Count: report.buckets[2].amount > 0 ? 1 : 0,
          overdue90PlusCount: report.buckets[3].amount > 0 ? 1 : 0,
          totalOutstanding: report.totalDue,
        );
      });
    } catch (e) {
      debugPrint('Error loading aging data: $e');
      // Keep empty logic on error
      if (mounted) setState(() => _agingData = CustomerAgingData.empty());
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeStateProvider);
    final isDark = themeState.isDark;

    if (_isLoading) {
      return const DesktopContentContainer(
        title: 'Customer Details',
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 64),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_customer == null) {
      return DesktopContentContainer(
        title: 'Customer Details',
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 64),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.person_off_outlined,
                size: 48,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 12),
              const Text('Customer not found'),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _loadCustomer,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return DesktopContentContainer(
      title: 'Customer Details',
      subtitle: 'Manage customer profile and transactions',
      actions: [
        DesktopIconButton(
          icon: Icons.qr_code,
          tooltip: 'Connect App',
          onPressed: () => CustomerQrDialog.show(
            context,
            customerId: widget.customerId,
            customerName: _customer!.name,
          ),
        ),
        DesktopIconButton(
          icon: Icons.credit_card,
          tooltip: 'Credit Limit',
          onPressed: _showCreditLimitDialog,
        ),
        DesktopIconButton(
          icon: Icons.edit,
          tooltip: 'Edit',
          onPressed: () => _handleMenuAction('edit'),
        ),
        DesktopIconButton(
          icon: _customer!.isBlocked ? Icons.check_circle : Icons.block,
          tooltip: _customer!.isBlocked ? 'Unblock' : 'Block',
          onPressed: () =>
              _handleMenuAction(_customer!.isBlocked ? 'unblock' : 'block'),
        ),
      ],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Custom Header Card
            _buildDesktopHeader(isDark),
            const SizedBox(height: 16),

            // Financial Summary
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  if (!isDark)
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                    ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildFinancialStat(
                      'Total Sales',
                      '₹${_effectiveTotalBilled.toStringAsFixed(0)}',
                      Colors.blue,
                      isDark,
                    ),
                  ),
                  Container(width: 1, height: 40, color: Colors.grey.shade300),
                  Expanded(
                    child: _buildFinancialStat(
                      'Total Paid',
                      '₹${_effectiveTotalPaid.toStringAsFixed(0)}',
                      Colors.green,
                      isDark,
                    ),
                  ),
                  Container(width: 1, height: 40, color: Colors.grey.shade300),
                  Expanded(
                    child: _buildFinancialStat(
                      'Outstanding',
                      '₹${_effectiveOutstanding.toStringAsFixed(0)}',
                      _effectiveOutstanding > 0 ? Colors.orange : Colors.green,
                      isDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Action Buttons
            CustomerActionButtons(
              customerId: widget.customerId,
              customerName: _customer!.name,
              onCreateBill: () => _navigateToBillCreation(),
              onCreateEstimate: () => _showComingSoon('Estimate'),
              onDeliveryChallan: () => _showComingSoon('Delivery Challan'),
              onReceivePayment: () => _navigateToPayment(),
              onIssueCreditNote: () => _showComingSoon('Credit Note'),
              onAddRemark: () => _showRemarkDialog(),
            ),
            const SizedBox(height: 16),

            // Aging Widget
            if (_effectiveOutstanding > 0)
              CustomerAgingWidget(
                agingData: _agingData,
                onBucketTap: () => _navigateToLedger(),
              ),

            // Credit Limit Info
            if (_customer!.creditLimit > 0)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.credit_score,
                        color: Colors.blue,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Credit Limit',
                            style: TextStyle(
                              color: isDark ? Colors.white60 : Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '₹${_customer!.creditLimit.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Available',
                          style: TextStyle(
                            color: isDark ? Colors.white60 : Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '₹${(_customer!.creditLimit - _customer!.totalDues).toStringAsFixed(0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color:
                                (_customer!.creditLimit -
                                        _customer!.totalDues) >
                                    0
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),
            // View Ledger Button
            OutlinedButton.icon(
              onPressed: _navigateToLedger,
              icon: const Icon(Icons.account_balance_wallet),
              label: const Text('View Full Ledger'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopHeader(bool isDark) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24),
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [Colors.blue.shade600, Colors.blue.shade800],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 35,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: Text(
              _avatarInitial(_customer!.name),
              style: GoogleFonts.outfit(
                fontSize: responsiveValue<double>(
                  context,
                  mobile: 22,
                  tablet: 24,
                  desktop: 28,
                ),
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Customer Type Badge
                if (_customer!.customerType != CustomerType.regular)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _getCustomerTypeColor(
                        _customer!.customerType,
                      ).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _customer!.customerType.name.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                // Name
                Text(
                  _customer!.name.trim().isEmpty
                      ? 'Unnamed Customer'
                      : _customer!.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: responsiveValue<double>(
                      context,
                      mobile: 18,
                      tablet: 20,
                      desktop: 24,
                    ),
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                // Phone
                Text(
                  _customer!.phone?.isNotEmpty == true
                      ? _customer!.phone!
                      : 'No phone',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                ),
              ],
            ),
          ),
          // Block Status
          if (_customer!.isBlocked)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.block, color: Colors.red, size: 24),
            ),
        ],
      ),
    );
  }

  Widget _buildFinancialStat(
    String label,
    String value,
    Color color,
    bool isDark,
  ) {
    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isDark ? Colors.white60 : Colors.grey,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        // FittedBox scales large currency values down instead of overflowing
        // the fixed-width Row column on narrow phones.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }

  /// Safe first-letter for avatars — guards against empty/whitespace names
  /// which would otherwise throw a RangeError on `name[0]`.
  String _avatarInitial(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
  }

  Color _getCustomerTypeColor(CustomerType type) {
    switch (type) {
      case CustomerType.cash:
        return Colors.green;
      case CustomerType.credit:
        return Colors.orange;
      case CustomerType.regular:
        return Colors.blue;
      case CustomerType.wholesale:
        return Colors.purple;
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'edit':
        // Navigate to edit screen
        break;
      case 'block':
        _showBlockDialog();
        break;
      case 'unblock':
        _unblockCustomer();
        break;
    }
  }

  Future<void> _showCreditLimitDialog() async {
    final result = await CreditLimitDialog.show(
      context: context,
      customerName: _customer!.name,
      currentOutstanding: _customer!.totalDues,
      currentCreditLimit: _customer!.creditLimit,
    );

    if (result != null) {
      final service = sl<CustomerEnforcementService>();
      final userId = sl<SessionManager>().ownerId ?? '';

      bool success;
      if (result.removed) {
        success = await service.updateCreditLimit(
          customerId: widget.customerId,
          userId: userId,
          newLimit: 0,
        );
      } else if (result.newLimit != null) {
        success = await service.updateCreditLimit(
          customerId: widget.customerId,
          userId: userId,
          newLimit: result.newLimit!,
        );
      } else {
        return;
      }

      if (success) {
        _loadCustomer();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Credit limit updated')));
      }
    }
  }

  void _showBlockDialog() {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block Customer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Are you sure you want to block this customer? They will not be able to create new bills on credit.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _blockCustomer(reasonController.text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }

  Future<void> _blockCustomer(String reason) async {
    final service = sl<CustomerEnforcementService>();
    final userId = sl<SessionManager>().ownerId ?? '';

    final success = await service.blockCustomer(
      customerId: widget.customerId,
      userId: userId,
      reason: reason.isEmpty ? 'Blocked by shop owner' : reason,
    );

    if (success) {
      _loadCustomer();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Customer blocked')));
    }
  }

  Future<void> _unblockCustomer() async {
    final service = sl<CustomerEnforcementService>();
    final userId = sl<SessionManager>().ownerId ?? '';

    final success = await service.unblockCustomer(
      customerId: widget.customerId,
      userId: userId,
    );

    if (success) {
      _loadCustomer();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Customer unblocked')));
    }
  }

  void _navigateToBillCreation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BillCreationScreenV2(initialCustomer: _customer),
      ),
    );
  }

  void _navigateToPayment() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerPaymentScreen(
          customerId: widget.customerId,
          suggestedAmount: _customer!.totalDues > 0
              ? _customer!.totalDues
              : null,
        ),
      ),
    );
  }

  void _navigateToLedger() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerLedgerScreen(customerId: widget.customerId),
      ),
    );
  }

  void _showRemarkDialog() {
    final remarkController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Remark'),
        content: TextField(
          controller: remarkController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Enter remark about this customer...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (remarkController.text.trim().isNotEmpty) {
                // Save remark - in production, call repository
                Navigator.pop(ctx);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Remark saved')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(String feature) {
    // Route to actual screens where they exist
    switch (feature) {
      case 'Estimate':
        context.push('/proforma', extra: {'customerId': widget.customerId});
        break;
      case 'Delivery Challan':
        context.push(
          '/delivery-challan',
          extra: {'customerId': widget.customerId},
        );
        break;
      case 'Credit Note':
        context.push(
          '/return-inwards',
          extra: {'customerId': widget.customerId},
        );
        break;
      default:
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Navigate to $feature')));
    }
  }
}
