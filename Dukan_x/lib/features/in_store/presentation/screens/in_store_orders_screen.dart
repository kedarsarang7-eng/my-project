// ============================================================================
// In-Store Orders Tab (DukanX Operator Panel)
// ============================================================================
// Shows all IN_STORE_SCAN orders for the current business.
// Accessible from the main operator navigation.
// ============================================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:dukanx/core/responsive/responsive.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class InStoreOrderSummary {
  final String orderId;
  final String sessionId;
  final String customerId;
  final String status;
  final int totalCents;
  final int itemCount;
  final bool exitVerified;
  final DateTime createdAt;

  const InStoreOrderSummary({
    required this.orderId,
    required this.sessionId,
    required this.customerId,
    required this.status,
    required this.totalCents,
    required this.itemCount,
    required this.exitVerified,
    required this.createdAt,
  });

  factory InStoreOrderSummary.fromJson(Map<String, dynamic> json) {
    return InStoreOrderSummary(
      orderId: json['orderId'] as String,
      sessionId: json['sessionId'] as String? ?? '',
      customerId: json['customerId'] as String? ?? '',
      status: json['status'] as String? ?? 'UNKNOWN',
      totalCents: (json['totalCents'] as num? ?? 0).toInt(),
      itemCount: (json['itemCount'] as num? ??
              (json['cartItems'] as List?)?.length ??
              0)
          .toInt(),
      exitVerified: json['exitQR']?['verified'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  String get totalDisplay =>
      '₹${(totalCents / 100).toStringAsFixed(2)}';
}

// ── Provider ──────────────────────────────────────────────────────────────────

final _inStoreOrdersProvider = FutureProvider.autoDispose
    .family<List<InStoreOrderSummary>, ({String baseUrl, String token, String tenantPK})>(
  (ref, params) async {
    final res = await http.get(
      Uri.parse('${params.baseUrl}/v1/in-store/orders/today')
          .replace(queryParameters: {}),
      headers: {
        'Authorization': 'Bearer ${params.token}',
      },
    );
    if (res.statusCode != 200) return [];
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final list = body['data']?['orders'] as List<dynamic>? ?? [];
    return list
        .map((e) => InStoreOrderSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  },
);

// ── Screen ────────────────────────────────────────────────────────────────────

class InStoreOrdersScreen extends ConsumerWidget {
  final String apiBaseUrl;
  final String accessToken;
  final String tenantId;

  const InStoreOrdersScreen({
    super.key,
    required this.apiBaseUrl,
    required this.accessToken,
    required this.tenantId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = (
      baseUrl: apiBaseUrl,
      token: accessToken,
      tenantPK: tenantId,
    );
    final ordersAsync = ref.watch(_inStoreOrdersProvider(params));

    return Scaffold(
      appBar: AppBar(
        title: const Text('In-Store Orders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_inStoreOrdersProvider(params)),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: ordersAsync.when(
        data: (orders) {
          if (orders.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shopping_cart_outlined,
                      size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No in-store orders today',
                      style: TextStyle(
                          fontSize: 16, color: Colors.grey)),
                ],
              ),
            );
          }

          // Stats bar
          final confirmed = orders.where((o) => o.status == 'CONFIRMED').length;
          final pending = orders.where((o) => o.status == 'PAYMENT_PENDING').length;
          final totalRevenue = orders
              .where((o) => o.status == 'CONFIRMED')
              .fold(0, (sum, o) => sum + o.totalCents);

          return Column(
            children: [
              _StatsBar(
                confirmed: confirmed,
                pending: pending,
                totalRevenue: totalRevenue,
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: orders.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _OrderCard(order: orders[i]),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text('Failed to load: $e',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () =>
                    ref.invalidate(_inStoreOrdersProvider(params)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

// ── Stats bar ─────────────────────────────────────────────────────────────────

class _StatsBar extends StatelessWidget {
  final int confirmed;
  final int pending;
  final int totalRevenue;

  const _StatsBar({
    required this.confirmed,
    required this.pending,
    required this.totalRevenue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1B5E20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _Stat(
              label: 'Confirmed',
              value: '$confirmed',
              color: Colors.greenAccent),
          const _Divider(),
          _Stat(
              label: 'Pending',
              value: '$pending',
              color: Colors.orangeAccent),
          const _Divider(),
          _Stat(
            label: 'Revenue',
            value: '₹${(totalRevenue / 100).toStringAsFixed(0)}',
            color: Colors.white,
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Stat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: responsiveValue<double>(context,
                    mobile: 16.0,
                    tablet: 18.0,
                    desktop: 20.0,  // PRESERVED: Desktop uses exactly 20 as before
                  ))),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
        height: 36, width: 1, color: Colors.white.withValues(alpha: 0.3));
  }
}

// ── Order card ────────────────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  final InStoreOrderSummary order;

  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (order.status) {
      'CONFIRMED' => Colors.green,
      'PAYMENT_PENDING' => Colors.orange,
      'CANCELLED' => Colors.red,
      _ => Colors.grey,
    };

    final timeStr =
        DateFormat('hh:mm a').format(order.createdAt.toLocal());

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Status dot
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(right: 14),
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            // Order info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          order.orderId.replaceAll('INSTORE-', '#'),
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              fontFamily: 'monospace'),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(timeStr,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${order.itemCount} item${order.itemCount == 1 ? '' : 's'}',
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          order.status.replaceAll('_', ' '),
                          style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (order.exitVerified) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.verified,
                            size: 14, color: Colors.blue),
                        const Text(' Exited',
                            style: TextStyle(
                                color: Colors.blue, fontSize: 11)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              order.totalDisplay,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
