// Filter Carousel Widget
//
// Horizontal swipeable filter selector with live preview.
// Futuristic pill-style indicators.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/p2d_theme.dart';

/// Available image filters
enum P2DFilter {
  reality('Reality'),
  digitalClean('Digital Clean'),
  ultraBW('Ultra B/W'),
  receiptBoost('Receipt Boost'),
  sharpPro('Sharp Pro');

  final String label;
  const P2DFilter(this.label);
}

class FilterCarousel extends StatefulWidget {
  final P2DFilter selectedFilter;
  final ValueChanged<P2DFilter> onFilterChanged;

  const FilterCarousel({
    super.key,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  @override
  State<FilterCarousel> createState() => _FilterCarouselState();
}

class _FilterCarouselState extends State<FilterCarousel> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: widget.selectedFilter.index,
      viewportFraction: 0.35,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Current filter label
        Text(
          widget.selectedFilter.label,
          style: const TextStyle(
            color: kP2DAccentCyan,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),

        // Filter carousel
        SizedBox(
          height: 40,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              HapticFeedback.selectionClick();
              widget.onFilterChanged(P2DFilter.values[index]);
            },
            itemCount: P2DFilter.values.length,
            itemBuilder: (context, index) {
              final filter = P2DFilter.values[index];
              final isSelected = filter == widget.selectedFilter;

              return GestureDetector(
                onTap: () {
                  _pageController.animateToPage(
                    index,
                    duration: kP2DAnimationNormal,
                    curve: Curves.easeInOut,
                  );
                },
                child: AnimatedContainer(
                  duration: kP2DAnimationFast,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: isSelected
                        ? kP2DAccentCyan.withOpacity(0.2)
                        : kP2DGlassSurface,
                    border: Border.all(
                      color: isSelected ? kP2DAccentCyan : kP2DGlassBorder,
                      width: isSelected ? 1.5 : 1,
                    ),
                    boxShadow: isSelected
                        ? [kP2DNeonGlow(kP2DAccentCyan, blur: 10)]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      filter.label,
                      style: TextStyle(
                        color: isSelected ? kP2DAccentCyan : kP2DTextSecondary,
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Dots indicator
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: P2DFilter.values.map((filter) {
            final isSelected = filter == widget.selectedFilter;
            return AnimatedContainer(
              duration: kP2DAnimationFast,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isSelected ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: isSelected ? kP2DAccentCyan : kP2DTextMuted,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
