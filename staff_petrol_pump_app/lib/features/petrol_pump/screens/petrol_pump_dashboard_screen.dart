import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_provider.dart';
import '../../../core/auth/token_storage.dart';
import '../providers/providers.dart';
import '../theme/fuelpos_theme.dart';
import '../widgets/widgets.dart';

// ── Header helper widgets ────────────────────────────────────────────────────

/// Animated search field with focus-glow ring
class _FuelPosSearchField extends StatefulWidget {
  @override
  State<_FuelPosSearchField> createState() => _FuelPosSearchFieldState();
}

class _FuelPosSearchFieldState extends State<_FuelPosSearchField> {
  final FocusNode _fn = FocusNode();
  final ValueNotifier<bool> _focused = ValueNotifier(false);
  final ValueNotifier<bool> _hovered = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _fn.addListener(() => _focused.value = _fn.hasFocus);
  }

  @override
  void dispose() {
    _fn.dispose();
    _focused.dispose();
    _hovered.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _hovered.value = true,
      onExit: (_) => _hovered.value = false,
      child: ValueListenableBuilder<bool>(
        valueListenable: _focused,
        builder: (context, isFocused, _) => ValueListenableBuilder<bool>(
          valueListenable: _hovered,
          builder: (context, isHovered, _) {
            final accent = FuelPOSTheme.petrolBlue;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 260,
              height: 38,
              decoration: BoxDecoration(
                color: isFocused
                    ? accent.withValues(alpha: 0.07)
                    : FuelPOSTheme.cardDark,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: isFocused
                      ? accent
                      : isHovered
                          ? accent.withValues(alpha: 0.45)
                          : FuelPOSTheme.borderDark,
                  width: isFocused ? 1.5 : 1,
                ),
                boxShadow: isFocused
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.2),
                          blurRadius: 12,
                        )
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  Icon(
                    Icons.search_rounded,
                    size: 16,
                    color: isFocused ? accent : FuelPOSTheme.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      focusNode: _fn,
                      style: const TextStyle(
                        color: FuelPOSTheme.textPrimary,
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search transactions...',
                        hintStyle: const TextStyle(
                          color: FuelPOSTheme.textMuted,
                          fontSize: 13,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Hoverable icon button for the header
class _FuelPosIconBtn extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _FuelPosIconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_FuelPosIconBtn> createState() => _FuelPosIconBtnState();
}

class _FuelPosIconBtnState extends State<_FuelPosIconBtn> {
  final ValueNotifier<bool> _hovered = ValueNotifier(false);

  @override
  void dispose() {
    _hovered.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => _hovered.value = true,
        onExit: (_) => _hovered.value = false,
        child: GestureDetector(
          onTap: widget.onTap,
          child: ValueListenableBuilder<bool>(
            valueListenable: _hovered,
            builder: (context, isHovered, _) => AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isHovered
                    ? FuelPOSTheme.petrolBlue.withValues(alpha: 0.12)
                    : FuelPOSTheme.cardDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isHovered
                      ? FuelPOSTheme.petrolBlue.withValues(alpha: 0.4)
                      : FuelPOSTheme.borderDark,
                ),
              ),
              child: Icon(
                widget.icon,
                size: 18,
                color: isHovered
                    ? FuelPOSTheme.petrolBlue
                    : FuelPOSTheme.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Gradient CTA button (New Payment, etc.)
class _FuelPosCTAButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _FuelPosCTAButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_FuelPosCTAButton> createState() => _FuelPosCTAButtonState();
}

class _FuelPosCTAButtonState extends State<_FuelPosCTAButton> {
  final ValueNotifier<bool> _hovered = ValueNotifier(false);

  @override
  void dispose() {
    _hovered.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _hovered.value = true,
      onExit: (_) => _hovered.value = false,
      child: GestureDetector(
        onTap: widget.onTap,
        child: ValueListenableBuilder<bool>(
          valueListenable: _hovered,
          builder: (context, isHovered, _) => AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            transform:
                Matrix4.translationValues(0, isHovered ? -1.5 : 0, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  FuelPOSTheme.primaryGreen.withValues(
                      alpha: isHovered ? 1.0 : 0.88),
                  FuelPOSTheme.primaryGreen.withValues(alpha: 0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(9),
              boxShadow: isHovered
                  ? [
                      BoxShadow(
                        color:
                            FuelPOSTheme.primaryGreen.withValues(alpha: 0.4),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 16, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Notification bell with badge
class _FuelPosNotificationBtn extends StatefulWidget {
  @override
  State<_FuelPosNotificationBtn> createState() =>
      _FuelPosNotificationBtnState();
}

class _FuelPosNotificationBtnState extends State<_FuelPosNotificationBtn> {
  final ValueNotifier<bool> _hovered = ValueNotifier(false);

  @override
  void dispose() {
    _hovered.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _hovered.value = true,
      onExit: (_) => _hovered.value = false,
      child: GestureDetector(
        onTap: () {},
        child: ValueListenableBuilder<bool>(
          valueListenable: _hovered,
          builder: (context, isHovered, _) => AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isHovered
                  ? FuelPOSTheme.petrolBlue.withValues(alpha: 0.1)
                  : FuelPOSTheme.cardDark,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isHovered
                    ? FuelPOSTheme.petrolBlue.withValues(alpha: 0.35)
                    : FuelPOSTheme.borderDark,
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(
                  child: Icon(
                    Icons.notifications_outlined,
                    size: 18,
                    color: isHovered
                        ? FuelPOSTheme.petrolBlue
                        : FuelPOSTheme.textSecondary,
                  ),
                ),
                Positioned(
                  top: 5,
                  right: 5,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: FuelPOSTheme.primaryRed,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: FuelPOSTheme.primaryRed
                              .withValues(alpha: 0.6),
                          blurRadius: 4,
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hoverable user avatar chip with dropdown
class _FuelPosAvatarChip extends StatefulWidget {
  final VoidCallback onLogout;

  const _FuelPosAvatarChip({required this.onLogout});

  @override
  State<_FuelPosAvatarChip> createState() => _FuelPosAvatarChipState();
}

class _FuelPosAvatarChipState extends State<_FuelPosAvatarChip> {
  final ValueNotifier<bool> _hovered = ValueNotifier(false);

  @override
  void dispose() {
    _hovered.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _hovered.value = true,
      onExit: (_) => _hovered.value = false,
      child: ValueListenableBuilder<bool>(
        valueListenable: _hovered,
        builder: (context, isHovered, _) {
          return PopupMenuButton<String>(
            color: FuelPOSTheme.cardDark,
            offset: const Offset(0, 44),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: Row(children: [
                  Icon(Icons.person_outline,
                      size: 16, color: FuelPOSTheme.textSecondary),
                  const SizedBox(width: 10),
                  Text('Profile',
                      style:
                          const TextStyle(color: FuelPOSTheme.textPrimary)),
                ]),
              ),
              PopupMenuItem(
                value: 'settings',
                child: Row(children: [
                  Icon(Icons.settings_outlined,
                      size: 16, color: FuelPOSTheme.textSecondary),
                  const SizedBox(width: 10),
                  Text('Settings',
                      style:
                          const TextStyle(color: FuelPOSTheme.textPrimary)),
                ]),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'logout',
                child: Row(children: [
                  Icon(Icons.logout_rounded,
                      size: 16, color: FuelPOSTheme.errorRed),
                  const SizedBox(width: 10),
                  Text('Logout',
                      style: TextStyle(color: FuelPOSTheme.errorRed)),
                ]),
              ),
            ],
            onSelected: (value) {
              if (value == 'logout') widget.onLogout();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isHovered
                    ? FuelPOSTheme.petrolBlue.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isHovered
                      ? FuelPOSTheme.petrolBlue.withValues(alpha: 0.3)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          FuelPOSTheme.petrolBlue,
                          FuelPOSTheme.dieselOrange,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: isHovered
                          ? [
                              BoxShadow(
                                color: FuelPOSTheme.petrolBlue
                                    .withValues(alpha: 0.4),
                                blurRadius: 10,
                              )
                            ]
                          : null,
                    ),
                    child: const Icon(Icons.person_rounded,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Admin',
                        style: TextStyle(
                          color: isHovered
                              ? FuelPOSTheme.textPrimary
                              : FuelPOSTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Text(
                        'John Doe',
                        style: TextStyle(
                          color: FuelPOSTheme.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: isHovered ? 0.5 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      Icons.expand_more_rounded,
                      size: 16,
                      color: isHovered
                          ? FuelPOSTheme.petrolBlue
                          : FuelPOSTheme.textMuted,
                    ),
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

/// Petrol Pump Dashboard Screen - Main dashboard for fuel station management
class PetrolPumpDashboardScreen extends ConsumerStatefulWidget {
  const PetrolPumpDashboardScreen({super.key});

  @override
  ConsumerState<PetrolPumpDashboardScreen> createState() =>
      _PetrolPumpDashboardScreenState();
}

class _PetrolPumpDashboardScreenState
    extends ConsumerState<PetrolPumpDashboardScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    // Ensure license is loaded
    await ref.read(licenseProvider.notifier).fetchLicenseProfile();

    // Load all dashboard data
    await Future.wait([
      ref.read(dashboardSummaryProvider.notifier).refresh(),
      ref.read(fuelChartProvider.notifier).loadChartData(),
      ref.read(transactionsProvider.notifier).loadTransactions(),
      ref.read(revenueProvider.notifier).loadRevenueData(),
      ref.read(alertsProvider.notifier).loadAlerts(),
    ]);
  }

  Future<void> _onDateChanged(DateTime date) async {
    setState(() {
      _selectedDate = date;
    });

    // Reload data with new date
    ref.read(dashboardSummaryProvider.notifier).refresh();
    ref.read(fuelChartProvider.notifier).setDate(date);
    ref.read(transactionsProvider.notifier).setDate(date);
    ref.read(revenueProvider.notifier).loadRevenueData(date: date);
  }

  Future<void> _refreshAll() async {
    ref.read(dashboardSummaryProvider.notifier).forceRefresh();
    ref.read(fuelChartProvider.notifier).refresh();
    ref.read(transactionsProvider.notifier).refresh();
    ref.read(revenueProvider.notifier).refresh();
    ref.read(alertsProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final license = ref.watch(licenseProvider);
    final lastUpdated = ref.watch(lastUpdatedProvider);

    // Show loading if license hasn't been fetched
    if (!license.hasFetched || license.isLoading) {
      return Scaffold(
        backgroundColor: FuelPOSTheme.backgroundDark,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Loading station data...',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: FuelPOSTheme.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    // Show error if license failed to load
    if (license.error != null || license.profile == null) {
      return Scaffold(
        backgroundColor: FuelPOSTheme.backgroundDark,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: FuelPOSTheme.errorRed,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                license.error ?? 'Failed to load license profile',
                style: const TextStyle(color: FuelPOSTheme.textSecondary),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _initializeData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: FuelPOSTheme.backgroundDark,
      body: Row(
        children: [
          // Sidebar
          SidebarNavWidget(
            currentRoute: '/dashboard/petrol-pump',
          ),

          // Main content
          Expanded(
            child: Column(
              children: [
                // Header
                _buildHeader(lastUpdated),

                // Dashboard content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // KPI Cards Row
                        _buildKpiCards(),
                        const SizedBox(height: 24),

                        // Main content area
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left side (2/3 width)
                            Expanded(
                              flex: 2,
                              child: Column(
                                children: [
                                  // Fuel Sales Chart
                                  SizedBox(
                                    height: 380,
                                    child: FuelSalesChartWidget(
                                      selectedDate: _selectedDate,
                                      onDateChanged: _onDateChanged,
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  // Recent Transactions
                                  SizedBox(
                                    height: 400,
                                    child: TransactionTableWidget(
                                      selectedDate: _selectedDate,
                                      onDateChanged: _onDateChanged,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 24),

                            // Right side (1/3 width)
                            Expanded(
                              child: Column(
                                children: [
                                  // Revenue Donut Chart
                                  const SizedBox(
                                    height: 320,
                                    child: RevenueDonutWidget(),
                                  ),
                                  const SizedBox(height: 24),

                                  // Alerts Panel
                                  SizedBox(
                                    height: 300,
                                    child: AlertsPanelWidget(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String? lastUpdated) {
    final stationName =
        ref.watch(licenseProvider).profile?.stationName ?? 'Station';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: FuelPOSTheme.surfaceDark,
        border: Border(
          bottom: BorderSide(
            color: FuelPOSTheme.petrolBlue.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: FuelPOSTheme.petrolBlue.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Station icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  FuelPOSTheme.petrolBlue.withValues(alpha: 0.25),
                  FuelPOSTheme.dieselOrange.withValues(alpha: 0.12),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: FuelPOSTheme.petrolBlue.withValues(alpha: 0.4),
              ),
            ),
            child: const Icon(
              Icons.local_gas_station_rounded,
              size: 16,
              color: FuelPOSTheme.petrolBlue,
            ),
          ),
          const SizedBox(width: 10),
          // Breadcrumbs
          Text(
            'FuelPOS',
            style: TextStyle(
              color: FuelPOSTheme.textMuted,
              fontSize: 13,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Icon(
              Icons.chevron_right_rounded,
              color: FuelPOSTheme.textMuted,
              size: 16,
            ),
          ),
          Text(
            stationName,
            style: const TextStyle(
              color: FuelPOSTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),

          const Spacer(),

          // Search with focus glow
          _FuelPosSearchField(),
          const SizedBox(width: 16),

          // Last updated
          if (lastUpdated != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: FuelPOSTheme.cardDark,
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: FuelPOSTheme.borderDark),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 12,
                    color: FuelPOSTheme.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    lastUpdated,
                    style: const TextStyle(
                      color: FuelPOSTheme.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(width: 8),

          // Refresh button
          _FuelPosIconBtn(
            icon: Icons.refresh_rounded,
            tooltip: 'Refresh data',
            onTap: _refreshAll,
          ),
          const SizedBox(width: 8),

          // Quick QR Payment button
          _FuelPosCTAButton(
            icon: Icons.qr_code_scanner_rounded,
            label: 'New Payment',
            onTap: () => context.go('/qr/entry'),
          ),
          const SizedBox(width: 8),

          // Notifications
          _FuelPosNotificationBtn(),
          const SizedBox(width: 12),

          // User avatar chip
          _FuelPosAvatarChip(
            onLogout: () async {
              await ref.read(authStateProvider.notifier).signOut();
              await TokenStorage.clearTokens();
              if (mounted) context.go('/login');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCards() {
    final todaySales = ref.watch(todaySalesProvider);
    final fuelSold = ref.watch(fuelSoldProvider);
    final transactions = ref.watch(dashboardSummaryProvider).summary?.totalTransactions;
    final inventory = ref.watch(inventoryProvider);

    return KpiRowWidget(
      children: [
        // Today's Sales
        KpiCardWidget(
          title: "Today's Sales",
          value: todaySales?.formattedTotal ?? '₹0.00',
          changePercent: todaySales?.changePercent,
          isPositiveChange: todaySales?.isPositive ?? true,
          icon: Icons.trending_up,
          accentColor: FuelPOSTheme.primaryGreen,
        ),

        // Fuel Sold
        KpiCardWidget(
          title: 'Fuel Sold (Liters)',
          value: fuelSold?.formattedTotal ?? '0 L',
          subtitle: fuelSold != null
              ? 'Petrol ${fuelSold.formattedPetrol} | Diesel ${fuelSold.formattedDiesel}'
              : null,
          icon: Icons.local_gas_station,
          accentColor: FuelPOSTheme.petrolBlue,
        ),

        // Total Transactions
        KpiCardWidget(
          title: 'Total Transactions',
          value: transactions?.formattedCount ?? '0',
          changePercent: transactions?.changePercent,
          isPositiveChange: transactions?.isPositive ?? true,
          icon: Icons.receipt_long,
          accentColor: FuelPOSTheme.primaryOrange,
        ),

        // Current Inventory
        KpiCardWidget(
          title: 'Current Inventory',
          value: inventory != null
              ? 'P: ${inventory.petrol.percent}% | D: ${inventory.diesel.percent}%'
              : '-',
          subtitle: inventory != null
              ? 'Petrol: ${inventory.petrol.formattedLiters} | Diesel: ${inventory.diesel.formattedLiters}'
              : null,
          icon: Icons.inventory_2,
          accentColor: inventory?.petrol.isLow ?? false
              ? FuelPOSTheme.errorRed
              : FuelPOSTheme.successGreen,
        ),
      ],
    );
  }
}
