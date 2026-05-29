// ============================================================================
// SCAN LANDING SCREEN — QR scan entry: validates vendor + table
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/pwa_api_service.dart';
import '../../utils/pwa_haptics.dart';
import '../../widgets/pwa_offline_banner.dart';
import '../../widgets/pwa_state_widgets.dart';

class ScanLandingScreen extends ConsumerStatefulWidget {
  final String vendorId;
  final String tableId;
  const ScanLandingScreen({
    super.key,
    required this.vendorId,
    required this.tableId,
  });
  @override
  ConsumerState<ScanLandingScreen> createState() => _ScanLandingScreenState();
}

class _ScanLandingScreenState extends ConsumerState<ScanLandingScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic> _vendor = {};
  bool _isLoading = true;
  bool _loadError = false;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _load();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final vendor = await PwaApiService.fetchVendorInfo(widget.vendorId);
    if (mounted) {
      setState(() {
        _vendor = vendor;
        _loadError = vendor['error'] != null;
        _isLoading = false;
      });
      _animCtrl.forward();
    }
    // Pre-warm the table-scoped JWT so the first order placement is instant.
    // Fire-and-forget: failure is non-fatal (placeOrder retries internally).
    if (!_loadError && widget.vendorId.isNotEmpty && widget.tableId.isNotEmpty) {
      PwaApiService.ensureTableToken(
        vendorId: widget.vendorId,
        tableId: widget.tableId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isValid = widget.vendorId.isNotEmpty && widget.tableId.isNotEmpty;

    return Scaffold(
      body: SafeArea(
        child: _isLoading
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
                      title: 'Could not load restaurant',
                      subtitle: 'Check connection and retry.',
                      onRetry: _load,
                    ),
                  ),
                ],
              )
            : FadeTransition(
                opacity: _fadeAnim,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const PwaOfflineBanner(),
                      // ── Hero banner ───────────────────────────────────────
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 52,
                          horizontal: 24,
                        ),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFF0C0A0A),
                              Color(0xFF1A0D04),
                              Color(0xFF0F0F0F),
                            ],
                            stops: [0.0, 0.55, 1.0],
                          ),
                        ),
                        child: Column(
                          children: [
                            // Logo with double-ring glow
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    const Color(0xFFEA580C).withValues(alpha: 0.25),
                                    const Color(0xFFEA580C).withValues(alpha: 0.05),
                                  ],
                                ),
                                border: Border.all(
                                  color: const Color(0xFFEA580C)
                                      .withValues(alpha: 0.55),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFEA580C)
                                        .withValues(alpha: 0.3),
                                    blurRadius: 28,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.restaurant_menu,
                                size: 48,
                                color: Color(0xFFEA580C),
                              ),
                            ),
                            const SizedBox(height: 22),
                            Text(
                              _vendor['name'] ?? 'Restaurant',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.6,
                              ),
                            ),
                            if (_vendor['tagline'] != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                _vendor['tagline'],
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                            if (widget.tableId.isNotEmpty) ...[
                              const SizedBox(height: 22),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFFEA580C)
                                          .withValues(alpha: 0.2),
                                      const Color(0xFFEA580C)
                                          .withValues(alpha: 0.08),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: const Color(0xFFEA580C)
                                        .withValues(alpha: 0.5),
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFEA580C)
                                          .withValues(alpha: 0.18),
                                      blurRadius: 14,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.table_restaurant,
                                      size: 16,
                                      color: Color(0xFFEA580C),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Table ${widget.tableId}',
                                      style: const TextStyle(
                                        color: Color(0xFFEA580C),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // ── CTA Buttons ────────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            if (!isValid)
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.red.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.warning_amber,
                                      color: Colors.red,
                                      size: 18,
                                    ),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Invalid QR code. Please scan the QR at your table again.',
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else ...[
                              // Primary CTA — gradient fill
                              _RestroCTAButton(
                                icon: Icons.menu_book,
                                label: 'Browse Menu & Order',
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFEA580C),
                                    Color(0xFFF97316),
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderColor: const Color(0xFFEA580C),
                                onTap: () async {
                                  await PwaHaptics.tap();
                                  if (!context.mounted) return;
                                  context.push(
                                    '/menu',
                                    extra: {
                                      'vendorId': widget.vendorId,
                                      'tableId': widget.tableId,
                                    },
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                              // Secondary CTA — outline
                              _RestroCTAButton(
                                icon: Icons.receipt_long,
                                label: 'View Running Bill',
                                gradient: null,
                                borderColor: const Color(0xFF334155),
                                onTap: () async {
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
                            ],
                            const SizedBox(height: 32),
                            // Info strip
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _infoChip(Icons.wifi_off, 'Works Offline'),
                                const SizedBox(width: 12),
                                _infoChip(Icons.speed, 'Instant Order'),
                                const SizedBox(width: 12),
                                _infoChip(Icons.receipt, 'Digital Bill'),
                              ],
                            ),
                            const SizedBox(height: 20),
                            // Optional sign-in CTA — never a gate, purely for
                            // past orders / loyalty (future feature).
                            TextButton.icon(
                              icon: const Icon(Icons.history, size: 16),
                              label: const Text('View Past Orders / Sign In'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white38,
                                textStyle: const TextStyle(fontSize: 13),
                              ),
                              onPressed: () => context.push('/login'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF334155),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Hoverable CTA button for restro landing screen
class _RestroCTAButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final LinearGradient? gradient;
  final Color borderColor;
  final VoidCallback onTap;

  const _RestroCTAButton({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.borderColor,
    required this.onTap,
  });

  @override
  State<_RestroCTAButton> createState() => _RestroCTAButtonState();
}

class _RestroCTAButtonState extends State<_RestroCTAButton> {
  final ValueNotifier<bool> _hovered = ValueNotifier(false);
  final ValueNotifier<bool> _pressed = ValueNotifier(false);

  @override
  void dispose() {
    _hovered.dispose();
    _pressed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _hovered.value = true,
      onExit: (_) => _hovered.value = false,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => _pressed.value = true,
        onTapUp: (_) => _pressed.value = false,
        onTapCancel: () => _pressed.value = false,
        behavior: HitTestBehavior.opaque,
        child: ValueListenableBuilder<bool>(
          valueListenable: _hovered,
          builder: (context, isHovered, _) {
            return ValueListenableBuilder<bool>(
              valueListenable: _pressed,
              builder: (context, isPressed, _) {
                final scale = isPressed ? 0.97 : 1.0;
                final lift = isPressed ? 0.0 : (isHovered ? -2.0 : 0.0);
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  curve: Curves.easeOutCubic,
                  transform: Matrix4.identity()
                    ..translateByDouble(0.0, lift, 0.0, 1.0)
                    ..scaleByDouble(scale, scale, 1.0, 1.0),
                  transformAlignment: Alignment.center,
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: widget.gradient != null
                        ? LinearGradient(
                            colors: [
                              widget.gradient!.colors[0].withValues(
                                  alpha: isHovered ? 1.0 : 0.9),
                              widget.gradient!.colors[1],
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          )
                        : null,
                    color: widget.gradient == null
                        ? (isHovered
                            ? const Color(0xFF1E293B)
                            : const Color(0xFF0F172A))
                        : null,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isHovered
                          ? widget.borderColor
                          : widget.borderColor.withValues(alpha: 0.55),
                      width: isHovered ? 1.4 : 1,
                    ),
                    boxShadow: isHovered && widget.gradient != null
                        ? [
                            BoxShadow(
                              color: const Color(0xFFEA580C)
                                  .withValues(alpha: 0.35),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            )
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        widget.icon,
                        size: 18,
                        color: widget.gradient != null
                            ? Colors.white
                            : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        widget.label,
                        style: TextStyle(
                          color: widget.gradient != null
                              ? Colors.white
                              : (isHovered
                                  ? Colors.white
                                  : const Color(0xFF94A3B8)),
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
