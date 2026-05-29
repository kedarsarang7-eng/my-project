import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dukanx_shared/dukanx_shared.dart';
import '../../../../core/auth/customer_session_manager.dart';
import '../../../../core/navigation/app_router.dart';
import '../../../../core/websocket/customer_ws_service.dart';
import '../../../../core/websocket/ws_event_handler.dart';
import '../../data/home_repository.dart';

class CustomerHomeScreen extends ConsumerStatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  ConsumerState<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends ConsumerState<CustomerHomeScreen> {
  WsEventHandler? _wsEventHandler;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ws = ref.read(customerWsServiceProvider);
      _wsEventHandler = WsEventHandler(ref, ws);
    });
  }

  @override
  void dispose() {
    _wsEventHandler?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(customerSessionProvider).valueOrNull;
    final summary = ref.watch(homeSummaryProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              snap: true,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello, ${session?.profile?.displayName.split(' ').first ?? 'there'} 👋',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    'Here\'s your account overview',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () => context.push(AppRoutes.notifications),
                ),
                IconButton(
                  icon: const Icon(Icons.person_outline_rounded),
                  onPressed: () => context.push(AppRoutes.profile),
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  summary.when(
                    data: (data) => _SummarySection(data: data),
                    loading: () => const ListLoadingShimmer(itemCount: 2, itemHeight: 100),
                    error: (e, _) => ErrorStateWidget(
                      message: 'Could not load summary',
                      onRetry: () => ref.invalidate(homeSummaryProvider),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _QuickActions(),
                  const SizedBox(height: 24),
                  _ShopsSection(),
                ]),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (i) => _navigate(context, i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Invoices',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Ledger',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  void _navigate(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.home);
      case 1:
        context.go(AppRoutes.invoices);
      case 2:
        context.go(AppRoutes.ledger);
      case 3:
        context.go(AppRoutes.profile);
    }
  }
}

class _SummarySection extends StatelessWidget {
  final HomeSummary data;
  const _SummarySection({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CustomerBalanceCard(
          totalDue: data.totalDue,
          totalPaid: data.totalPaid,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Linked Shops',
                value: data.linkedShopsCount.toString(),
                icon: Icons.storefront_rounded,
                color: const Color(0xFF1565C0),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Pending Invoices',
                value: data.pendingInvoiceCount.toString(),
                icon: Icons.receipt_outlined,
                color: const Color(0xFFE53935),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatefulWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  final ValueNotifier<bool> _hovered = ValueNotifier(false);

  @override
  void dispose() {
    _hovered.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => _hovered.value = true,
      onExit: (_) => _hovered.value = false,
      child: ValueListenableBuilder<bool>(
        valueListenable: _hovered,
        builder: (context, isHovered, _) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(0, isHovered ? -2.5 : 0, 0),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isHovered
                    ? widget.color.withValues(alpha: 0.45)
                    : cs.outline.withValues(alpha: 0.25),
                width: isHovered ? 1.4 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.color
                      .withValues(alpha: isHovered ? 0.16 : 0.06),
                  blurRadius: isHovered ? 18 : 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          widget.color.withValues(alpha: 0.22),
                          widget.color.withValues(alpha: 0.1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: widget.color.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Icon(widget.icon, color: widget.color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.value,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: widget.color,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        widget.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurfaceVariant,
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
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _ActionChip(
              icon: Icons.shopping_bag_rounded,
              label: 'Shop Online',
              color: Colors.orange,
              onTap: () => context.push(AppRoutes.storeDiscovery),
            ),
            const SizedBox(width: 8),
            _ActionChip(
              icon: Icons.payment_rounded,
              label: 'Pay Due',
              onTap: () => context.push(AppRoutes.recordPayment),
            ),
            const SizedBox(width: 8),
            _ActionChip(
              icon: Icons.receipt_long_rounded,
              label: 'Invoices',
              onTap: () => context.push(AppRoutes.invoices),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _SelfCheckoutBanner(),
      ],
    );
  }
}

class _SelfCheckoutBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push(AppRoutes.inStoreLanding),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1B5E20), Color(0xFF388E3C)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.qr_code_scanner_rounded,
                  color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Self Scan & Checkout',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                  Text('Skip the queue — scan, pay & go',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  State<_ActionChip> createState() => _ActionChipState();
}

class _ActionChipState extends State<_ActionChip> {
  final ValueNotifier<bool> _hovered = ValueNotifier(false);

  @override
  void dispose() {
    _hovered.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = widget.color ?? cs.primary;

    return Expanded(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => _hovered.value = true,
        onExit: (_) => _hovered.value = false,
        child: GestureDetector(
          onTap: widget.onTap,
          child: ValueListenableBuilder<bool>(
            valueListenable: _hovered,
            builder: (context, isHovered, _) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOutCubic,
                transform:
                    Matrix4.translationValues(0, isHovered ? -2.5 : 0, 0),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isHovered
                      ? accent.withValues(alpha: 0.1)
                      : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isHovered
                        ? accent.withValues(alpha: 0.45)
                        : cs.outline.withValues(alpha: 0.15),
                    width: isHovered ? 1.4 : 1,
                  ),
                  boxShadow: isHovered
                      ? [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.18),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : null,
                ),
                child: Column(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            accent.withValues(alpha: 0.22),
                            accent.withValues(alpha: 0.08),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child:
                          Icon(widget.icon, color: accent, size: 20),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isHovered ? accent : cs.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ShopsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shops = ref.watch(recentShopsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'My Shops',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            TextButton(
              onPressed: () => context.push(AppRoutes.linkedShops),
              child: const Text('See all'),
            ),
          ],
        ),
        shops.when(
          data: (list) => list.isEmpty
              ? EmptyStateWidget(
                  icon: Icons.storefront_outlined,
                  title: 'No shops linked',
                  subtitle: 'Ask your vendor to link you to their shop',
                )
              : ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: list.take(3).length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _ShopTile(connection: list[i]),
                ),
          loading: () => const ListLoadingShimmer(itemCount: 3, itemHeight: 72),
          error: (_, _) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _ShopTile extends StatefulWidget {
  final VendorConnection connection;
  const _ShopTile({required this.connection});

  @override
  State<_ShopTile> createState() => _ShopTileState();
}

class _ShopTileState extends State<_ShopTile> {
  final ValueNotifier<bool> _hovered = ValueNotifier(false);

  @override
  void dispose() {
    _hovered.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasDue = widget.connection.outstandingBalance > 0;
    final accentColor = hasDue
        ? const Color(0xFFEF4444)
        : const Color(0xFF10B981);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _hovered.value = true,
      onExit: (_) => _hovered.value = false,
      child: GestureDetector(
        onTap: () => context.push(
            AppRoutes.ledger, extra: widget.connection.vendorId),
        child: ValueListenableBuilder<bool>(
          valueListenable: _hovered,
          builder: (context, isHovered, _) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              transform:
                  Matrix4.translationValues(0, isHovered ? -2.0 : 0, 0),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isHovered
                      ? cs.primary.withValues(alpha: 0.35)
                      : cs.outline.withValues(alpha: 0.2),
                  width: isHovered ? 1.4 : 1,
                ),
                boxShadow: isHovered
                    ? [
                        BoxShadow(
                          color: cs.primary.withValues(alpha: 0.1),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : null,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            cs.primary.withValues(alpha: 0.18),
                            cs.tertiary.withValues(alpha: 0.1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: cs.primary.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          widget.connection.vendorName
                              .substring(0, 1)
                              .toUpperCase(),
                          style: TextStyle(
                            color: cs.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.connection.vendorBusinessName ??
                                widget.connection.vendorName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: accentColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                hasDue
                                    ? 'Due: ${CurrencyFormatter.format(widget.connection.outstandingBalance)}'
                                    : 'No dues',
                                style: TextStyle(
                                  color: accentColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: isHovered ? cs.primary : cs.onSurfaceVariant,
                      size: 20,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
