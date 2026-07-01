import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dukanx/core/compat/firebase_auth_compat.dart';
import 'package:dukanx/core/responsive/responsive.dart';
import 'dart:ui' show ImageFilter;

/// Modern Forgot Password Screen
/// Uses ONLY Firebase Auth sendPasswordResetEmail
/// Glassmorphism + gradient design
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isSuccess = false;
  String? _errorMessage;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    if (!_formKey.currentState!.validate()) return;

    HapticFeedback.mediumImpact();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSuccess = true;
        });

        HapticFeedback.heavyImpact();

        // Auto-navigate back after 3 seconds
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          // Security: Generic message regardless of actual error
          _errorMessage = e.code == 'invalid-email'
              ? 'Please enter a valid email address.'
              : 'If this email is registered, a reset link has been sent.';
          // If email format is valid, always show success for security
          if (e.code != 'invalid-email') {
            _isSuccess = true;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          // Security: Always show success for valid email format
          _isSuccess = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Background gradient orbs
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Colors.blue.withOpacity(0.3), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Colors.purple.withOpacity(0.25), Colors.transparent],
                ),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Center(
                child: BoundedBox(
                  maxWidth: 500,
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: _isSuccess ? _buildSuccessView() : _buildFormView(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormView() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),

          // Logo with glow
          Center(
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF667EEA).withOpacity(0.4),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.lock_reset,
                size: 48,
                color: Colors.white,
              ),
            ),
          ),

          const SizedBox(height: 48),

          // Title
          const Text(
            'Reset Password',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            'Enter your registered email address',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withOpacity(0.6),
            ),
          ),

          const SizedBox(height: 48),

          // Email input with glassmorphism
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Email address',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                    prefixIcon: Icon(
                      Icons.email_outlined,
                      color: Colors.white.withOpacity(0.7),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(20),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.contains('@') || !value.contains('.')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
              ),
            ),
          ),

          // Error message
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          ],

          const SizedBox(height: 32),

          // Send button with gradient
          GestureDetector(
            onTap: _isLoading ? null : _sendResetEmail,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF667EEA).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
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
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'Send Reset Link',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Back to login
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Back to Login',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 80),

        // Success checkmark with animation
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00C853), Color(0xFF69F0AE)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00C853).withOpacity(0.4),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.check, size: 64, color: Colors.white),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 48),

        const Text(
          'Check Your Email',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),

        const SizedBox(height: 16),

        Text(
          'If this email is registered, you will receive a password reset link shortly.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: Colors.white.withOpacity(0.6),
            height: 1.5,
          ),
        ),

        const SizedBox(height: 16),

        Text(
          'Check your spam folder if you don\'t see it.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.4)),
        ),

        const SizedBox(height: 48),

        // Back to login button
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white.withOpacity(0.1),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: const Center(
              child: Text(
                'Back to Login',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
