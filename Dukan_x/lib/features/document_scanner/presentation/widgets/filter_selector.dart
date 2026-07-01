import 'package:flutter/material.dart';
import '../../domain/models/scanned_page.dart';

class FilterSelector extends StatelessWidget {
  final PageFilter currentFilter;
  final Function(PageFilter) onFilterChanged;

  const FilterSelector({
    super.key,
    required this.currentFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.black87,
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _FilterOption(
            label: "Original",
            filter: PageFilter.original,
            isSelected: currentFilter == PageFilter.original,
            onTap: () => onFilterChanged(PageFilter.original),
            color: Colors.grey,
          ),
          const SizedBox(width: 16),
          _FilterOption(
            label: "Magic Color",
            filter: PageFilter.magicColor,
            isSelected: currentFilter == PageFilter.magicColor,
            onTap: () => onFilterChanged(PageFilter.magicColor),
            color: Colors.blueAccent,
          ),
          const SizedBox(width: 16),
          _FilterOption(
            label: "B&W",
            filter: PageFilter.blackAndWhite,
            isSelected: currentFilter == PageFilter.blackAndWhite,
            onTap: () => onFilterChanged(PageFilter.blackAndWhite),
            color: Colors.white,
          ),
          const SizedBox(width: 16),
          _FilterOption(
            label: "Grayscale",
            filter: PageFilter.grayScale,
            isSelected: currentFilter == PageFilter.grayScale,
            onTap: () => onFilterChanged(PageFilter.grayScale),
            color: Colors.grey.shade400,
          ),
        ],
      ),
    );
  }
}

class _FilterOption extends StatelessWidget {
  final String label;
  final PageFilter filter;
  final bool isSelected;
  final VoidCallback onTap;
  final Color color;

  const _FilterOption({
    required this.label,
    required this.filter,
    required this.isSelected,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.cyan : Colors.transparent,
                width: 2,
              ),
              color: color.withOpacity(0.2),
            ),
            child: Icon(Icons.filter_b_and_w, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.cyan : Colors.white60,
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
