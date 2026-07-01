// ============================================================================
// CUSTOMER PROFILE SCREEN (MODERN + FEATURES)
// ============================================================================
// Core customer profile with:
// - Time-based gradient theme
// - Financial Summary
// - Account Management (Edit Profile, My Shops)
// - Settings (Theme, Language, Security)
// - Support (Help, Terms, Share)
//
// Author: DukanX Engineering
// Version: 3.1.0 (Feature Complete)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/routing/route_paths.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../providers/app_state_providers.dart';

import '../../../../widgets/glass_morphism.dart';
import '../../../../widgets/modern_ui_components.dart';
import '../controllers/customer_profile_controller.dart';

// Feature Screens
import 'edit_profile_screen.dart';
import 'my_shops_screen.dart';
import 'security_settings_screen.dart';
import 'support_screens.dart';
import 'notification_settings_screen.dart';
import 'customer_invoice_list_screen.dart';

import 'package:url_launcher/url_launcher.dart';

// Credit Network
import '../../../credit_network/data/credit_network_repository.dart';
import '../../../credit_network/presentation/widgets/credit_score_widget.dart';
import 'package:dukanx/core/responsive/responsive.dart';

// Prescriptions

class CustomerProfileScreen extends ConsumerStatefulWidget {
  final String customerId;

  const CustomerProfileScreen({super.key, required this.customerId});

  @override
  ConsumerState<CustomerProfileScreen> createState() =>
      _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends ConsumerState<CustomerProfileScreen>
    with SingleTickerProviderStateMixin {
  late CustomerProfileController _controller;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  // Udhar Circle
  double _trustScore = 100.0;
  bool _isScoreLoading = true;

  @override
  void initState() {
    super.initState();
    final session = sl<SessionManager>();
    _controller = CustomerProfileController(
      customerId: widget.customerId,
      ownerId: session.ownerId!, // Use linked owner ID
    );

    _controller.addListener(() {
      if (mounted) setState(() {});
    });

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);

    // Initial data fetch
    _refreshData();
  }

  Future<void> _refreshData() async {
    await _controller.fetchData();
    if (mounted) _animController.forward();

    // Fetch Trust Score
    if (_controller.customer?.phone != null) {
      final repo = sl<CreditNetworkRepository>();
      final profile = await repo.getCreditProfile(_controller.customer!.phone!);
      if (mounted) {
        setState(() {
          _trustScore = profile?.trustScore ?? 100.0;
          _isScoreLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = sl<SessionManager>();

    // Determine Time-Based Gradient
    final timeTheme = _TimeTheme.current;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          "My Profile",
          style: AppTypography.headlineSmall.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationSettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: timeTheme.gradientColors,
            ),
          ),
          child: _controller.isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : RefreshIndicator(
                  onRefresh: _refreshData,
                  color: timeTheme.primaryColor,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 100, 20, 20),
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: Column(
                        children: [
                          // 1. Profile Header
                          _buildProfileHeader(session),

                          const SizedBox(height: 24),

                          // 2. Financial Summary Card
                          _buildFinancialCard(timeTheme),

                          const SizedBox(height: 24),

                          // 3. Menu Grid
                          _buildMenuSection(context, ref, timeTheme),

                          const SizedBox(height: 40),

                          // 4. Logout
                          _buildLogoutButton(context),

                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(SessionManager session) {
    final customer = _controller.customer;
    if (customer == null) return const SizedBox.shrink();

    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.5),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const CircleAvatar(
                radius: 50,
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 50, color: Colors.grey),
                // backgroundImage: customer.photoUrl != null ? NetworkImage(customer.photoUrl!) : null,
              ),
            ),
            GestureDetector(
              onTap: _navigateToEditProfile,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit, size: 16, color: Colors.white),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          customer.name,
          style: AppTypography.headlineMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [
              Shadow(color: Colors.black.withOpacity(0.3), blurRadius: 10),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          customer.phone ?? "No phone linked",
          style: AppTypography.bodyLarge.copyWith(
            color: Colors.white.withOpacity(0.9),
          ),
        ),
        if (customer.address != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              customer.address!,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyMedium.copyWith(
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ),

        const SizedBox(height: 12),
        // Trust Score Ring
        CreditScoreWidget(score: _trustScore, isLoading: _isScoreLoading),
      ],
    );
  }

  Widget _buildFinancialCard(_TimeTheme theme) {
    final snap = _controller.financialSnapshot;
    return GestureDetector(
      onTap: _navigateToInvoices,
      child: GlassContainer(
        borderRadius: 24,
        blur: 10,
        border: Border.all(color: Colors.white.withOpacity(0.2)),
        child: Column(
          children: [
            Text(
              "Total Outstanding",
              style: AppTypography.headlineSmall.copyWith(
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "â‚¹${snap.outstandingBalance.toStringAsFixed(2)}",
              style: AppTypography.displayMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                _buildFinStat(
                  "Total Paid",
                  "â‚¹${snap.totalReceived.toStringAsFixed(0)}",
                  Icons.check_circle_outline,
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.white.withOpacity(0.2),
                ),
                _buildFinStat(
                  "Bills",
                  "${_controller.state.insights.totalTransactions}",
                  Icons.receipt_long,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Center(
                child: Text(
                  "Tap to view details", // Call to action
                  style: AppTypography.bodySmall.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinStat(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.headlineSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(color: Colors.white60),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(
    BuildContext context,
    WidgetRef ref,
    _TimeTheme theme,
  ) {
    return Column(
      children: [
        _buildMenuCategory("Account", [
          _buildMenuItem(
            icon: Icons.receipt_long,
            title: "My Orders & Bills",
            subtitle: "View invoices and payments",
            color: Colors.blueAccent, // Distinct color
            onTap: _navigateToInvoices,
          ),
          _buildMenuItem(
            icon: Icons.store,
            title: "My Shops",
            subtitle: "Manage linked shops",
            color: Colors.orange,
            onTap: () =>
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyShopsScreen()),
                ).then(
                  (_) => _refreshData(),
                ), // Refresh on return in case of switch
          ),
          _buildMenuItem(
            icon: Icons.person_outline,
            title: "Personal Details",
            subtitle: "Name, address, phone",
            color: Colors.blue,
            onTap: _navigateToEditProfile,
          ),
        ]),
        const SizedBox(height: 16),
        _buildMenuCategory("Preferences", [
          _buildMenuItem(
            icon: Icons.language,
            title: "Language",
            subtitle: "English (Change)",
            color: Colors.purple,
            onTap: () => _showLanguageDialog(context, ref),
          ),
          _buildSwitchMenuItem(
            ref: ref,
            icon: Icons.dark_mode_outlined,
            title: "Dark Mode",
            color: Colors.indigo,
          ),
          _buildMenuItem(
            icon: Icons.notifications_outlined,
            title: "Notifications",
            subtitle: "Offers, Updates",
            color: Colors.amber,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NotificationSettingsScreen(),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        _buildMenuCategory("Support", [
          _buildMenuItem(
            icon: Icons.call,
            title: "Contact Shop",
            subtitle: "Call or WhatsApp",
            color: Colors.green, // Contact color
            onTap: _contactShop,
          ),
          _buildMenuItem(
            icon: Icons.lock_outline,
            title: "Security",
            subtitle: "App lock, password",
            color: Colors.red,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SecuritySettingsScreen()),
            ),
          ),
          _buildMenuItem(
            icon: Icons.help_outline,
            title: "Help & FAQ",
            subtitle: "Common questions",
            color: Colors.teal,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HelpScreen()),
            ),
          ),
          _buildMenuItem(
            icon: Icons.share_outlined,
            title: "Tell a Friend",
            subtitle: "Share the app",
            color: Colors.pink,
            onTap: () => Share.share(
              "Check out DukanX for managing your local shop bills! https://dukanx.com",
            ),
          ),
          _buildMenuItem(
            icon: Icons.policy_outlined,
            title: "Terms & Privacy",
            subtitle: "Read policies",
            color: Colors.grey,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TermsScreen()),
            ),
          ),
        ]),
        // Risk Management Removed (Vendor Only Feature)
      ],
    );
  }

  Widget _buildMenuCategory(String title, List<Widget> children) {
    return GlassContainer(
      borderRadius: 20,
      blur: 10,
      color: Colors.white.withOpacity(0.85),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              title.toUpperCase(),
              style: AppTypography.labelLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
                letterSpacing: 1.2,
              ),
            ),
          ),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        title,
        style: AppTypography.headlineSmall.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: AppTypography.bodyMedium.copyWith(color: Colors.grey[600]),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Colors.grey,
      ),
    );
  }

  Widget _buildSwitchMenuItem({
    required WidgetRef ref,
    required IconData icon,
    required String title,
    required Color color,
  }) {
    final themeState = ref.watch(themeStateProvider);
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        title,
        style: AppTypography.headlineSmall.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Switch.adaptive(
        value: themeState.isDark,
        onChanged: (val) {
          ref.read(themeStateProvider.notifier).setDarkMode(val);
        },
        activeColor: color,
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: () async {
          await sl<SessionManager>().signOut();
          if (context.mounted) {
            // Migrated AD-5: stack-clearing pushNamedAndRemoveUntil('/login')
            // -> context.go(RoutePaths.login) under MaterialApp.router.
            context.go(RoutePaths.login);
          }
        },
        icon: const Icon(Icons.logout, color: Colors.white70),
        label: Text(
          "Sign Out",
          style: AppTypography.headlineSmall.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 20),
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(
          "Select Language",
          style: AppTypography.headlineMedium.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        children: [
          _langOption(context, ref, 'English', 'en'),
          _langOption(context, ref, 'à¤¹à¤¿à¤¨à¥à¤¦à¥€', 'hi'),
          _langOption(context, ref, 'à¤®à¤°à¤¾à¤ à¥€', 'mr'),
          _langOption(context, ref, 'àª—à«àªœàª°àª¾àª¤à«€', 'gu'),
        ],
      ),
    );
  }

  Widget _langOption(
    BuildContext context,
    WidgetRef ref,
    String name,
    String code,
  ) {
    return SimpleDialogOption(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      child: Text(name, style: AppTypography.headlineSmall),
      onPressed: () {
        ref.read(localeStateProvider.notifier).setLocale(Locale(code));
        Navigator.pop(context);
      },
    );
  }

  void _navigateToInvoices() {
    // Navigate to invoices list
    // valid customerId is guaranteed by widget.customerId
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerInvoiceListScreen(
          customerId: widget.customerId,
          vendorId: _controller.ownerId, // Filter by current shop context
        ),
      ),
    );
  }

  void _navigateToEditProfile() async {
    final customer = _controller.customer;
    if (customer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile data not available yet. Please wait...'),
        ),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(currentProfile: customer),
      ),
    );

    if (result == true) {
      _refreshData();
    }
  }

  Future<void> _contactShop() async {
    // In a real app, you'd fetch the shop's phone number from the current session/shop data.
    // Since we don't have the shop phone readily available in _controller (it only has customer data),
    // we'll try to find it or show a placeholder.
    // For now, let's assume we can get it from the connection or session.

    // Default support number implementation:
    const phoneNumber = '919999999999'; // Default support
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);

    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not launch dialer")),
        );
      }
    }
  }
}

class _TimeTheme {
  final List<Color> gradientColors;
  final Color primaryColor;

  const _TimeTheme(this.gradientColors, this.primaryColor);

  static _TimeTheme get current {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return const _TimeTheme([
        Color(0xFF4CA1AF),
        Color(0xFFC4E0E5),
      ], Color(0xFF4CA1AF));
    } else if (hour < 17) {
      return const _TimeTheme([
        Color(0xFF56CCF2),
        Color(0xFF2F80ED),
      ], Color(0xFF2F80ED));
    } else if (hour < 20) {
      return const _TimeTheme([
        Color(0xFFFF512F),
        Color(0xFFDD2476),
      ], Color(0xFFDD2476));
    } else {
      return const _TimeTheme([
        Color(0xFF0F2027),
        Color(0xFF203A43),
        Color(0xFF2C5364),
      ], Color(0xFF2C5364));
    }
  }
}
