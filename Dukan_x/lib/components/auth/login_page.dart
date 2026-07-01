import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dukanx/core/routing/route_paths.dart';
import '../../auth/auth_store.dart';
import '../../core/di/service_locator.dart';
import '../../core/session/session_manager.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _obscure = true;
  bool _rememberMe = false;
  String? _inlineError;
  bool _shouldShake = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _emailFocus.requestFocus(),
    );
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _shouldShake = !_shouldShake);
      return;
    }
    setState(() => _inlineError = null);

    final emailText = _email.text.trim();
    final passwordText = _password.text;

    try {
      await ref.read(authStoreProvider.notifier).login(emailText, passwordText);

      if (emailText == 'admin@myvyaparmitra.com' && passwordText == 'admin') {
        await sl<SessionManager>().devBypassLogin();
        if (!mounted) return;
        context.go('/onboarding');
        return;
      }

      if (!mounted) return;
      context.go(RoutePaths.authGate);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _inlineError = e.toString().replaceFirst('Exception: ', '');
        _shouldShake = !_shouldShake;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isMobile = media.size.width < 768;
    final isKeyboardOpen = media.viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: isMobile
          ? Column(
              children: [
                if (!isKeyboardOpen)
                  const Expanded(
                    flex: 3,
                    child: _AnimatedLeftBackground(isMobile: true),
                  ),
                Expanded(flex: 7, child: _buildRightPanel()),
              ],
            )
          : Row(
              children: [
                const Expanded(
                  flex: 55,
                  child: _AnimatedLeftBackground(isMobile: false),
                ),
                Expanded(flex: 45, child: _buildRightPanel()),
              ],
            ),
    );
  }

  Widget _buildRightPanel() {
    // Background: gradient base + optional local image overlay
    // Drop your image at: assets/images/login/right_bg.png
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF8F9FC), Color(0xFFEEF1F8), Color(0xFFE8ECF4)],
        ),
        // Image enabled ONLY for right side
        image: DecorationImage(
          image: AssetImage('assets/images/login/right_bg.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Center(
        child: _SlideUpFadeIn(
          child: _ShakeWidget(
            shouldShake: _shouldShake,
            child: SingleChildScrollView(
              child: Container(
                width: 420,
                margin: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1F000000),
                      blurRadius: 60,
                      offset: Offset(0, 20),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Log In',
                        style: GoogleFonts.dmSans(
                          color: const Color(0xFF111827),
                          fontWeight: FontWeight.w700,
                          fontSize: 28,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Access your multi-business dashboard.',
                        style: GoogleFonts.dmSans(
                          color: const Color(0xFF6B7280),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 24),

                      _buildLabel('Email Address'),
                      const SizedBox(height: 6),
                      _buildTextField(
                        controller: _email,
                        focusNode: _emailFocus,
                        hint: 'name@company.com',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty)
                            return 'Email is required';
                          if (!v.contains('@')) return 'Enter a valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      _buildLabel('Password'),
                      const SizedBox(height: 6),
                      _buildTextField(
                        controller: _password,
                        focusNode: _passwordFocus,
                        hint: '••••••••',
                        icon: Icons.lock_outline,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        suffix: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure ? Icons.visibility_off : Icons.visibility,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Password is required'
                            : null,
                      ),
                      const SizedBox(height: 12),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                height: 24,
                                width: 24,
                                child: Checkbox(
                                  value: _rememberMe,
                                  activeColor: const Color(0xFF1A56DB),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  onChanged: (v) =>
                                      setState(() => _rememberMe = v ?? false),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Remember me',
                                style: GoogleFonts.dmSans(
                                  color: const Color(0xFF374151),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          InkWell(
                            onTap: () {},
                            child: Text(
                              'Forgot Password?',
                              style: GoogleFonts.dmSans(
                                color: const Color(0xFF1A56DB),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),

                      if (_inlineError != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _inlineError!,
                          style: GoogleFonts.dmSans(
                            color: Colors.red.shade600,
                            fontSize: 13,
                          ),
                        ),
                      ] else
                        const SizedBox(height: 24),
                      if (_inlineError == null) const SizedBox(height: 24),

                      _buildLoginButton(),
                      const SizedBox(height: 24),

                      Center(
                        child: Text(
                          '© 2026 Myvyaparmitra | Privacy Policy | Terms of Service',
                          style: GoogleFonts.dmSans(
                            color: const Color(0xFF9CA3AF),
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.dmSans(
        fontSize: 12,
        color: const Color(0xFF374151),
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffix,
    String? Function(String?)? validator,
    TextInputAction? textInputAction,
    void Function(String)? onFieldSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      style: GoogleFonts.dmSans(color: const Color(0xFF111827), fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.dmSans(
          color: const Color(0xFF9CA3AF),
          fontSize: 14,
        ),
        prefixIcon: Icon(icon, color: const Color(0xFF6B7280), size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: Color(0xFF1A56DB), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.red.shade400),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.red.shade400, width: 2),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    final isLoading = ref.watch(authStoreProvider).isLoading;
    return Container(
      height: 48,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A3A8F), Color(0xFF1D4ED8)],
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D4ED8).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : _submit,
          borderRadius: BorderRadius.circular(8),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    'Log In',
                    style: GoogleFonts.dmSans(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedLeftBackground extends StatefulWidget {
  final bool isMobile;
  const _AnimatedLeftBackground({this.isMobile = false});

  @override
  _AnimatedLeftBackgroundState createState() => _AnimatedLeftBackgroundState();
}

class _AnimatedLeftBackgroundState extends State<_AnimatedLeftBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) {
        final t = _controller.value;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(
                  const Color(0xFF0D1E4A),
                  const Color(0xFF102868),
                  t,
                )!,
                Color.lerp(
                  const Color(0xFF1A56DB),
                  const Color(0xFF2563EB),
                  t,
                )!,
              ],
            ),
            // Uncomment below when you add left_bg.png to assets/images/login/
            // image: const DecorationImage(
            //   image: AssetImage('assets/images/login/left_bg.png'),
            //   fit: BoxFit.cover,
            // ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(painter: _NetworkLinesPainter(t)),
              const _FloatingIcons(),
              Positioned(
                bottom: widget.isMobile ? 24 : 48,
                left: widget.isMobile ? 24 : 48,
                right: widget.isMobile ? 24 : 48,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            color: Color(0xFF0D1E4A),
                            shape: BoxShape.circle,
                            border: Border.fromBorderSide(
                              BorderSide(color: Colors.white, width: 2),
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Text(
                                'D',
                                style: GoogleFonts.dmSans(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const Positioned(
                                top: 8,
                                right: 8,
                                child: Icon(
                                  Icons.star,
                                  color: Colors.white,
                                  size: 10,
                                ),
                              ),
                              const Positioned(
                                bottom: 8,
                                right: 8,
                                child: Icon(
                                  Icons.arrow_outward,
                                  color: Color(0xFF38BDF8),
                                  size: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Myvyaparmitra',
                            style: GoogleFonts.dmSans(
                              color: Colors.white,
                              fontSize: widget.isMobile ? 24 : 32,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Empowering Your Business Growth.\nManage. Scale. Thrive.',
                      style: GoogleFonts.dmSans(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: widget.isMobile ? 14 : 18,
                        fontWeight: FontWeight.w400,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FloatingIcons extends StatefulWidget {
  const _FloatingIcons();
  @override
  _FloatingIconsState createState() => _FloatingIconsState();
}

class _FloatingIconsState extends State<_FloatingIcons>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          children: [
            _buildIcon(Icons.storefront_outlined, 0.1, 0.2, 0),
            _buildIcon(Icons.local_shipping_outlined, 0.3, 0.6, 0.5),
            _buildIcon(Icons.bar_chart_outlined, 0.7, 0.3, 1.0),
            _buildIcon(Icons.location_on_outlined, 0.8, 0.7, 1.5),
            _buildIcon(Icons.inventory_2_outlined, 0.5, 0.8, 0.8),
            _buildIcon(Icons.cloud_queue, 0.2, 0.8, 1.2),
          ],
        );
      },
    );
  }

  Widget _buildIcon(IconData icon, double x, double y, double delay) {
    final offset = math.sin((_controller.value * math.pi * 2) + delay) * 8;
    return Align(
      alignment: FractionalOffset(x, y),
      child: Transform.translate(
        offset: Offset(0, offset),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.white.withOpacity(0.02), blurRadius: 20),
            ],
          ),
          child: Icon(icon, color: Colors.white.withOpacity(0.6), size: 32),
        ),
      ),
    );
  }
}

class _NetworkLinesPainter extends CustomPainter {
  final double t;
  _NetworkLinesPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 1.0;

    final points = <Offset>[];
    for (var i = 0; i < 25; i++) {
      final x = (math.sin((i + 1) * 0.7 + t * 1.5) * 0.5 + 0.5) * size.width;
      final y = (math.cos((i + 1) * 0.5 + t) * 0.5 + 0.5) * size.height;
      points.add(Offset(x, y));
      canvas.drawCircle(Offset(x, y), 2, paint..style = PaintingStyle.fill);
    }

    paint.style = PaintingStyle.stroke;
    for (var i = 0; i < points.length; i++) {
      for (var j = i + 1; j < points.length; j++) {
        if ((points[i] - points[j]).distance < 180) {
          canvas.drawLine(points[i], points[j], paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _NetworkLinesPainter oldDelegate) =>
      oldDelegate.t != t;
}

class _SlideUpFadeIn extends StatefulWidget {
  final Widget child;
  const _SlideUpFadeIn({required this.child});
  @override
  _SlideUpFadeInState createState() => _SlideUpFadeInState();
}

class _SlideUpFadeInState extends State<_SlideUpFadeIn>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fade = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

class _ShakeWidget extends StatefulWidget {
  final Widget child;
  final bool shouldShake;
  const _ShakeWidget({required this.child, required this.shouldShake});
  @override
  _ShakeWidgetState createState() => _ShakeWidgetState();
}

class _ShakeWidgetState extends State<_ShakeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void didUpdateWidget(_ShakeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shouldShake != oldWidget.shouldShake) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final sineValue = math.sin(_controller.value * math.pi * 4);
        return Transform.translate(
          offset: Offset(sineValue * 8, 0),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
