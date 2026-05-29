// ============================================================================
// ORDER TRACKING SCREEN — Live KOT status stepper
// ============================================================================
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import '../../services/pwa_api_service.dart';
import '../../services/pwa_websocket_service.dart';
import '../../utils/pwa_haptics.dart';
import '../../widgets/pwa_offline_banner.dart';
import '../../widgets/pwa_state_widgets.dart';

class OrderTrackingScreen extends ConsumerStatefulWidget {
  final String vendorId;
  final String orderId;
  final String tableId;
  const OrderTrackingScreen({
    super.key,
    required this.vendorId,
    required this.orderId,
    required this.tableId,
  });
  @override
  ConsumerState<OrderTrackingScreen> createState() =>
      _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends ConsumerState<OrderTrackingScreen> {
  static const _storage = FlutterSecureStorage();
  Map<String, dynamic> _order = {};
  bool _isLoading = true;
  bool _loadError = false;
  Timer? _pollTimer;
  StreamSubscription<PwaWsEvent>? _wsSub;
  bool _wsConnected = false;
  static const _orange = Color(0xFFEA580C);

  static const _statuses = ['placed', 'preparing', 'ready', 'served'];
  static const _labels = ['Order Placed', 'Being Prepared', 'Ready!', 'Served'];
  static const _icons = [
    Icons.check_circle_outline,
    Icons.kitchen,
    Icons.room_service_outlined,
    Icons.sentiment_very_satisfied,
  ];

  @override
  void initState() {
    super.initState();
    _load();
    _connectRealtime();
    _pollTimer = Timer.periodic(const Duration(seconds: 12), (_) => _load());
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    PwaWebSocketService.instance.disconnect();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _connectRealtime() async {
    final token = await _storage.read(key: 'accessToken') ?? '';
    if (token.isEmpty) return;

    final connected = await PwaWebSocketService.instance.connect(
      authToken: token,
      vendorId: widget.vendorId,
      customerId: widget.orderId,
    );
    if (!connected) return;

    PwaWebSocketService.instance.subscribe(const [
      'order_updated',
      'kot_status_updated',
      'bill_updated',
    ]);

    if (mounted) {
      setState(() => _wsConnected = true);
    } else {
      _wsConnected = true;
    }
    _wsSub = PwaWebSocketService.instance.stream.listen((event) {
      final evtOrderId =
          (event.data['orderId'] ?? event.data['id'] ?? '').toString();
      if (evtOrderId == widget.orderId) {
        _load();
      }
    });
  }

  Future<void> _load() async {
    final order = await PwaApiService.fetchOrderStatus(
      widget.vendorId,
      widget.orderId,
    );
    if (mounted) {
      setState(() {
        _order = order ?? {};
        _loadError = order == null;
        _isLoading = false;
      });
    }
  }

  int get _currentStep {
    final s = _order['status'] as String? ?? 'placed';
    return _statuses.indexOf(s).clamp(0, 3);
  }

  @override
  Widget build(BuildContext context) {
    final kots = (_order['kots'] as List?) ?? [];
    final eta = _order['estimatedMinutes'] as int? ?? 15;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Order Status',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? const Column(
              children: [
                PwaOfflineBanner(),
                Expanded(child: PwaSkeletonList(itemCount: 4)),
              ],
            )
          : _loadError
          ? Column(
              children: [
                const PwaOfflineBanner(),
                Expanded(
                  child: PwaErrorState(
                    title: 'Order status unavailable',
                    subtitle: 'Could not fetch latest status.',
                    onRetry: _load,
                  ),
                ),
              ],
            )
          : Column(
              children: [
                const PwaOfflineBanner(),
                Expanded(
                  child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // ── ETA Banner ───────────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 20,
                      horizontal: 24,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _orange.withValues(alpha: 0.15),
                          _orange.withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _orange.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _currentStep >= 2 ? '🎉' : '⏱️',
                          style: const TextStyle(fontSize: 40),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _currentStep >= 2
                              ? 'Your order is ready!'
                              : 'Approx. $eta min',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Order #${widget.orderId.length > 8 ? widget.orderId.substring(0, 8) : widget.orderId}',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _wsConnected
                              ? 'Live updates connected'
                              : 'Realtime unavailable, auto-refresh active',
                          style: TextStyle(
                            color: _wsConnected ? Colors.green : Colors.grey[500],
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  // ── Status Stepper ───────────────────────────────────────
                  ...List.generate(_statuses.length, (i) {
                    final isDone = i <= _currentStep;
                    final isActive = i == _currentStep;
                    final color = isDone ? _orange : Colors.grey[700]!;
                    return Column(
                      children: [
                        Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 400),
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isDone
                                    ? _orange.withValues(alpha: 0.15)
                                    : const Color(0xFF1A1A1A),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: color,
                                  width: isActive ? 2 : 1,
                                ),
                              ),
                              child: Icon(_icons[i], color: color, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _labels[i],
                                    style: TextStyle(
                                      color: isDone
                                          ? Colors.white
                                          : Colors.grey[600],
                                      fontWeight: isDone
                                          ? FontWeight.w700
                                          : FontWeight.normal,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (isActive)
                                    const Text(
                                      'In progress…',
                                      style: TextStyle(
                                        color: _orange,
                                        fontSize: 11,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (isDone)
                              const Icon(
                                Icons.check_circle,
                                color: _orange,
                                size: 18,
                              ),
                          ],
                        ),
                        if (i < _statuses.length - 1)
                          Padding(
                            padding: const EdgeInsets.only(left: 21),
                            child: Container(
                              width: 2,
                              height: 24,
                              color: i < _currentStep
                                  ? _orange.withValues(alpha: 0.4)
                                  : const Color(0xFF2E2E2E),
                            ),
                          ),
                      ],
                    );
                  }),
                  const SizedBox(height: 28),
                  // ── KOT details ──────────────────────────────────────────
                  if (kots.isNotEmpty) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'ORDER DETAILS',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF2E2E2E)),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: kots.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: Color(0xFF2E2E2E)),
                        itemBuilder: (ctx, ki) {
                          final kot = kots[ki];
                          final items = (kot['items'] as List?) ?? [];
                          return Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'KOT #${kot['kotNumber']}',
                                  style: const TextStyle(
                                    color: _orange,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ...items.map(
                                  (item) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      children: [
                                        const Text(
                                          '•  ',
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                        Text(
                                          '${item['qty']}× ${item['itemName']}',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF2E2E2E)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.receipt_long, size: 16),
                      label: const Text('View Bill'),
                      onPressed: () async {
                        await PwaHaptics.tap();
                        if (!context.mounted) return;
                        context.push(
                          '/bill',
                          extra: {
                            'vendorId': widget.vendorId,
                            'tableId': widget.tableId,
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
                ),
              ],
            ),
    );
  }
}
