import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../services/connection_service.dart';
import '../../../../providers/app_state_providers.dart';
import 'shop_confirmation_screen.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class ManualShopAddScreen extends ConsumerStatefulWidget {
  const ManualShopAddScreen({super.key});

  @override
  ConsumerState<ManualShopAddScreen> createState() =>
      _ManualShopAddScreenState();
}

class _ManualShopAddScreenState extends ConsumerState<ManualShopAddScreen> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  String? _error;

  Future<void> _verifyAndProceed() async {
    final input = _controller.text.trim();
    if (input.isEmpty) {
      setState(() => _error = "Please enter a Shop ID");
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Search for shop using ConnectionService
      final shops = await sl<ConnectionService>().searchShops(input);
      if (shops.isNotEmpty) {
        if (mounted) {
          // Navigate to confirmation screen with shop data
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ShopConfirmationScreen(
                ownerUid: input,
                shopData: shops.first,
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _error = "Shop not found. Please verify the ID.";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = "Error verifying ID: $e";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeStateProvider);
    final isDark = theme.isDark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.grey[50],
      appBar: AppBar(
        title: const Text("Enter Shop ID"),
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
        child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Enter Manual Code",
              style: TextStyle(
                fontSize: responsiveValue<double>(context, mobile: 18, tablet: 20, desktop: 24),
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Ask the shop owner for their Shop ID or Code.",
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _controller,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                labelText: "Shop ID",
                labelStyle: TextStyle(
                  color: isDark ? Colors.white54 : Colors.grey,
                ),
                hintText: "e.g. 7X892L...",
                hintStyle: TextStyle(
                  color: isDark ? Colors.white24 : Colors.black26,
                ),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                ),
                errorText: _error,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verifyAndProceed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Verify & Proceed",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
