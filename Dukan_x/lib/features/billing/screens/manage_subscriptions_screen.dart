// ============================================================================
// MANAGE SUBSCRIPTIONS SCREEN - PREMIUM FUTURISTIC UI
// ============================================================================
// Lists active/paused/cancelled subscriptions with create/cancel actions.
// Uses sl<SubscriptionRepository> for reactive offline-first data access.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/repository/subscription_repository.dart';
import '../../../core/billing/recurring_billing_service.dart';
import '../../../core/session/session_manager.dart';
import '../../../core/theme/futuristic_colors.dart';
import '../../../widgets/modern_ui_components.dart';
import '../../../widgets/glass_morphism.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class ManageSubscriptionsScreen extends StatefulWidget {
  const ManageSubscriptionsScreen({super.key});

  @override
  State<ManageSubscriptionsScreen> createState() =>
      _ManageSubscriptionsScreenState();
}

class _ManageSubscriptionsScreenState extends State<ManageSubscriptionsScreen>
    with SingleTickerProviderStateMixin {
  final _subscriptionRepo = sl<SubscriptionRepository>();
  final _billingService = sl<RecurringBillingService>();
  final _session = sl<SessionManager>();
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userId = _session.ownerId;

    if (userId == null) {
      return Scaffold(
        backgroundColor: isDark
            ? FuturisticColors.darkBackground
            : FuturisticColors.background,
        body: BoundedBox(
          maxWidth: 800,
          child: const Center(child: Text('Authentication Required')),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark
          ? FuturisticColors.darkBackground
          : FuturisticColors.background,
      appBar: _buildAppBar(isDark),
      body: StreamBuilder<List<Subscription>>(
        stream: _subscriptionRepo.watchAllActive(userId),
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
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final subscriptions = snapshot.data ?? [];

          if (subscriptions.isEmpty) {
            return _buildEmptyState(isDark);
          }

          return _buildSubscriptionsList(subscriptions, isDark);
        },
      ),
      floatingActionButton: _buildFAB(userId),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
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
              Icons.autorenew_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            'Subscriptions',
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
            color: FuturisticColors.accent2.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppBorderRadius.md),
            border: Border.all(
              color: FuturisticColors.accent2.withValues(alpha: 0.3),
            ),
          ),
          child: IconButton(
            icon: Icon(
              Icons.play_circle_outline,
              color: FuturisticColors.accent2,
            ),
            tooltip: 'Process Due Subscriptions',
            onPressed: _processAllDue,
          ),
        ),
      ],
    );
  }

  Widget _buildFAB(String userId) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppGradients.primaryGradient,
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        boxShadow: AppShadows.glowShadow(FuturisticColors.primary),
      ),
      child: FloatingActionButton.extended(
        onPressed: () => _showCreateSubscriptionDialog(userId),
        backgroundColor: Colors.transparent,
        elevation: 0,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'NEW SUBSCRIPTION',
          style: AppTypography.labelLarge.copyWith(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildSubscriptionsList(
    List<Subscription> subscriptions,
    bool isDark,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: subscriptions.length,
      itemBuilder: (context, index) {
        return _buildSubscriptionCard(subscriptions[index], isDark);
      },
    );
  }

  Widget _buildSubscriptionCard(Subscription sub, bool isDark) {
    final currencyFormat = NumberFormat.currency(symbol: 'â‚¹', decimalDigits: 2);
    final dateFormat = DateFormat('dd MMM yyyy');

    Color statusColor;
    IconData statusIcon;
    switch (sub.status.toUpperCase()) {
      case 'ACTIVE':
        statusColor = FuturisticColors.success;
        statusIcon = Icons.check_circle;
        break;
      case 'PAUSED':
        statusColor = FuturisticColors.warning;
        statusIcon = Icons.pause_circle;
        break;
      case 'PAST_DUE':
        statusColor = FuturisticColors.error;
        statusIcon = Icons.error;
        break;
      default:
        statusColor = FuturisticColors.textMuted;
        statusIcon = Icons.cancel;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: ModernCard(
        backgroundColor: isDark
            ? FuturisticColors.darkSurface
            : FuturisticColors.surface,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Plan name + Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    sub.planName,
                    style: AppTypography.headlineMedium.copyWith(
                      color: isDark
                          ? FuturisticColors.darkTextPrimary
                          : FuturisticColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppBorderRadius.xxl),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        sub.status,
                        style: AppTypography.labelSmall.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Cycle + Amount
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.repeat,
                      size: 16,
                      color: FuturisticColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      sub.billingCycle,
                      style: AppTypography.bodyMedium.copyWith(
                        color: isDark
                            ? FuturisticColors.darkTextSecondary
                            : FuturisticColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Text(
                  currencyFormat.format(sub.grandTotal),
                  style: AppTypography.headlineMedium.copyWith(
                    color: FuturisticColors.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),

            Divider(
              height: AppSpacing.xl,
              color: isDark
                  ? FuturisticColors.darkDivider
                  : FuturisticColors.divider,
            ),

            // Next billing + Items count
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Next Billing',
                      style: AppTypography.labelSmall.copyWith(
                        color: isDark
                            ? FuturisticColors.darkTextSecondary
                            : FuturisticColors.textSecondary,
                      ),
                    ),
                    Text(
                      dateFormat.format(sub.nextBillingDate ?? DateTime.now()),
                      style: AppTypography.labelMedium.copyWith(
                        color: isDark
                            ? FuturisticColors.darkTextPrimary
                            : FuturisticColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${sub.items.length} item${sub.items.length == 1 ? '' : 's'}',
                  style: AppTypography.labelSmall.copyWith(
                    color: isDark
                        ? FuturisticColors.darkTextSecondary
                        : FuturisticColors.textSecondary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _cancelSubscription(sub),
                  icon: Icon(
                    Icons.cancel_outlined,
                    size: 18,
                    color: FuturisticColors.error,
                  ),
                  label: Text(
                    'Cancel',
                    style: AppTypography.labelSmall.copyWith(
                      color: FuturisticColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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
                Icons.autorenew_rounded,
                size: 48,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No Subscriptions Yet',
              style: AppTypography.headlineMedium.copyWith(
                color: isDark
                    ? FuturisticColors.darkTextPrimary
                    : FuturisticColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Create recurring billing subscriptions\nto auto-generate invoices.',
              textAlign: TextAlign.center,
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

  // ============================================
  // ACTIONS
  // ============================================

  Future<void> _processAllDue() async {
    final userId = _session.ownerId;
    if (userId == null) return;

    final count = await _billingService.processDueSubscriptions(userId);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          count > 0
              ? 'âœ… Processed $count subscription(s) â€” invoices generated!'
              : 'No subscriptions are due for billing.',
        ),
        backgroundColor: count > 0
            ? FuturisticColors.success
            : FuturisticColors.surface,
      ),
    );
  }

  Future<void> _cancelSubscription(Subscription sub) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Cancel Subscription'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Cancel "${sub.planName}"?'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Reason (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('BACK'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: FuturisticColors.error,
              ),
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text(
                'CANCEL SUBSCRIPTION',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (reason != null) {
      await _subscriptionRepo.deleteSubscription(sub.id, reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Subscription cancelled.'),
          backgroundColor: FuturisticColors.warning,
        ),
      );
    }
  }

  void _showCreateSubscriptionDialog(String userId) {
    showDialog(
      context: context,
      builder: (ctx) => _CreateSubscriptionDialog(userId: userId),
    );
  }
}

// ============================================================================
// CREATE SUBSCRIPTION DIALOG
// ============================================================================

class _CreateSubscriptionDialog extends StatefulWidget {
  final String userId;
  const _CreateSubscriptionDialog({required this.userId});

  @override
  State<_CreateSubscriptionDialog> createState() =>
      _CreateSubscriptionDialogState();
}

class _CreateSubscriptionDialogState extends State<_CreateSubscriptionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _planNameController = TextEditingController();
  final _descController = TextEditingController();
  final _itemNameController = TextEditingController();
  final _itemPriceController = TextEditingController();
  final _itemQtyController = TextEditingController(text: '1');
  final _customerIdController = TextEditingController();
  final _uuid = const Uuid();

  String _billingCycle = 'MONTHLY';
  final List<SubscriptionItem> _items = [];

  @override
  void dispose() {
    _planNameController.dispose();
    _descController.dispose();
    _itemNameController.dispose();
    _itemPriceController.dispose();
    _itemQtyController.dispose();
    _customerIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.autorenew, color: FuturisticColors.primary),
          const SizedBox(width: 8),
          const Text('New Subscription'),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _planNameController,
                  decoration: const InputDecoration(
                    labelText: 'Plan Name *',
                    hintText: 'e.g. Monthly Web Maintenance',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Plan name required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _customerIdController,
                  decoration: const InputDecoration(
                    labelText: 'Customer ID *',
                    hintText: 'Enter existing customer ID',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Customer ID required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _billingCycle,
                  decoration: const InputDecoration(
                    labelText: 'Billing Cycle',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'DAILY', child: Text('Daily')),
                    DropdownMenuItem(value: 'WEEKLY', child: Text('Weekly')),
                    DropdownMenuItem(value: 'MONTHLY', child: Text('Monthly')),
                    DropdownMenuItem(value: 'YEARLY', child: Text('Yearly')),
                  ],
                  onChanged: (v) => setState(() => _billingCycle = v!),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Line Items',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: FuturisticColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _itemNameController,
                        decoration: const InputDecoration(
                          labelText: 'Item Name',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _itemQtyController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Qty',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _itemPriceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Price (â‚¹)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _addItem,
                      icon: Icon(
                        Icons.add_circle,
                        color: FuturisticColors.primary,
                      ),
                    ),
                  ],
                ),
                if (_items.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ..._items.asMap().entries.map((entry) {
                    final i = entry.key;
                    final item = entry.value;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.productName),
                      subtitle: Text(
                        '${item.quantity} Ã— â‚¹${item.unitPrice.toStringAsFixed(2)}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.remove_circle_outline,
                          color: Colors.red,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _items.removeAt(i)),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: FuturisticColors.primary,
          ),
          onPressed: _saveSubscription,
          child: const Text('CREATE', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  void _addItem() {
    final name = _itemNameController.text.trim();
    final price = double.tryParse(_itemPriceController.text) ?? 0;
    final qty = double.tryParse(_itemQtyController.text) ?? 1;

    if (name.isEmpty || price <= 0) return;

    setState(() {
      _items.add(
        SubscriptionItem(
          id: _uuid.v4(),
          subscriptionId: '', // Will be set by repository
          productName: name,
          quantity: qty,
          unitPrice: price,
          totalAmount: qty * price,
          createdAt: DateTime.now(),
        ),
      );
      _itemNameController.clear();
      _itemPriceController.clear();
      _itemQtyController.text = '1';
    });
  }

  Future<void> _saveSubscription() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one line item.')),
      );
      return;
    }

    final now = DateTime.now();
    final subId = _uuid.v4();

    final subscription = Subscription(
      id: subId,
      userId: widget.userId,
      customerId: _customerIdController.text.trim(),
      planName: _planNameController.text.trim(),
      description: _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
      billingCycle: _billingCycle,
      startDate: now,
      nextBillingDate: now,
      createdAt: now,
      updatedAt: now,
      items: _items,
    );

    try {
      await sl<SubscriptionRepository>().saveSubscription(subscription);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('âœ… Subscription created!'),
          backgroundColor: FuturisticColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
