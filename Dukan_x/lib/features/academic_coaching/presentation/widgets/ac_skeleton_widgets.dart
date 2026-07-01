// ============================================================================
// ACADEMIC COACHING — SKELETON LOADING WIDGETS
// ============================================================================

import 'package:flutter/material.dart';

class AcSkeletonCard extends StatelessWidget {
  final double height;
  final EdgeInsetsGeometry margin;

  const AcSkeletonCard({
    super.key,
    this.height = 120,
    this.margin = const EdgeInsets.only(bottom: 12),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _buildSkeletonCircle(48),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildSkeletonLine(width: 150, height: 16),
                  const SizedBox(height: 8),
                  _buildSkeletonLine(width: 100, height: 12),
                  const SizedBox(height: 8),
                  _buildSkeletonLine(width: 80, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AcSkeletonGrid extends StatelessWidget {
  final int itemCount;
  final int crossAxisCount;

  const AcSkeletonGrid({
    super.key,
    this.itemCount = 6,
    this.crossAxisCount = 3,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.2,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) => _buildSkeletonBox(),
    );
  }
}

class AcSkeletonTable extends StatelessWidget {
  final int rowCount;

  const AcSkeletonTable({super.key, this.rowCount = 5});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: List.generate(
              4,
              (index) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildSkeletonLine(height: 14),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Rows
        ...List.generate(
          rowCount,
          (index) => Container(
            height: 56,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: List.generate(
                4,
                (colIndex) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildSkeletonLine(height: 12, width: colIndex == 0 ? 120 : 80),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class AcSkeletonSummaryCards extends StatelessWidget {
  final int count;

  const AcSkeletonSummaryCards({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        count,
        (index) => Expanded(
          child: Container(
            height: 100,
            margin: EdgeInsets.only(right: index < count - 1 ? 16 : 0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSkeletonCircle(28),
                  const Spacer(),
                  _buildSkeletonLine(width: 60, height: 24),
                  const SizedBox(height: 4),
                  _buildSkeletonLine(width: 80, height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _buildSkeletonCircle(double size) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: const Color(0xFFE2E8F0),
      shape: BoxShape.circle,
    ),
  );
}

Widget _buildSkeletonLine({double? width, double height = 12}) {
  return Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: const Color(0xFFE2E8F0),
      borderRadius: BorderRadius.circular(4),
    ),
  );
}

Widget _buildSkeletonBox({double? height}) {
  return Container(
    height: height,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSkeletonCircle(48),
          const SizedBox(height: 16),
          _buildSkeletonLine(width: 120, height: 16),
          const SizedBox(height: 8),
          _buildSkeletonLine(width: 80, height: 12),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSkeletonLine(width: 40, height: 12),
              _buildSkeletonLine(width: 60, height: 24),
            ],
          ),
        ],
      ),
    ),
  );
}

class AcShimmer extends StatefulWidget {
  final Widget child;

  const AcShimmer({super.key, required this.child});

  @override
  State<AcShimmer> createState() => _AcShimmerState();
}

class _AcShimmerState extends State<AcShimmer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: -1, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: const [
                Color(0xFFE2E8F0),
                Color(0xFFF1F5F9),
                Color(0xFFE2E8F0),
              ],
              stops: const [0.0, 0.5, 1.0],
              transform: GradientRotation(_animation.value * 3.14159),
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}
