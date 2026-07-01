import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dukanx/core/routing/route_paths.dart';
import '../widgets/modern_ui_components.dart';
import '../core/theme/futuristic_colors.dart';

class CustomerAppViewModern extends StatefulWidget {
  final String phoneNumber;
  final bool isOwnerMode;

  const CustomerAppViewModern({
    required this.phoneNumber,
    this.isOwnerMode = false,
    super.key,
  });

  @override
  State<CustomerAppViewModern> createState() => _CustomerAppViewModernState();
}

class _CustomerAppViewModernState extends State<CustomerAppViewModern>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FuturisticColors.background,
      body: CustomScrollView(
        slivers: [
          // Modern AppBar with gradient
          SliverAppBar(
            expandedHeight: 250,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: FuturisticColors.secondary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      FuturisticColors.secondary,
                      FuturisticColors.primaryDark,
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: AppSpacing.lg),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person,
                          size: 50,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        widget.isOwnerMode ? 'Customer Account' : 'My Account',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        widget.phoneNumber,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyLarge?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
              centerTitle: true,
              collapseMode: CollapseMode.parallax,
            ),
            actions: [
              if (widget.isOwnerMode)
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Edit Due Amount',
                  onPressed: () => _showEditDuesDialog(context),
                ),
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Logout',
                onPressed: () => context.go(RoutePaths.splash),
              ),
            ],
          ),

          // Modern Tab Bar
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverTabBarDelegate(
              child: Container(
                color: FuturisticColors.surface,
                child: TabBar(
                  controller: _tabController,
                  labelColor: FuturisticColors.secondary,
                  unselectedLabelColor: FuturisticColors.textSecondary,
                  indicatorColor: FuturisticColors.secondary,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  tabs: const [
                    Tab(icon: Icon(Icons.receipt, size: 24), text: 'Bills'),
                    Tab(icon: Icon(Icons.info, size: 24), text: 'Info'),
                  ],
                ),
              ),
            ),
          ),

          // Tab Content
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [_buildBillsTab(context), _buildInfoTab(context)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillsTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          EmptyStateWidget(
            icon: Icons.receipt_long,
            title: 'No Bills Yet',
            description: 'Bills will appear here once created.',
            buttonLabel: widget.isOwnerMode ? 'Create Bill' : null,
            onButtonPressed: widget.isOwnerMode
                ? () => context.push('/advanced_bill_creation')
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Account Information',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.lg),
          ModernCard(
            child: Column(
              children: [
                ModernListTile(
                  leadingIcon: Icons.phone,
                  title: 'Phone Number',
                  subtitle: widget.phoneNumber,
                  showDivider: true,
                  iconColor: FuturisticColors.primary,
                ),
                const ModernListTile(
                  leadingIcon: Icons.account_balance_wallet,
                  title: 'Account Balance',
                  subtitle: '₹0.00',
                  showDivider: true,
                  iconColor: FuturisticColors.success,
                ),
                const ModernListTile(
                  leadingIcon: Icons.receipt,
                  title: 'Total Bills',
                  subtitle: '0',
                  showDivider: false,
                  iconColor: FuturisticColors.accent2,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Actions',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.md),
          ModernCard(
            child: Column(
              children: [
                ModernListTile(
                  leadingIcon: Icons.history,
                  title: 'Payment History',
                  subtitle: 'View all transactions',
                  onTap: () => context.push('/payment-history'),
                  iconColor: FuturisticColors.secondary,
                  showDivider: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDuesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Due Amount'),
        content: const TextField(
          decoration: InputDecoration(
            labelText: 'New Due Amount (₹)',
            prefixText: '₹ ',
          ),
          keyboardType: TextInputType.numberWithOptions(decimal: true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Due amount updated')),
              );
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _SliverTabBarDelegate({required this.child});

  @override
  double get minExtent => 56;

  @override
  double get maxExtent => 56;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}
