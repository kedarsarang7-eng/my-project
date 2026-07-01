import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'dart:io';
import 'dart:typed_data';

import '../../../../core/theme/futuristic_colors.dart';
import '../../../../providers/app_state_providers.dart';
import '../../../../services/secure_qr_service.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../widgets/modern_ui_components.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class CustomerAppEntryQrScreen extends ConsumerStatefulWidget {
  const CustomerAppEntryQrScreen({super.key});

  @override
  ConsumerState<CustomerAppEntryQrScreen> createState() =>
      _CustomerAppEntryQrScreenState();
}

class _CustomerAppEntryQrScreenState
    extends ConsumerState<CustomerAppEntryQrScreen> {
  String? _deepLink;
  bool _isLoading = true;
  final SecureQrService _qrService =
      SecureQrService(); // Use DI if registered, or direct instantiation

  @override
  void initState() {
    super.initState();
    _generateQr();
  }

  Future<void> _generateQr() async {
    final session = sl<SessionManager>();
    if (!session.isOwner || session.userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // Generate Secure Dynamic Link
    final link = _qrService.generateCustomerDeepLink(
      shopId: session.userId!,
      expiryHours: 24 * 30, // 30 Days expiry for printed QR comfort
    );

    if (mounted) {
      setState(() {
        _deepLink = link;
        _isLoading = false;
      });
    }
  }

  Future<void> _shareQr() async {
    if (_deepLink == null) return;

    try {
      final qrPainter = QrPainter(
        data: _deepLink!,
        version: QrVersions.auto,
        gapless: true,
        color: Colors.black,
        emptyColor: Colors.white,
      );

      final picData = await qrPainter.toImageData(300);
      if (picData == null) return;

      final bytes = Uint8List.view(picData.buffer);
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/customer_entry_qr.png');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Download the app and scan this QR to view my shop!',
        subject: 'Customer App QR',
      );
    } catch (e) {
      debugPrint('Share error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeStateProvider);
    final isDark = theme.isDark;
    final settings = ref.watch(settingsStateProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Customer App QR"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? FuturisticColors.darkBackgroundGradient
              : FuturisticColors.lightBackgroundGradient,
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _deepLink == null
              ? const Center(child: Text("Error generating QR"))
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),

                    // QR Card
                    Center(
                      child: Container(
                        padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            QrImageView(
                              data: _deepLink!,
                              version: QrVersions.auto,
                              size: 250,
                              backgroundColor: Colors.white,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              settings.userName ?? "My Shop",
                              style: AppTypography.headlineSmall.copyWith(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text(
                              "Customer Access",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Action Buttons
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: EnterpriseButton(
                        label: "Share QR Code",
                        icon: Icons.share,
                        onPressed: _shareQr,
                        width: double.infinity,
                      ),
                    ),

                    const SizedBox(height: 20),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        "Customers scanning this QR will get the Customer-Only version of the app linked to your shop.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
      ),
    );
  }
}
