import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../providers/auth_provider.dart';

/// Force Password Change Screen
///
/// This screen is shown when a staff member logs in for the first time
/// with a temporary password. They must set a new password before
/// accessing the app.
class ForcePasswordChangeScreen extends ConsumerStatefulWidget {
  final String staffId;
  final String temporaryPassword;

  const ForcePasswordChangeScreen({
    super.key,
    required this.staffId,
    required this.temporaryPassword,
  });

  @override
  ConsumerState<ForcePasswordChangeScreen> createState() =>
      _ForcePasswordChangeScreenState();
}

class _ForcePasswordChangeScreenState
    extends ConsumerState<ForcePasswordChangeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  // Password strength indicators
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;

  @override
  void initState() {
    super.initState();
    _newPasswordController.addListener(_checkPasswordStrength);
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _checkPasswordStrength() {
    final password = _newPasswordController.text;
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasUppercase = password.contains(RegExp(r'[A-Z]'));
      _hasLowercase = password.contains(RegExp(r'[a-z]'));
      _hasNumber = password.contains(RegExp(r'[0-9]'));
      _hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    });
  }

  bool get _isPasswordValid {
    return _hasMinLength &&
        _hasUppercase &&
        _hasLowercase &&
        _hasNumber &&
        _hasSpecialChar;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundGrey,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 40),

              // Logo/Icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primaryNavy.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_outline,
                  size: 48,
                  color: AppColors.primaryNavy,
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                'Set New Password',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),

              // Subtitle
              Text(
                'This is your first login. Please set a secure password to continue.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textMedium,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),

              // Form Card
              Container(
                decoration: BoxDecoration(
                  color: AppColors.cardWhite,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryNavy.withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // New Password Field
                        _buildPasswordField(
                          controller: _newPasswordController,
                          label: 'New Password',
                          hint: 'Enter new password',
                          obscureText: _obscureNewPassword,
                          onToggleVisibility: () {
                            setState(() =>
                                _obscureNewPassword = !_obscureNewPassword);
                          },
                          validator: (value) {
                            if (value?.isEmpty ?? true) {
                              return 'Password is required';
                            }
                            if (!_isPasswordValid) {
                              return 'Password does not meet requirements';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Confirm Password Field
                        _buildPasswordField(
                          controller: _confirmPasswordController,
                          label: 'Confirm Password',
                          hint: 'Re-enter new password',
                          obscureText: _obscureConfirmPassword,
                          onToggleVisibility: () {
                            setState(() => _obscureConfirmPassword =
                                !_obscureConfirmPassword);
                          },
                          validator: (value) {
                            if (value?.isEmpty ?? true) {
                              return 'Please confirm your password';
                            }
                            if (value != _newPasswordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // Password Strength Indicator
                        _buildPasswordStrengthIndicator(),
                        const SizedBox(height: 24),

                        // Error Message
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.errorRed.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline,
                                    color: AppColors.errorRed, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: AppColors.errorRed,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading || !_isPasswordValid
                                ? null
                                : _changePassword,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryNavy,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade300,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    'Set Password',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Help Text
              GestureDetector(
                onTap: () => _showContactAdminDialog(),
                child: Text(
                  'Need help? Contact your manager',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.primaryNavy,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    required String? Function(String?) validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textLight,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                obscureText ? Icons.visibility_off : Icons.visibility,
                color: AppColors.textMedium,
              ),
              onPressed: onToggleVisibility,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.dividerGrey),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.dividerGrey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primaryNavy, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.errorRed),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordStrengthIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundGrey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Password Requirements:',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 12),
          _buildRequirementItem('At least 8 characters', _hasMinLength),
          _buildRequirementItem('One uppercase letter (A-Z)', _hasUppercase),
          _buildRequirementItem('One lowercase letter (a-z)', _hasLowercase),
          _buildRequirementItem('One number (0-9)', _hasNumber),
          _buildRequirementItem(
              'One special character (!@#\$%^&*)', _hasSpecialChar),
        ],
      ),
    );
  }

  Widget _buildRequirementItem(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: isMet ? AppColors.successGreen : AppColors.textLight,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: isMet ? AppColors.textDark : AppColors.textMedium,
              fontWeight: isMet ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  void _showContactAdminDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Contact Manager',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Please contact your station manager or admin for assistance with password reset.',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: GoogleFonts.inter(color: AppColors.primaryNavy),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success =
          await ref.read(authNotifierProvider.notifier).completeNewPassword(
                staffId: widget.staffId,
                temporaryPassword: widget.temporaryPassword,
                newPassword: _newPasswordController.text,
              );

      if (success && mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      } else if (mounted) {
        final authState = ref.read(authNotifierProvider);
        setState(() {
          _errorMessage = authState.errorMessage ??
              'Password change failed. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
