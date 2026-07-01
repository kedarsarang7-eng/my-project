// ============================================================================
// Active Sessions Monitor (DukanX Operator Panel)
// ============================================================================
// Shows live in-store sessions with auto-refresh every 30 seconds.
// Allows staff to see who is currently shopping in the store.
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:dukanx/core/responsive/responsive.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class ActiveSession {
  final String sessionId;
  final String customerId;
  final String customerName;
  final int itemCount;
  final int totalCents;
  final DateTime startedAt;

  const ActiveSession({
    required this.sessionId,
    required this.customerId,
    required this.customerName,
    required this.itemCount,
    required this.totalCents,
    required this.startedAt,
  });

  factory ActiveSession.fromJson(Map<String, dynamic> json) {
    return ActiveSession(
      sessionId: json['sessionId'] as String,
      customerId: json['customerId'] as String? ?? '',
      customerName: json['customerName'] as String? ?? 'Guest',
      itemCount: (json['itemCount'] as num? ?? 0).toInt(),
      totalCents: (json['totalCents'] as num? ?? 0).toInt(),
      startedAt:
          DateTime.tryParse(json['startedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  String get durationDisplay {
    final diff = DateTime.now().difference(startedAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    return '${diff.inHours}h ${diff.inMinutes.remainder(60)}m';
  }

  String get totalDisplay => '₹${(totalCents / 100).toStringAsFixed(2)}';
}

// ── Provider ──────────────────────────────────────────────────────────────────

final _activeSessionsProvider = FutureProvider.autoDispose
    .family<
      List<ActiveSession>,
      ({String baseUrl, String token, String storeId})
    >((ref, params) async {
      final res = await http.get(
        Uri.parse(
          '${params.baseUrl}/v1/in-store/sessions/active?storeId=${params.storeId}',
        ),
        headers: {'Authorization': 'Bearer ${params.token}'},
      );
      if (res.statusCode != 200) return [];
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = body['data']?['sessions'] as List<dynamic>? ?? [];
      return list
          .map((e) => ActiveSession.fromJson(e as Map<String, dynamic>))
          .toList();
    });

// ── Screen ────────────────────────────────────────────────────────────────────

class ActiveSessionsScreen extends ConsumerStatefulWidget {
  final String apiBaseUrl;
  final String accessToken;
  final String storeId;

  const ActiveSessionsScreen({
    super.key,
    required this.apiBaseUrl,
    required this.accessToken,
    required this.storeId,
  });

  @override
  ConsumerState<ActiveSessionsScreen> createState() =>
      _ActiveSessionsScreenState();
}

class _ActiveSessionsScreenState extends ConsumerState<ActiveSessionsScreen> {
  Timer? _refreshTimer;

  late final _params = (
    baseUrl: widget.apiBaseUrl,
    token: widget.accessToken,
    storeId: widget.storeId,
  );

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) ref.invalidate(_activeSessionsProvider(_params));
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(_activeSessionsProvider(_params));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Shoppers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_activeSessionsProvider(_params)),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: Column(
          children: [
            // Live indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFF1B5E20).withValues(alpha: 0.07),
              child: Row(
                children: [
                  _PulseDot(),
                  const SizedBox(width: 8),
                  const Text(
                    'Live — refreshes every 30s',
                    style: TextStyle(
                      color: Color(0xFF2E7D32),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  sessionsAsync
                          .whenData(
                            (s) => Text(
                              '${s.length} active',
                              style: const TextStyle(
                                color: Color(0xFF2E7D32),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                          .value ??
                      const SizedBox.shrink(),
                ],
              ),
            ),

            Expanded(
              child: sessionsAsync.when(
                data: (sessions) {
                  if (sessions.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_off_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No active shoppers right now',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: sessions.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _SessionCard(session: sessions[i]),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off, color: Colors.grey, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        '$e',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () =>
                            ref.invalidate(_activeSessionsProvider(_params)),
                        child: const Text('Retry'),
                      ),
                    ],
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

// ── Session card ──────────────────────────────────────────────────────────────

class _SessionCard extends StatelessWidget {
  final ActiveSession session;
  const _SessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
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
            // Avatar
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFF2E7D32).withValues(alpha: 0.1),
              child: Text(
                session.customerName.isNotEmpty
                    ? session.customerName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Color(0xFF2E7D32),
                  fontWeight: FontWeight.bold,
                  fontSize: responsiveValue<double>(
                    context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop:
                        18.0, // PRESERVED: Desktop uses exactly 18 as before
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.customerName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.shopping_basket_outlined,
                        size: 13,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${session.itemCount} item${session.itemCount == 1 ? '' : 's'}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.timer_outlined,
                        size: 13,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        session.durationDisplay,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Cart total
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  session.totalDisplay,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'ACTIVE',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
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

// ── Pulsing dot ───────────────────────────────────────────────────────────────

class _PulseDot extends StatefulWidget {
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.5, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Color(0xFF2E7D32),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
