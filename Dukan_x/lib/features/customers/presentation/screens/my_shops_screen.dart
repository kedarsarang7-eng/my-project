// ============================================================================
// MY SHOPS SCREEN
// ============================================================================
// Lists all linked shops and allows switching context
// Uses ConnectionService to list and SessionManager to switch
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../services/connection_service.dart';
import '../../../../core/session/session_manager.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class MyShopsScreen extends ConsumerStatefulWidget {
  const MyShopsScreen({super.key});

  @override
  ConsumerState<MyShopsScreen> createState() => _MyShopsScreenState();
}

class _MyShopsScreenState extends ConsumerState<MyShopsScreen> {
  @override
  Widget build(BuildContext context) {
    // We can't easily watch the stream from DI in a stateless way without a provider wrapper
    // But we can use StreamBuilder directly for simplicity here

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "My Shops",
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push('/customer_link_shop');
        },
        icon: const Icon(Icons.add_link),
        label: const Text("Link Shop"),
      ),
      body: StreamBuilder<List<ConnectedShop>>(
        stream: sl<ConnectionService>().streamMyConnections(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final shops = snapshot.data ?? [];

          if (shops.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.store, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    "No shops linked yet",
                    style: GoogleFonts.outfit(
                      fontSize: responsiveValue<double>(
                        context,
                        mobile: 14.0,
                        tablet: 16.0,
                        desktop:
                            18.0, // PRESERVED: Desktop uses exactly 18 as before
                      ),
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => context.push('/customer_link_shop'),
                    child: const Text("Find a Shop"),
                  ),
                ],
              ),
            );
          }

          final currentOwnerId = sl<SessionManager>().ownerId;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: shops.length,
            itemBuilder: (context, index) {
              final shop = shops[index];
              final isSelected = shop.vendorId == currentOwnerId;
              return _ShopListItem(
                shop: shop,
                isSelected: isSelected,
                onTap: () => _switchShop(shop.vendorId),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _switchShop(String vendorId) async {
    final session = sl<SessionManager>();
    if (session.ownerId == vendorId) return;

    try {
      await session.switchShop(vendorId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Shop context switched!"),
            duration: Duration(milliseconds: 1500),
          ),
        );
        // Optionally pop back to home to refresh everything cleanly
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error switching shop: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _ShopListItem extends StatelessWidget {
  final ConnectedShop shop;
  final bool isSelected;
  final VoidCallback onTap;

  const _ShopListItem({
    required this.shop,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<Map<String, dynamic>>(
      stream: sl<ConnectionService>().streamShopDetails(shop.vendorId),
      builder: (context, snapshot) {
        // Use live data if available, fallback to cached data in 'shop' object
        final liveData = snapshot.data;
        final shopName = liveData?['shopName'] as String? ?? shop.shopName;
        // final shopAddress = liveData?['shopAddress'] as String? ?? 'No address';
        final logoUrl = liveData?['shopLogoUrl'] as String?;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? Colors.blue.withOpacity(0.2) : Colors.blue.shade50)
                : (isDark ? const Color(0xFF2A2A3E) : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? Colors.blue
                  : (isDark ? Colors.white10 : Colors.grey.shade200),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              if (!isDark && !isSelected)
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            onTap: onTap,
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: isSelected ? Colors.blue : Colors.grey.shade200,
              backgroundImage: logoUrl != null ? NetworkImage(logoUrl) : null,
              child: logoUrl == null
                  ? Icon(
                      Icons.store,
                      color: isSelected ? Colors.white : Colors.grey,
                    )
                  : null,
            ),
            title: Text(
              shopName,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            subtitle: Text(
              "ID: ${shop.vendorId.substring(0, 8)}...",
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: isDark ? Colors.white70 : Colors.grey.shade600,
              ),
            ),
            trailing: isSelected
                ? const Icon(Icons.check_circle, color: Colors.blue)
                : const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey,
                  ),
          ),
        );
      },
    );
  }
}
