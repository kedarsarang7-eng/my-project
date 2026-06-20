import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../providers/auth_provider.dart';

class BiometricButton extends ConsumerWidget {
  const BiometricButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 64,
      child: OutlinedButton(
        onPressed: () => _handleBiometricLogin(context, ref),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.primaryNavy, width: 1.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Fingerprint icon
            const Icon(Icons.fingerprint,
                color: AppColors.primaryNavy, size: 28),
            const SizedBox(width: 6),
            // Face ID icon
            const Icon(Icons.face, color: AppColors.primaryNavy, size: 26),
            const SizedBox(width: 14),
            // Text
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.biometricMain,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryNavy,
                  ),
                ),
                Text(
                  AppStrings.biometricSub,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textMedium,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleBiometricLogin(
      BuildContext context, WidgetRef ref) async {
    final localAuth = LocalAuthentication();

    try {
      // Check if device supports biometrics
      final canCheck = await localAuth.canCheckBiometrics;
      final isDeviceSupported = await localAuth.isDeviceSupported();

      if (!canCheck && !isDeviceSupported) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Biometric login is not supported on this device'),
            ),
          );
        }
        return;
      }

      // Authenticate with biometrics
      final authenticated = await localAuth.authenticate(
        localizedReason: 'Log in with biometrics',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (authenticated) {
        await ref.read(authNotifierProvider.notifier).biometricLogin();
      }
    } on PlatformException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Biometric authentication failed'),
          ),
        );
      }
    }
  }
}
