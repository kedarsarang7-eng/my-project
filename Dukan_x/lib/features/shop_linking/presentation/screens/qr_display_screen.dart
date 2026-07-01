import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dukanx/core/compat/firebase_auth_compat.dart';
import '../../../../providers/app_state_providers.dart';
import '../../../../services/secure_qr_service.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class QrDisplayScreen extends ConsumerWidget {
  const QrDisplayScreen({super.key});

  // Secure QR Service for signed QR generation
  static final SecureQrService _qrService = SecureQrService();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Current user is Owner
    final user = FirebaseAuth.instance.currentUser;
    final ownerUid = user?.uid ?? '';
    final settings = ref.watch(settingsStateProvider);
    final businessTypeState = ref.watch(businessTypeProvider);

    final shopName = settings.userName ?? user?.displayName ?? "My Shop";
    final businessType = businessTypeState.type.name;

    // Generate signed QR payload using SecureQrService (v2 format with HMAC)
    final String qrString = _qrService.generateShopQrPayload(
      shopId: ownerUid,
      shopName: shopName,
      businessType: businessType,
      expiryHours: 24 * 7, // 7 days expiry for shop QR
    );

    final theme = ref.watch(themeStateProvider);
    final isDark = theme.isDark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("My Shop QR Code"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: responsiveValue<double>(context, mobile: 16, tablet: 18, desktop: 20),
        ),
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: Stack(
        children: [
          // Ambient Background
          if (isDark) ...[
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Colors.blue.withOpacity(0.2), Colors.transparent],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -100,
              left: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.purple.withOpacity(0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],

          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 30,
                        spreadRadius: 5,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      QrImageView(
                        data: qrString,
                        version: QrVersions.auto,
                        size: 250.0,
                        backgroundColor: Colors.white,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "Scan to Join My Shop",
                        style: TextStyle(
                          fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
                  ),
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "Share this Qr with your customers",
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.perm_identity,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                      const SizedBox(width: 10),
                      SelectableText(
                        "Shop ID: $ownerUid",
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}
