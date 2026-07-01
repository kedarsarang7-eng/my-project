import 'package:flutter/material.dart';

/// WeighingScaleWidget — Real-time weighing scale display for grocery POS.
///
/// Features:
/// - Large weight display (7-segment style)
/// - Tare button to subtract container weight
/// - Auto-calculate line total when product is selected
/// - Unit toggle (kg/g)
/// - Animated weight transitions
///
/// Usage:
///   WeighingScaleWidget(
///     onWeightConfirmed: (weight, unit, tare) {
///       // Add to cart with weight as quantity
///     },
///     productName: 'Onion',
///     pricePerKg: 45.00,  // ₹45/kg
///   )
class WeighingScaleWidget extends StatefulWidget {
  /// Callback when weight is confirmed (user taps "Add to Bill")
  final void Function(double weight, String unit, double tare)? onWeightConfirmed;

  /// Optional product name to display
  final String? productName;

  /// Price per kg (for total calculation)
  final double? pricePerKg;

  /// Initial weight (for testing or pre-filled values)
  final double initialWeight;

  const WeighingScaleWidget({
    super.key,
    this.onWeightConfirmed,
    this.productName,
    this.pricePerKg,
    this.initialWeight = 0.0,
  });

  @override
  State<WeighingScaleWidget> createState() => _WeighingScaleWidgetState();
}

class _WeighingScaleWidgetState extends State<WeighingScaleWidget>
    with SingleTickerProviderStateMixin {
  double _grossWeight = 0.0;
  double _tare = 0.0;
  bool _isKg = true;
  late AnimationController _pulseController;

  double get _netWeight => (_grossWeight - _tare).clamp(0.0, double.infinity);
  double get _displayWeight => _isKg ? _netWeight : _netWeight * 1000;
  String get _unit => _isKg ? 'kg' : 'g';
  double? get _lineTotal =>
      widget.pricePerKg != null ? _netWeight * widget.pricePerKg! : null;

  @override
  void initState() {
    super.initState();
    _grossWeight = widget.initialWeight;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _setTare() {
    setState(() {
      _tare = _grossWeight;
    });
  }

  void _clearTare() {
    setState(() {
      _tare = 0.0;
    });
  }

  void _toggleUnit() {
    setState(() {
      _isKg = !_isKg;
    });
  }

  /// Simulate weight update (in production, this is called by the
  /// serial port listener connected to the USB scale)
  void updateWeight(double weightKg) {
    setState(() {
      _grossWeight = weightKg;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00D4FF).withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00D4FF).withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.scale_rounded,
                      color: Color(0xFF00D4FF), size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'WEIGHING SCALE',
                    style: TextStyle(
                      color: Color(0xFF00D4FF),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
              // Live indicator
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Color.lerp(
                        const Color(0xFF22C55E),
                        const Color(0xFF22C55E).withValues(alpha: 0.3),
                        _pulseController.value,
                      ),
                      shape: BoxShape.circle,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Weight display (main)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0A0A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF333333)),
            ),
            child: Column(
              children: [
                // Product name
                if (widget.productName != null) ...[
                  Text(
                    widget.productName!,
                    style: const TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                // Large weight number
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _isKg
                          ? _displayWeight.toStringAsFixed(3)
                          : _displayWeight.toStringAsFixed(0),
                      style: const TextStyle(
                        color: Color(0xFF00FF88),
                        fontSize: 48,
                        fontWeight: FontWeight.w300,
                        fontFamily: 'monospace',
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _unit,
                        style: const TextStyle(
                          color: Color(0xFF00FF88),
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                // Tare indicator
                if (_tare > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'TARE: ${_tare.toStringAsFixed(3)} kg',
                    style: const TextStyle(
                      color: Color(0xFFFF8800),
                      fontSize: 11,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Price / Total display (if product selected)
          if (widget.pricePerKg != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1B2A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF1B3A5C)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '₹${widget.pricePerKg!.toStringAsFixed(2)}/kg',
                    style: const TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '₹${(_lineTotal ?? 0).toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Action buttons row
          Row(
            children: [
              // Tare button
              Expanded(
                child: _ScaleButton(
                  label: _tare > 0 ? 'CLEAR TARE' : 'TARE',
                  icon: Icons.exposure_zero_rounded,
                  color: const Color(0xFFFF8800),
                  onPressed: _tare > 0 ? _clearTare : _setTare,
                ),
              ),
              const SizedBox(width: 8),
              // Unit toggle
              Expanded(
                child: _ScaleButton(
                  label: _isKg ? 'kg → g' : 'g → kg',
                  icon: Icons.swap_horiz_rounded,
                  color: const Color(0xFF00D4FF),
                  onPressed: _toggleUnit,
                ),
              ),
              const SizedBox(width: 8),
              // Add to bill
              Expanded(
                flex: 2,
                child: _ScaleButton(
                  label: 'ADD TO BILL',
                  icon: Icons.add_shopping_cart_rounded,
                  color: const Color(0xFF22C55E),
                  filled: true,
                  onPressed: _netWeight > 0
                      ? () => widget.onWeightConfirmed?.call(
                            _netWeight, _unit, _tare)
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScaleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool filled;
  final VoidCallback? onPressed;

  const _ScaleButton({
    required this.label,
    required this.icon,
    required this.color,
    this.filled = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: filled
                ? color.withValues(alpha: onPressed != null ? 0.2 : 0.05)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: color.withValues(alpha: onPressed != null ? 0.5 : 0.15),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 18,
                  color: color.withValues(alpha: onPressed != null ? 1 : 0.3)),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color.withValues(alpha: onPressed != null ? 1 : 0.3),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
