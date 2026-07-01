import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dukanx/core/compat/firebase_auth_compat.dart';
import 'package:notifications_sdk/notifications_sdk.dart' as uns;

import '../../../../core/notifications/uns_providers.dart';
import '../../../../services/connection_service.dart';
import '../../../../services/secure_qr_service.dart';
import '../../../../providers/app_state_providers.dart';
import 'shop_confirmation_screen.dart';
import 'manual_shop_add_screen.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Path-style identifier used as `source_module` on every UNS emit raised
/// from this screen. Matches Phase 2 §9.1.
const String _kQrScannerSourceModule =
    'Dukan_x/lib/features/shop_linking/presentation/screens/qr_scanner_screen.dart';

class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  final MobileScannerController controller = MobileScannerController();
  final SecureQrService _qrService = SecureQrService();
  bool _isProcessing = false;

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    for (final barcode in barcodes) {
      if (barcode.rawValue == null) continue;
      final rawValue = barcode.rawValue!;

      // Validate QR using SecureQrService (handles v2, v1, and legacy formats)
      final validationResult = _qrService.validateQrPayload(rawValue);

      if (validationResult.isValid && validationResult.shopId != null) {
        setState(() => _isProcessing = true);
        controller.stop();

        // Extract shop info from validated payload
        final shopId = validationResult.shopId!;
        final payload = validationResult.payload;
        final shopName = payload?['shopName'] as String?;
        final businessType = payload?['businessType'] as String?;

        // Navigate to confirmation screen with validated data
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ShopConfirmationScreen(
              ownerUid: shopId,
              shopName: shopName,
              businessType: businessType,
            ),
          ),
        ).then((_) {
          if (mounted) {
            setState(() => _isProcessing = false);
            controller.start();
          }
        });
        return; // Stop after first valid QR
      } else if (validationResult.error != null) {
        // Show error for invalid/expired QR
        if (validationResult.error!.contains('expired')) {
          _showError(
            'This QR code has expired. Please ask the shop for a new one.',
          );
        } else if (validationResult.error!.contains('tampered')) {
          _showError('Invalid QR code. This may be a security issue.');
        }
        // Continue scanning for other barcodes
        continue;
      }

      // Fallback: Handle v1 format for backward compatibility
      if (rawValue.startsWith('v1:')) {
        setState(() => _isProcessing = true);
        controller.stop();

        try {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) {
            throw Exception("You must be logged in to connect.");
          }

          // Send request using ConnectionService (legacy flow)
          await ConnectionService().sendRequestFromQr(rawValue);

          // UNS emit (task 14.5, T-CUS-3) — legacy v1 QR fallback path
          // also raises `users.customer_shop.linked` so the registry
          // consumers see the same event regardless of QR version. The
          // shop owner still has to accept the request, but Phase 2 §9.1
          // anchors the trigger on the QR scan, not on the acceptance.
          final v1ShopId = _parseV1ShopId(rawValue);
          if (v1ShopId != null) {
            await _emitCustomerShopLinked(
              customerId: user.uid,
              customerName: user.displayName,
              customerPhone: user.phoneNumber,
              shopId: v1ShopId,
            );
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Connection request sent! Waiting for approval.'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context);
          }
        } catch (e) {
          if (mounted) {
            _showError('Failed: $e');
            setState(() => _isProcessing = false);
            controller.start();
          }
        }
        return;
      }
    }
  }

  /// Parse a legacy v1 QR (`v1:<vendorId>` or `v1:<vendorId>:<x>:<y>`) and
  /// return the shop/vendor id, or null if the format is unexpected.
  String? _parseV1ShopId(String rawValue) {
    if (!rawValue.startsWith('v1:')) return null;
    final parts = rawValue.split(':');
    if (parts.length < 2) return null;
    final id = parts[1].trim();
    return id.isEmpty ? null : id;
  }

  /// Emit the canonical `users.customer_shop.linked` event through the
  /// Shared_SDK. Recipients (`customer`, `admin`) and channels are resolved
  /// server-side from Phase 2 §9.1 — this site only carries the payload.
  Future<void> _emitCustomerShopLinked({
    required String customerId,
    String? customerName,
    String? customerPhone,
    required String shopId,
  }) async {
    final sdk = ref.read(notificationsSdkProvider).value;
    if (sdk == null) return;

    try {
      final payload = <String, dynamic>{
        'customer_id': customerId,
        'shop_id': shopId,
        'customer_name': ?customerName,
        'customer_phone': ?customerPhone,
        'link_source': 'qr_scan_v1_fallback',
      };

      final dedupKey = 'users.customer_shop.linked:$customerId:$shopId';

      final event = sdk.buildEvent(
        eventName: 'users.customer_shop.linked',
        category: uns.EventCategory.users,
        subCategory: 'shop_link',
        priority: uns.EventPriority.normal,
        actorId: customerId,
        targetId: shopId,
        recipients: const <uns.Recipient>[],
        payload: payload,
        channels: const <uns.NotificationChannel>[
          uns.NotificationChannel.inApp,
          uns.NotificationChannel.push,
        ],
        sourceModule: _kQrScannerSourceModule,
        sourceApp: uns.SourceApp.dukanxDesktop,
        dedupKey: dedupKey,
        dedupScopeFields: const <String>['customer_id', 'shop_id'],
      );

      await sdk.emit(event);
    } catch (e, stack) {
      debugPrint(
        '[QrScannerScreen] UNS emit "users.customer_shop.linked" '
        'failed: $e\n$stack',
      );
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeStateProvider);
    // ignore: unused_local_variable
    final isDark = theme.isDark;

    return Scaffold(
      backgroundColor: Colors.black,
      body: BoundedBox(
        maxWidth: 800,
        child: Stack(
          children: [
            MobileScanner(controller: controller, onDetect: _onDetect),

            // Overlay
            Container(
              decoration: ShapeDecoration(
                shape: QrScannerOverlayShape(
                  borderColor: Colors.blue,
                  borderRadius: 10,
                  borderLength: 30,
                  borderWidth: 10,
                  cutOutSize: 300,
                ),
              ),
            ),

            // Header
            Positioned(
              top: 50,
              left: 20,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),

            Positioned(
              top: 60,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  "Scan Shop QR",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: responsiveValue<double>(
                      context,
                      mobile: 14.0,
                      tablet: 16.0,
                      desktop:
                          18.0, // PRESERVED: Desktop uses exactly 18 as before
                    ),
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                  ),
                ),
              ),
            ),

            // Tools
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ValueListenableBuilder(
                    valueListenable: controller,
                    builder: (context, state, child) {
                      final torchState = state.torchState;
                      return IconButton(
                        color: Colors.white,
                        icon: Icon(
                          torchState == TorchState.on
                              ? Icons.flash_on
                              : Icons.flash_off,
                          color: torchState == TorchState.on
                              ? Colors.yellow
                              : Colors.white,
                          size: 30,
                        ),
                        onPressed: () => controller.toggleTorch(),
                      );
                    },
                  ),
                  ValueListenableBuilder(
                    valueListenable: controller,
                    builder: (context, state, child) {
                      final cameraFacing = state.cameraDirection;
                      return IconButton(
                        color: Colors.white,
                        icon: Icon(
                          cameraFacing == CameraFacing.front
                              ? Icons.camera_front
                              : Icons.camera_rear,
                          size: 30,
                        ),
                        onPressed: () => controller.switchCamera(),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Manual Entry
            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: ElevatedButton.icon(
                onPressed: () {
                  controller.stop();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ManualShopAddScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.keyboard, color: Colors.white),
                label: const Text(
                  "Enter Shop ID Manually",
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.2),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom Overlay Shape
class QrScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;
  final double cutOutBottomOffset;

  const QrScannerOverlayShape({
    this.borderColor = Colors.red,
    this.borderWidth = 10.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 80),
    this.borderRadius = 0,
    this.borderLength = 40,
    this.cutOutSize = 250,
    this.cutOutBottomOffset = 0,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path getLeftTopPath(Rect rect) {
      return Path()
        ..moveTo(rect.left, rect.bottom)
        ..lineTo(rect.left, rect.top)
        ..lineTo(rect.right, rect.top);
    }

    return getLeftTopPath(rect);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final backgroundPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final boxPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.dstOut;

    final cutOutRect = Rect.fromCenter(
      center: rect.center + Offset(0, -cutOutBottomOffset),
      width: cutOutSize,
      height: cutOutSize,
    );

    canvas.saveLayer(rect, backgroundPaint);
    canvas.drawRect(rect, backgroundPaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(cutOutRect, Radius.circular(borderRadius)),
      boxPaint,
    );
    canvas.restore();

    // Draw corners
    final path = Path();
    // Top left
    path.moveTo(cutOutRect.left, cutOutRect.top + borderLength);
    path.lineTo(cutOutRect.left, cutOutRect.top + borderRadius);
    path.quadraticBezierTo(
      cutOutRect.left,
      cutOutRect.top,
      cutOutRect.left + borderRadius,
      cutOutRect.top,
    );
    path.lineTo(cutOutRect.left + borderLength, cutOutRect.top);
    // Top right
    path.moveTo(cutOutRect.right - borderLength, cutOutRect.top);
    path.lineTo(cutOutRect.right - borderRadius, cutOutRect.top);
    path.quadraticBezierTo(
      cutOutRect.right,
      cutOutRect.top,
      cutOutRect.right,
      cutOutRect.top + borderRadius,
    );
    path.lineTo(cutOutRect.right, cutOutRect.top + borderLength);
    // Bottom right
    path.moveTo(cutOutRect.right, cutOutRect.bottom - borderLength);
    path.lineTo(cutOutRect.right, cutOutRect.bottom - borderRadius);
    path.quadraticBezierTo(
      cutOutRect.right,
      cutOutRect.bottom,
      cutOutRect.right - borderRadius,
      cutOutRect.bottom,
    );
    path.lineTo(cutOutRect.right - borderLength, cutOutRect.bottom);
    // Bottom left
    path.moveTo(cutOutRect.left + borderLength, cutOutRect.bottom);
    path.lineTo(cutOutRect.left + borderRadius, cutOutRect.bottom);
    path.quadraticBezierTo(
      cutOutRect.left,
      cutOutRect.bottom,
      cutOutRect.left,
      cutOutRect.bottom - borderRadius,
    );
    path.lineTo(cutOutRect.left, cutOutRect.bottom - borderLength);

    canvas.drawPath(path, borderPaint);
  }

  @override
  ShapeBorder scale(double t) {
    return QrScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth,
      overlayColor: overlayColor,
    );
  }
}
