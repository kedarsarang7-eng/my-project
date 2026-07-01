import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:dukanx/core/compat/firebase_auth_compat.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:dukanx/core/routing/route_paths.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/auth/auth_intent_service.dart';
import '../../../../services/google_signin_service.dart';
import '../../data/auth_repository.dart';
import '../widgets/fast_login_options.dart';
import '../widgets/security_upgrade_prompt.dart';
import '../../../../core/repository/shop_link_repository.dart';
import '../../services/biometric_service.dart';
import '../../services/pin_service.dart';
import 'package:uuid/uuid.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Customer Authentication Screen - Matches reference design
/// Purple theme with space background
class CustomerAuthScreen extends StatefulWidget {
  const CustomerAuthScreen({super.key});

  @override
  State<CustomerAuthScreen> createState() => _CustomerAuthScreenState();
}

class _CustomerAuthScreenState extends State<CustomerAuthScreen>
    with TickerProviderStateMixin {
  // Controllers
  final _formKey = GlobalKey<FormState>();
  final _customerNameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // State
  bool _isLogin = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final _session = sl<SessionManager>();

  // Animation
  late AnimationController _glowController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  // Theme Colors - Purple for Customer
  static const _primaryPurple = Color(0xFFAB5CF6);
  static const _bgDark = Color(0xFF0B0D1F);

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _glowController.dispose();
    _fadeController.dispose();
    _customerNameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleAuth() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        await _handleLogin();
      } else {
        await _handleSignup();
      }
    } on FirebaseAuthException catch (e) {
      // Handle specific Firebase Auth errors
      String message = _getFirebaseAuthErrorMessage(e.code);
      _showError(message);
    } catch (e) {
      final errorStr = e.toString();
      // Check for App Check specific errors
      if (errorStr.contains('firebase-app-check-token-is-invalid') ||
          errorStr.contains('app-check')) {
        _showError(
          'Security verification failed. Please restart the app and try again.',
        );
        debugPrint('App Check Error: $e');
      } else {
        _showError(errorStr.replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Convert Firebase Auth error codes to user-friendly messages
  String _getFirebaseAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email. Please sign up first.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'Invalid email address format.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password is too weak. Use at least 8 characters.';
      case 'firebase-app-check-token-is-invalid':
        return 'Security verification failed. Please restart the app.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      default:
        return 'Authentication failed: $code';
    }
  }

  Future<void> _handleLogin() async {
    // Ensure intent is set (guard)
    await authIntent.initialize();
    if (!authIntent.isCustomerIntent) {
      throw Exception('Invalid flow. Please select Customer Dashboard first.');
    }

    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );

    // Wait for session to initialize and verify role
    await _session.refreshSession();

    if (!mounted) return;

    // STRICT ROLE VALIDATION
    final validationResult = authIntent.validateRole(
      _session.isOwner
          ? 'vendor'
          : _session.isCustomer
          ? 'customer'
          : null,
    );

    if (validationResult == RoleValidationResult.mismatch) {
      // BLOCK: Wrong login portal used
      final errorMessage = authIntent.getMismatchErrorMessage(
        _session.isOwner ? 'vendor' : 'unknown',
      );

      // Sign out immediately
      await FirebaseAuth.instance.signOut();
      await authIntent.clearIntent();

      throw Exception(errorMessage);
    }

    // SUCCESS: Clear intent and navigate to AuthGate for role-based routing
    await _linkToLockedShopIfNeeded();
    await authIntent.clearIntent();
    context.go(RoutePaths.authGate);
  }

  /// Auto-link to the locked vendor if in Customer-Only Mode
  Future<void> _linkToLockedShopIfNeeded() async {
    final lockedVendorId = _session.lockedVendorId;
    if (!_session.isCustomerOnlyMode || lockedVendorId == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final shopLinkRepo = sl<ShopLinkRepository>();

      // Check if already linked
      final isLinked = await shopLinkRepo.isLinked(
        customerId: user.uid,
        shopId: lockedVendorId,
      );

      if (!isLinked) {
        debugPrint(
          '[CustomerAuth] Auto-linking to locked vendor: $lockedVendorId',
        );
        // Retrieve shop details if possible (or use placeholders until sync)
        // For now we use the ID as name placeholder if we can't fetch it
        // In a real scenario, we might want to fetch public shop profile first

        await shopLinkRepo.createLink(
          customerId: user.uid,
          shopId: lockedVendorId,
          customerProfileId: const Uuid().v4(), // Generate client-side ID
          shopName: 'Linked Shop', // Initial fallback name, will update on sync
          businessType: 'general',
          shopPhone: '',
        );
        debugPrint('[CustomerAuth] Linked successfully');
      }
    } catch (e) {
      debugPrint('[CustomerAuth] Auto-linking failed: $e');
      // We don't block login, but we should log it
    }
  }

  Future<void> _handleSignup() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      throw Exception("Passwords do not match");
    }

    if (_passwordController.text.length < 8) {
      throw Exception("Password must be at least 8 characters");
    }

    debugPrint('CustomerAuth: Starting signup...');

    // Set Intent BEFORE creating user
    await authIntent.setCustomerIntent();

    final userCredential = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
    final user = userCredential.user!;
    debugPrint('CustomerAuth: Firebase user created: ${user.uid}');

    // Create Customer Profile via Repository
    try {
      final authRepo = AuthRepository();
      await authRepo.createCustomerProfile(
        uid: user.uid,
        name: _customerNameController.text.trim(),
        phone: _mobileController.text.trim(),
        email: _emailController.text.trim(),
      );
      debugPrint('CustomerAuth: Customer profile created via repository');
    } catch (e) {
      debugPrint('CustomerAuth: Failed to create profile: $e');
      // Continue anyway, relying on AuthIntent
    }

    await _session.refreshSession();

    if (!mounted) return;

    // Navigate directly to dashboard
    _navigateToDashboard();
  }

  void _navigateToDashboard() {
    debugPrint('CustomerAuth: Navigating to dashboard...');
    // Show quick success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Text("Account created successfully!", style: GoogleFonts.outfit()),
          ],
        ),
        backgroundColor: const Color(0xFF00FF88).withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );

    // Check for security upgrade
    _checkSecurityUpgrade().then((_) async {
      if (!mounted) return;
      await _linkToLockedShopIfNeeded();
      // Navigate to AuthGate - let it handle role-based routing
      context.go(RoutePaths.authGate);
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.outfit(color: Colors.white)),
        backgroundColor: Colors.red.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      body: Stack(
        children: [
          // Space background
          _SpaceBackground(accentColor: _primaryPurple),

          // Main content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                children: [
                  // Top bar
                  _buildTopBar(),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Center(
                        child: BoundedBox(
                          maxWidth: 500,
                          child: Column(
                            children: [
                              const SizedBox(height: 20),

                              // Glowing logo
                              _GlowingLogo(
                                controller: _glowController,
                                accentColor: _primaryPurple,
                              ),

                              const SizedBox(height: 30),

                              // Title
                              Text(
                                _isLogin
                                    ? "Customer Login"
                                    : "Create Customer\nAccount",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontSize: responsiveValue<double>(
                                    context,
                                    mobile: 20,
                                    tablet: 22,
                                    desktop: 26,
                                  ),
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _isLogin
                                    ? "Log in to access your customer portal"
                                    : "Create an account to get started",
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.6),
                                ),
                              ),

                              const SizedBox(height: 30),

                              // Form
                              _buildForm(),

                              const SizedBox(height: 20),

                              // Toggle login/signup
                              _buildToggle(),

                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Bottom glow
                  _BottomGlow(accentColor: _primaryPurple),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              if (!_isLogin) {
                setState(() => _isLogin = true);
              } else {
                Navigator.pop(context);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white.withOpacity(0.7),
                size: 20,
              ),
            ),
          ),
          Icon(Icons.menu, color: Colors.white.withOpacity(0.7), size: 28),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      padding: EdgeInsets.all(
        responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24),
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: _primaryPurple.withOpacity(0.3), width: 1),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_isLogin) ...[
              // Customer Name
              _buildTextField(
                label: "Your Name",
                controller: _customerNameController,
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 16),

              // Mobile Number
              _buildTextField(
                label: "Mobile Number",
                controller: _mobileController,
                icon: Icons.phone_android,
                keyboardType: TextInputType.phone,
                prefixText: "+91 ",
              ),
              const SizedBox(height: 16),
            ],

            // Email
            _buildTextField(
              label: "Email ID",
              controller: _emailController,
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),

            // Password
            _buildTextField(
              label: "Password",
              controller: _passwordController,
              icon: Icons.lock_outline,
              isPassword: true,
              obscure: _obscurePassword,
              onVisToggle: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),

            if (!_isLogin) ...[
              const SizedBox(height: 8),
              if (_passwordController.text.isNotEmpty &&
                  _passwordController.text.length < 8)
                Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.orange.shade400,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "Password must be at least 8 characters",
                      style: GoogleFonts.outfit(
                        color: Colors.orange.shade400,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),

              // Confirm Password
              _buildTextField(
                label: "Confirm Password",
                controller: _confirmPasswordController,
                icon: Icons.lock_outline,
                isPassword: true,
                obscure: _obscureConfirmPassword,
                onVisToggle: () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword,
                ),
              ),
              const SizedBox(height: 8),
              if (_confirmPasswordController.text.isNotEmpty &&
                  _confirmPasswordController.text != _passwordController.text)
                Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.orange.shade400,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "Passwords do not match",
                      style: GoogleFonts.outfit(
                        color: Colors.orange.shade400,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
            ],

            if (_isLogin) ...[
              // Fast Login Options
              FastLoginOptions(
                onBiometricSuccess: () async {
                  await _session.refreshSession();
                  if (mounted) {
                    context.go(RoutePaths.authGate);
                  }
                },
                onPinSuccess: () async {
                  await _session.refreshSession();
                  if (mounted) {
                    context.go(RoutePaths.authGate);
                  }
                },
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push('/forgot_password'),
                  child: Text(
                    "Forgot password?",
                    style: GoogleFonts.outfit(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Submit Button
            _buildSubmitButton(),

            const SizedBox(height: 16),

            // Divider
            _buildDivider(),

            const SizedBox(height: 16),

            // Google Sign-In Button
            _buildGoogleButton(),
          ],
        ),
      ),
    );
  }

  /// Handle Google Sign-In for Customer
  Future<void> _handleGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);

    try {
      // Set customer intent
      await authIntent.setCustomerIntent();

      final userCredential = await GoogleSignInService().signIn();
      if (userCredential == null) {
        throw Exception('Google Sign-In cancelled');
      }

      final user = userCredential.user!;
      debugPrint('CustomerAuth: Google user: ${user.uid}');

      // Force session refresh
      await _session.refreshSession();

      if (!mounted) return;

      // Check if new user (no role yet)
      if (!_session.isOwner && !_session.isCustomer) {
        // Auto-create customer profile
        await AuthRepository().createCustomerProfile(
          uid: user.uid,
          name: user.displayName ?? 'Customer',
          phone: user.phoneNumber ?? '',
          email: user.email ?? '',
        );
        debugPrint('CustomerAuth: Auto-created customer profile');
      }

      // Navigate to dashboard
      await _linkToLockedShopIfNeeded();
      await authIntent.clearIntent();
      if (!mounted) return;
      context.go(RoutePaths.authGate);
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.white.withOpacity(0.2))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR',
            style: GoogleFonts.outfit(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12,
            ),
          ),
        ),
        Expanded(child: Divider(color: Colors.white.withOpacity(0.2))),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: _isGoogleLoading ? null : _handleGoogleSignIn,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.white.withOpacity(0.3)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: Colors.white.withOpacity(0.05),
        ),
        child: _isGoogleLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/images/google_logo.svg',
                    width: 20,
                    height: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Continue with Google',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
    bool obscure = false,
    VoidCallback? onVisToggle,
    String? prefixText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            color: Colors.white.withOpacity(0.7),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          style: GoogleFonts.outfit(color: Colors.white, fontSize: 15),
          onChanged: (_) => setState(() {}),
          validator: (val) {
            if (val == null || val.isEmpty) return "Required";
            if (label.contains("Email") && !val.contains("@")) {
              return "Invalid email";
            }
            return null;
          },
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.black.withOpacity(0.3),
            prefixIcon: Icon(
              icon,
              color: _primaryPurple.withOpacity(0.7),
              size: 20,
            ),
            prefixText: prefixText,
            prefixStyle: GoogleFonts.outfit(color: Colors.white70),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      obscure ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white.withOpacity(0.4),
                      size: 20,
                    ),
                    onPressed: onVisToggle,
                  )
                : (controller.text.isNotEmpty
                      ? Icon(
                          Icons.check_circle,
                          color: _primaryPurple.withOpacity(0.7),
                          size: 20,
                        )
                      : null),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _primaryPurple.withOpacity(0.5)),
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleAuth,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFAB5CF6), Color(0xFFD500F9)],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: _primaryPurple.withOpacity(0.4),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Center(
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    _isLogin ? "Login" : "Create Account",
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _isLogin ? "Don't have an account?" : "Already have an account?",
          style: GoogleFonts.outfit(
            color: Colors.white.withOpacity(0.6),
            fontSize: 14,
          ),
        ),
        TextButton(
          onPressed: () => setState(() => _isLogin = !_isLogin),
          child: Text(
            _isLogin ? "Create Account" : "Log in",
            style: GoogleFonts.outfit(
              color: _primaryPurple,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
              decorationColor: _primaryPurple,
            ),
          ),
        ),
        if (!_isLogin)
          Icon(Icons.chevron_right, color: _primaryPurple, size: 18),
      ],
    );
  }

  Future<void> _checkSecurityUpgrade() async {
    if (!mounted) return;
    final bioEnabled = await biometricService.isBiometricsEnabled();
    final pinEnabled = await pinService.isPinSet();

    if (!bioEnabled && !pinEnabled) {
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) =>
              SecurityUpgradePrompt(onDismiss: () => Navigator.pop(context)),
        );
      }
    }
  }
}

// ============================================================================
// SHARED WIDGETS
// ============================================================================

/// Glowing circular logo
class _GlowingLogo extends StatelessWidget {
  final AnimationController controller;
  final Color accentColor;

  const _GlowingLogo({required this.controller, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(0.4),
                blurRadius: 40,
                spreadRadius: 5,
              ),
              BoxShadow(
                color: const Color(0xFF00D4FF).withOpacity(0.2),
                blurRadius: 60,
                spreadRadius: 10,
              ),
            ],
          ),
          child: CustomPaint(
            painter: _GlowRingPainter(progress: controller.value),
            child: Center(
              child: Container(
                width: 95,
                height: 95,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0B0D1F),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [accentColor, const Color(0xFF00D4FF)],
                      ).createShader(bounds),
                      child: Text(
                        "dukanX",
                        style: GoogleFonts.orbitron(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Custom painter for the rainbow glow ring
class _GlowRingPainter extends CustomPainter {
  final double progress;

  _GlowRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;

    final gradient = SweepGradient(
      startAngle: progress * 2 * math.pi,
      colors: const [
        Color(0xFFAB5CF6),
        Color(0xFFFF00FF),
        Color(0xFFFF6B00),
        Color(0xFFFFDD00),
        Color(0xFF00FF88),
        Color(0xFF00D4FF),
        Color(0xFFAB5CF6),
      ],
    );

    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _GlowRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Space background with stars
class _SpaceBackground extends StatelessWidget {
  final Color accentColor;

  const _SpaceBackground({required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0B0D1F), Color(0xFF150F2D), Color(0xFF0B0D1F)],
        ),
      ),
      child: Stack(
        children: [
          ...List.generate(50, (index) {
            final random = math.Random(index);
            return Positioned(
              left: random.nextDouble() * MediaQuery.of(context).size.width,
              top: random.nextDouble() * MediaQuery.of(context).size.height,
              child: Container(
                width: random.nextDouble() * 2 + 1,
                height: random.nextDouble() * 2 + 1,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(
                    random.nextDouble() * 0.5 + 0.2,
                  ),
                ),
              ),
            );
          }),
          Positioned(
            left: -80,
            top: MediaQuery.of(context).size.height * 0.3,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [accentColor.withOpacity(0.2), Colors.transparent],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom glow effect
class _BottomGlow extends StatelessWidget {
  final Color accentColor;

  const _BottomGlow({required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.5,
          colors: [
            accentColor.withOpacity(0.15),
            const Color(0xFF00D4FF).withOpacity(0.1),
            Colors.transparent,
          ],
        ),
      ),
      child: Center(
        child: Container(
          width: 150,
          height: 3,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: LinearGradient(
              colors: [Colors.transparent, accentColor, Colors.transparent],
            ),
          ),
        ),
      ),
    );
  }
}

/// Success Screen after account creation
class _SuccessScreen extends StatefulWidget {
  final String message;
  final String subMessage;
  final Color accentColor;
  final VoidCallback onContinue;

  const _SuccessScreen({
    required this.message,
    required this.subMessage,
    required this.accentColor,
    required this.onContinue,
  });

  @override
  State<_SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<_SuccessScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnim = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _controller.forward();

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) widget.onContinue();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D1F),
      body: Stack(
        children: [
          _SpaceBackground(accentColor: widget.accentColor),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Icon(
                      Icons.history,
                      color: Colors.white.withOpacity(0.7),
                      size: 28,
                    ),
                  ),
                ),
                const Spacer(),
                ScaleTransition(
                  scale: _scaleAnim,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.accentColor.withOpacity(0.1),
                      border: Border.all(
                        color: widget.accentColor.withOpacity(0.3),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.accentColor.withOpacity(0.3),
                          blurRadius: 40,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.check,
                      color: widget.accentColor,
                      size: 60,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  widget.message,
                  style: GoogleFonts.outfit(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white.withOpacity(0.05),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check,
                        color: const Color(0xFF00FF88),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        widget.subMessage,
                        style: GoogleFonts.outfit(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                _BottomGlow(accentColor: widget.accentColor),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
