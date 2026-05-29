import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';

class BiometricButton extends ConsumerWidget {
  const BiometricButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 64,
      child: OutlinedButton(
        onPressed: () {
          // TODO: Implement biometric login when available
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Biometric login coming soon')),
          );
        },
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.primaryNavy, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Fingerprint icon
            const Icon(Icons.fingerprint, color: AppColors.primaryNavy, size: 28),
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
}
