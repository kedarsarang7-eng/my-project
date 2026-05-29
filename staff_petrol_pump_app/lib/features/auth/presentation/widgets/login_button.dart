import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/auth/auth_provider.dart';
import '../providers/login_form_provider.dart';

class LoginButton extends ConsumerWidget {
  const LoginButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState  = ref.watch(authStateProvider);
    final formState  = ref.watch(loginFormProvider);
    final isLoading  = authState.isLoading;
    final isEnabled  = formState.staffId.isNotEmpty && formState.password.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading || !isEnabled
            ? null
            : () {
                FocusScope.of(context).unfocus();
                ref.read(authStateProvider.notifier).signIn(
                  formState.staffId,
                  formState.password,
                );
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: isEnabled ? AppColors.primaryNavy : AppColors.primaryNavy.withValues(alpha: 0.5),
          disabledBackgroundColor: AppColors.primaryNavy.withValues(alpha: 0.4),
          elevation: isEnabled ? 4 : 0,
          shadowColor: AppColors.primaryNavy.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2.5,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    AppStrings.loginButton,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                ],
              ),
      ),
    );
  }
}
