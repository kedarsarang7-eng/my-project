// ============================================================================
// KITCHEN DISPLAY SCREEN — Live KOT queue for kitchen staff
// ============================================================================
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/pos_providers.dart';
import '../../services/pos_api_service.dart';
import '../../services/pos_websocket_service.dart';

class KitchenDisplayScreen extends ConsumerStatefulWidget {
  const KitchenDisplayScreen({super.key});
  @override
  ConsumerState<KitchenDisplayScreen> createState() =>
      _KitchenDisplayScreenState();
}

class _KitchenDisplayScreenState extends ConsumerState<KitchenDisplayScreen> {
  List<Map<String, dynamic>> _kots = [];
  bool _isLoading = true;
  Timer? _pollTimer;
  StreamSubscription<PosWsEvent>? _wsSub;
  static const _orange = Color(0xFFEA580C);

  @override
  void initState() {
    super.initState();
    _load();
    _connectRealtime();
    // Poll every 10 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _load());
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    PosWebSocketService.instance.disconnect();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _connectRealtime() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('staff_token') ?? '';
    final session = ref.read(vendorSessionProvider);
    final businessId = session?.vendorId ?? prefs.getString('pos_vendor_id') ?? '';
    if (token.isEmpty || businessId.isEmpty) return;

    final ok = await PosWebSocketService.instance.connect(
      authToken: token,
      businessId: businessId,
      staffId: session?.staffName,
    );
    if (!ok) return;

    PosWebSocketService.instance.subscribe(const [
      'kot_created',
      'kot_status_updated',
    ]);
    _wsSub = PosWebSocketService.instance.events.listen((event) {
      if (event.event == 'kot_created' || event.event == 'kot_status_updated') {
        _load();
      }
    });
  }

  Future<void> _load() async {
    final session = ref.read(vendorSessionProvider);
    final kots = await PosApiService.fetchActiveKots(session?.vendorId ?? '');
    if (mounted) {
      setState(() {
        _kots = kots;
        _isLoading = false;
      });
    }
  }

  Future<void> _markDone(String kotId) async {
    final kot = _kots.firstWhere(
      (k) => (k['id'] ?? '').toString() == kotId,
      orElse: () => <String, dynamic>{},
    );
    final items = (kot['items'] as List?) ?? const [];
    for (final raw in items) {
      final item = raw as Map<String, dynamic>;
      final itemId = (item['id'] ?? '').toString();
      final current = (item['status'] ?? 'pending').toString();
      if (itemId.isEmpty || current == 'served' || current == 'cancelled') {
        continue;
      }
      final next = current == 'pending'
          ? 'preparing'
          : current == 'preparing'
          ? 'ready'
          : 'served';
      await PosApiService.updateKotItemStatus(kotId, itemId, next);
    }
    _load();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.amber;
      case 'preparing':
        return const Color(0xFF3B82F6);
      case 'ready':
        return Colors.green;
      case 'served':
        return const Color(0xFF22C55E);
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _kots
        .where(
          (k) =>
              k['status'] == 'pending' ||
              k['status'] == 'preparing' ||
              k['status'] == 'ready',
        )
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.kitchen, color: _orange, size: 18),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kitchen Display',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                Text(
                  'Live KOT Queue',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Live indicator
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _orange))
          : pending.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 80,
                    color: Colors.green[700],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Kitchen clear!\nAll orders served.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 320,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.75,
              ),
              itemCount: pending.length,
              itemBuilder: (ctx, i) => _buildKotCard(pending[i]),
            ),
    );
  }

  Widget _buildKotCard(Map<String, dynamic> kot) {
    final status = kot['status'] as String? ?? 'pending';
    final statusColor = _statusColor(status);
    final items = (kot['items'] as List?) ?? [];
    final kotNumber = kot['kotNumber']?.toString() ?? '?';
    final table = kot['tableNumber']?.toString() ?? '?';
    final createdAt = kot['createdAt'] != null
        ? DateTime.tryParse(kot['createdAt'].toString())
        : null;
    final elapsed = createdAt != null
        ? DateTime.now().difference(createdAt)
        : Duration.zero;
    final isOld = elapsed.inMinutes > 10;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOld
              ? Colors.red.withValues(alpha: 0.6)
              : statusColor.withValues(alpha: 0.4),
          width: isOld ? 2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'KOT #$kotNumber',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'T$table',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Timer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 12,
                  color: isOld ? Colors.red : Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  isOld
                      ? '${elapsed.inMinutes}m — URGENT'
                      : elapsed.inMinutes > 0
                      ? '${elapsed.inMinutes}m ago'
                      : 'Just now',
                  style: TextStyle(
                    fontSize: 11,
                    color: isOld ? Colors.red : Colors.grey,
                    fontWeight: isOld ? FontWeight.w700 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF2E2E2E)),
          // Items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (ctx, i) {
                final item = items[i];
                final variation = item['variationName'];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: _orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            '${item['qty']}x',
                            style: TextStyle(
                              color: _orange,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item['itemName'] +
                              (variation != null ? ' ($variation)' : ''),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Action button
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.check, size: 16),
                label: const Text(
                  'Advance Status',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                onPressed: () => _markDone(kot['id'] ?? ''),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
