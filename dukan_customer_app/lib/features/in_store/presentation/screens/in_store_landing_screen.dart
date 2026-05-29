// ============================================================================
// In-Store Landing Screen — "Start In-Store Shopping" entry point
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../providers/in_store_providers.dart';
import '../../../../../core/navigation/app_router.dart';

class InStoreLandingScreen extends ConsumerWidget {
  const InStoreLandingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(activeSessionProvider);

    // If there's an active session, go directly to shopping screen
    sessionAsync.whenData((session) {
      if (session != null && session.isActive) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.go(AppRoutes.inStoreShopping);
        });
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF8FFF8),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              // Hero
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: const Color(0xFF1B5E20).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.qr_code_scanner_rounded,
                        size: 80, color: Color(0xFF2E7D32)),
                    SizedBox(height: 12),
                    Text(
                      'Self Checkout',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B5E20),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Skip the queue',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF212121)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Scan products as you shop, pay from your phone, and show your exit QR to leave.',
                style: TextStyle(fontSize: 16, color: Color(0xFF757575)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              _StepTile(
                icon: Icons.store_outlined,
                step: '1',
                label: 'Scan store entry QR',
              ),
              const SizedBox(height: 12),
              _StepTile(
                icon: Icons.barcode_reader,
                step: '2',
                label: 'Scan each product',
              ),
              const SizedBox(height: 12),
              _StepTile(
                icon: Icons.payment_outlined,
                step: '3',
                label: 'Pay digitally',
              ),
              const SizedBox(height: 12),
              _StepTile(
                icon: Icons.exit_to_app_rounded,
                step: '4',
                label: 'Show exit QR & leave',
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _startShopping(context),
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Start In-Store Shopping'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startShopping(BuildContext context) async {
    final status = await Permission.camera.request();
    if (!context.mounted) return;

    if (status.isGranted) {
      context.push(AppRoutes.inStoreEntryQRScan);
    } else if (status.isPermanentlyDenied) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Camera Permission Required'),
          content: const Text(
              'Camera access is needed to scan QR codes and product barcodes. '
              'Please enable it in app settings.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  openAppSettings();
                },
                child: const Text('Open Settings')),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Camera permission denied. Cannot scan QR codes.')),
      );
    }
  }
}

class _StepTile extends StatelessWidget {
  final IconData icon;
  final String step;
  final String label;

  const _StepTile(
      {required this.icon, required this.step, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF2E7D32),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              step,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Icon(icon, color: const Color(0xFF388E3C), size: 22),
        const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF424242),
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}
