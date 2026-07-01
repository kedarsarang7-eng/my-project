import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:dukanx/core/routing/route_paths.dart';
import '../services/owner_account_service.dart';

class ProfessionalStartupScreen extends StatefulWidget {
  const ProfessionalStartupScreen({super.key});

  @override
  State<ProfessionalStartupScreen> createState() =>
      _ProfessionalStartupScreenState();
}

class _ProfessionalStartupScreenState extends State<ProfessionalStartupScreen>
    with SingleTickerProviderStateMixin {
  late Future<bool> _ownerExistsFuture;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _ownerExistsFuture = _fetchOwnerExists();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<bool> _fetchOwnerExists() async {
    try {
      final exists = await ownerAccountService.ownerExists(
        timeout: const Duration(seconds: 6),
      );
      return exists;
    } on TimeoutException catch (_) {
      throw TimeoutException('Owner lookup timed out');
    } catch (e) {
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    final isTablet = size.width >= 600 && size.width < 1024;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1B5E20), // Deep green
              Color(0xFF00838F), // Teal
              Color(0xFF0277BD), // Blue
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Decorative circles
            Positioned(
              top: -80,
              right: -80,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.06),
                ),
              ),
            ),
            Positioned(
              bottom: -120,
              left: -60,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.04),
                ),
              ),
            ),
            Positioned(
              top: size.height * 0.4,
              right: -100,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.03),
                ),
              ),
            ),

            // Main content
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 24 : (isTablet ? 48 : 80),
                      vertical: 32,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Logo
                          _buildLogo(),
                          const SizedBox(height: 32),

                          // Title
                          Text(
                            'Dukan X',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: isMobile ? 42 : 52,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 2,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.3),
                                  offset: const Offset(0, 4),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Subtitle
                          Text(
                            'Smart Billing & Shop Management',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: isMobile ? 16 : 18,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.9),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 56),

                          // Login Cards
                          _buildAdminLoginCard(context),
                          const SizedBox(height: 20),
                          _buildCustomerLoginCard(context),

                          const SizedBox(height: 48),

                          // Footer
                          Text(
                            'Version 1.0',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.15),
        border: Border.all(color: Colors.white.withOpacity(0.4), width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Icon(
        Icons.storefront_rounded,
        size: 55,
        color: Colors.white,
      ),
    );
  }

  Widget _buildAdminLoginCard(BuildContext context) {
    return FutureBuilder<bool>(
      future: _ownerExistsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildGlassCard(
            icon: Icons.admin_panel_settings_rounded,
            iconColor: const Color(0xFFFFA000),
            title: 'Loading...',
            subtitle: 'Checking admin account status',
            onTap: null,
            isLoading: true,
          );
        }

        // Even on error, we allow owner potential login
        final exists = snapshot.data ?? false;

        return _buildGlassCard(
          icon: Icons.admin_panel_settings_rounded,
          iconColor: const Color(0xFFFFA000),
          title: "I'm a shop owner",
          subtitle: exists
              ? 'Login to manage your shop'
              : 'Create your admin account & setup shop',
          onTap: () {
            context.push(RoutePaths.login);
          },
        );
      },
    );
  }

  Widget _buildCustomerLoginCard(BuildContext context) {
    return _buildGlassCard(
      icon: Icons.person_rounded,
      iconColor: const Color(0xFF42A5F5),
      title: "I'm a customer",
      subtitle: 'View bills, check payments & shop details',
      onTap: () {
        context.push(RoutePaths.login);
      },
    );
  }

  Widget _buildGlassCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(30),
            splashColor: Colors.white.withOpacity(0.1),
            highlightColor: Colors.white.withOpacity(0.05),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                color: Colors.white.withOpacity(0.12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.25),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Icon container
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: iconColor.withOpacity(0.2),
                      border: Border.all(
                        color: iconColor.withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                    child: isLoading
                        ? Padding(
                            padding: const EdgeInsets.all(18),
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          )
                        : Icon(icon, color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 20),

                  // Text content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withOpacity(0.75),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Arrow
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.1),
                    ),
                    child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white.withOpacity(0.7),
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
