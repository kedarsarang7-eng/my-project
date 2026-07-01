import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerKPIRow extends StatelessWidget {
  final int itemCount;

  const ShimmerKPIRow({super.key, this.itemCount = 4});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: List.generate(
        itemCount,
        (_) => _ShimmerCard(
          width: 180,
          height: 120,
          baseColor: colorScheme.surfaceVariant,
          highlightColor: colorScheme.surface,
        ),
      ),
    );
  }
}

class ShimmerChartArea extends StatelessWidget {
  final double height;

  const ShimmerChartArea({super.key, this.height = 260});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return _ShimmerCard(
      width: double.infinity,
      height: height,
      baseColor: colorScheme.surfaceVariant,
      highlightColor: colorScheme.surface,
    );
  }
}

class ShimmerListItems extends StatelessWidget {
  final int itemCount;

  const ShimmerListItems({super.key, this.itemCount = 5});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: List.generate(itemCount, (index) {
        return Padding(
          padding: EdgeInsets.only(bottom: index == itemCount - 1 ? 0 : 12),
          child: _ListRowShimmer(
            baseColor: colorScheme.surfaceVariant,
            highlightColor: colorScheme.surface,
          ),
        );
      }),
    );
  }
}

class ShimmerGrid extends StatelessWidget {
  final int itemCount;
  final int crossAxisCount;

  const ShimmerGrid({
    super.key,
    this.itemCount = 6,
    this.crossAxisCount = 2,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.1,
      ),
      itemBuilder: (context, index) => _ShimmerCard(
        width: double.infinity,
        height: double.infinity,
        baseColor: colorScheme.surfaceVariant,
        highlightColor: colorScheme.surface,
      ),
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  final double width;
  final double height;
  final Color baseColor;
  final Color highlightColor;

  const _ShimmerCard({
    required this.width,
    required this.height,
    required this.baseColor,
    required this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}

class _ListRowShimmer extends StatelessWidget {
  final Color baseColor;
  final Color highlightColor;

  const _ListRowShimmer({
    required this.baseColor,
    required this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 160,
                  height: 12,
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 64,
            height: 20,
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ),
    );
  }
}
