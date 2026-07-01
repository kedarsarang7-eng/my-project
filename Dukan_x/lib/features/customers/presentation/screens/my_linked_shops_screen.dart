// ============================================================================
// MY LINKED SHOPS SCREEN
// ============================================================================
// Customer dashboard showing all linked shops with business type icons,
// outstanding balances, and quick access to shop-specific bills.
//
// Author: DukanX Engineering
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dukanx/core/compat/firebase_auth_compat.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/repository/shop_link_repository.dart';
import '../../../../core/database/app_database.dart';
import '../../../../providers/app_state_providers.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Business type icons for visual differentiation
IconData _getBusinessTypeIcon(String? businessType) {
  switch (businessType?.toLowerCase()) {
    case 'grocery':
      return Icons.shopping_basket;
    case 'petrol_pump':
    case 'fuel':
      return Icons.local_gas_station;
    case 'medical':
    case 'pharmacy':
      return Icons.medical_services;
    case 'restaurant':
    case 'food':
      return Icons.restaurant;
    case 'electronics':
    case 'mobile':
      return Icons.phone_android;
    case 'cloth':
    case 'clothing':
      return Icons.checkroom;
    case 'hardware':
      return Icons.hardware;
    case 'general':
    default:
      return Icons.store;
  }
}

/// Business type color for visual differentiation
Color _getBusinessTypeColor(String? businessType) {
  switch (businessType?.toLowerCase()) {
    case 'grocery':
      return const Color(0xFF10B981); // Green
    case 'petrol_pump':
    case 'fuel':
      return const Color(0xFFF59E0B); // Amber
    case 'medical':
    case 'pharmacy':
      return const Color(0xFFEF4444); // Red
    case 'restaurant':
    case 'food':
      return const Color(0xFFF97316); // Orange
    case 'electronics':
    case 'mobile':
      return const Color(0xFF3B82F6); // Blue
    case 'cloth':
    case 'clothing':
      return const Color(0xFFA855F7); // Purple
    case 'hardware':
      return const Color(0xFF6B7280); // Gray
    case 'general':
    default:
      return const Color(0xFF6366F1); // Indigo
  }
}

class MyLinkedShopsScreen extends ConsumerWidget {
  const MyLinkedShopsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeStateProvider);
    final isDark = theme.isDark;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.login, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Please login to view linked shops',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    final shopLinkRepo = sl<ShopLinkRepository>();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.grey[50],
      appBar: AppBar(
        title: const Text('My Linked Shops'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: responsiveValue<double>(
            context,
            mobile: 16,
            tablet: 18,
            desktop: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => context.push('/qr-scanner'),
            tooltip: 'Scan Shop QR',
          ),
        ],
      ),
      body: StreamBuilder<List<ShopLinkEntity>>(
        stream: shopLinkRepo.watchActiveLinksForCustomer(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(
                  responsiveValue<double>(
                    context,
                    mobile: 16,
                    tablet: 20,
                    desktop: 24,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading shops: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final links = snapshot.data ?? [];

          if (links.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(
                  responsiveValue<double>(
                    context,
                    mobile: 16,
                    tablet: 20,
                    desktop: 32, // PRESERVED: Desktop uses exactly 32 as before
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(
                        responsiveValue<double>(
                          context,
                          mobile: 16,
                          tablet: 20,
                          desktop: 24,
                        ),
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.store_mall_directory,
                        size: 64,
                        color: isDark ? Colors.white38 : Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No Linked Shops Yet',
                      style: TextStyle(
                        fontSize: responsiveValue<double>(
                          context,
                          mobile: 16,
                          tablet: 18,
                          desktop: 20,
                        ),
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Scan a shop\'s QR code to get started',
                      style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () => context.push('/qr-scanner'),
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Scan Shop QR'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: links.length,
            itemBuilder: (context, index) {
              final link = links[index];
              final icon = _getBusinessTypeIcon(link.businessType);
              final color = _getBusinessTypeColor(link.businessType);
              final hasDues = link.outstandingBalance > 0;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      // Navigate to shop-specific bills
                      context.push(
                        '/shop-bills',
                        extra: {
                          'shopId': link.shopId,
                          'shopName': link.shopName,
                          'businessType': link.businessType,
                        },
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // Shop Icon with business type color
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(icon, color: color, size: 28),
                          ),
                          const SizedBox(width: 16),

                          // Shop Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  link.shopName,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  link.businessType
                                          ?.replaceAll('_', ' ')
                                          .toUpperCase() ??
                                      'GENERAL STORE',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: color,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Outstanding Balance
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₹${link.outstandingBalance.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: responsiveValue<double>(
                                    context,
                                    mobile: 14.0,
                                    tablet: 16.0,
                                    desktop:
                                        18.0, // PRESERVED: Desktop uses exactly 18 as before
                                  ),
                                  fontWeight: FontWeight.bold,
                                  color: hasDues
                                      ? Colors.red
                                      : (isDark
                                            ? Colors.green[400]
                                            : Colors.green),
                                ),
                              ),
                              Text(
                                hasDues ? 'due' : 'clear',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: hasDues
                                      ? Colors.red[300]
                                      : (isDark
                                            ? Colors.green[400]
                                            : Colors.green[600]),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(width: 8),
                          Icon(
                            Icons.chevron_right,
                            color: isDark ? Colors.white38 : Colors.grey[400],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
