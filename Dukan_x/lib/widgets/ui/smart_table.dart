import 'package:flutter/material.dart';
import '../../core/theme/futuristic_colors.dart';

/// A modern, high-density smart table for Enterprise Desktop use.
/// Features: Sticky header, standardized styling, row hover effects, and strict spacing.
class SmartTable<T> extends StatelessWidget {
  final List<SmartTableColumn<T>> columns;
  final List<T> data;
  final Function(T item)? onRowClick;
  final Function(T item)? onRowEdit;
  final Function(T item)? onRowDelete;
  final bool isLoading;
  final String emptyMessage;

  const SmartTable({
    super.key,
    required this.columns,
    required this.data,
    this.onRowClick,
    this.onRowEdit,
    this.onRowDelete,
    this.isLoading = false,
    this.emptyMessage = 'No records found',
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 48,
              color: FuturisticColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: const TextStyle(
                color: FuturisticColors.textSecondary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: FuturisticColors.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FuturisticColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // HEADER
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: FuturisticColors.surfaceHighlight,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: columns
                  .map(
                    (col) => Expanded(
                      flex: col.flex,
                      child: Text(
                        col.title.toUpperCase(),
                        style: const TextStyle(
                          color: FuturisticColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const Divider(
            height: 1,
            thickness: 1,
            color: FuturisticColors.border,
          ),

          // BODY
          Expanded(
            child: ListView.separated(
              itemCount: data.length,
              separatorBuilder: (_, _) => const Divider(
                height: 1,
                thickness: 0.5,
                color: FuturisticColors.border,
              ),
              itemBuilder: (context, index) {
                final item = data[index];
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    hoverColor: FuturisticColors.surfaceHighlight.withOpacity(
                      0.5,
                    ),
                    onTap: onRowClick != null ? () => onRowClick!(item) : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: columns
                            .map(
                              (col) => Expanded(
                                flex: col.flex,
                                child: col.builder != null
                                    ? col.builder!(item)
                                    : Text(
                                        col.valueMapper!(item),
                                        style: const TextStyle(
                                          color: FuturisticColors.textPrimary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class SmartTableColumn<T> {
  final String title;
  final int flex;
  final String Function(T item)? valueMapper;
  final Widget Function(T item)? builder;

  const SmartTableColumn({
    required this.title,
    this.flex = 1,
    this.valueMapper,
    this.builder,
  }) : assert(valueMapper != null || builder != null);
}
