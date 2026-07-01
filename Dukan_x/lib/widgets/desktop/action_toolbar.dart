import 'package:flutter/material.dart';

class ActionToolbar extends StatelessWidget {
  final List<Widget> actions;
  final Widget? title;
  final Widget? searchBar;
  final VoidCallback? onFilter;
  final VoidCallback? onExport;
  final VoidCallback? onRefresh;

  const ActionToolbar({
    super.key,
    required this.actions,
    this.title,
    this.searchBar,
    this.onFilter,
    this.onExport,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (title != null) ...[
            title!,
            const SizedBox(width: 16),
            Container(height: 24, width: 1, color: theme.dividerColor),
            const SizedBox(width: 16),
          ],
          if (searchBar != null) ...[
            Expanded(child: searchBar!),
            const SizedBox(width: 16),
          ] else
            const Spacer(),

          // Action Buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onRefresh != null)
                _buildIconButton(
                  context,
                  icon: Icons.refresh_rounded,
                  tooltip: 'Refresh',
                  onTap: onRefresh!,
                ),
              if (onFilter != null)
                _buildIconButton(
                  context,
                  icon: Icons.filter_list_rounded,
                  tooltip: 'Filter',
                  onTap: onFilter!,
                ),
              if (onExport != null)
                _buildIconButton(
                  context,
                  icon: Icons.download_rounded,
                  tooltip: 'Export',
                  onTap: onExport!,
                ),
              if (actions.isNotEmpty) ...[
                if (onRefresh != null || onFilter != null || onExport != null)
                  const SizedBox(width: 12),
                ...actions.map(
                  (action) => Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: action,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: theme.iconTheme.color),
          ),
        ),
      ),
    );
  }
}
