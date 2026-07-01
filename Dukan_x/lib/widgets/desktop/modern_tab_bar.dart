import 'package:flutter/material.dart';
import '../../core/theme/futuristic_colors.dart';

class ModernTabBar extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final Function(int) onTabSelected;
  final bool isVertical;

  const ModernTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
    this.isVertical = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isVertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(tabs.length, (index) {
          final isSelected = index == selectedIndex;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => onTabSelected(index),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? FuturisticColors.primary.withOpacity(0.1)
                      : Colors.transparent,
                  border: Border(
                    left: BorderSide(
                      color: isSelected
                          ? FuturisticColors.primary
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Text(
                  tabs[index],
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : FuturisticColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }),
      );
    }

    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: FuturisticColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = index == selectedIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTabSelected(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isSelected
                      ? FuturisticColors.surfaceElevated
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                  border: isSelected
                      ? Border.all(color: Colors.white.withOpacity(0.05))
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  tabs[index],
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : FuturisticColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
