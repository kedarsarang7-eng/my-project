import 'package:flutter/material.dart';
import '../../domain/models/user_shortcut_config.dart';
import '../../domain/services/shortcut_data_provider.dart';
import '../../../../core/theme/futuristic_colors.dart';

class ShortcutItem extends StatefulWidget {
  final UserShortcutConfig config;
  final ShortcutBadgeData? badge;
  final VoidCallback onTap;
  final VoidCallback onRightClick;

  const ShortcutItem({
    super.key,
    required this.config,
    this.badge,
    required this.onTap,
    required this.onRightClick,
  });

  @override
  State<ShortcutItem> createState() => _ShortcutItemState();
}

class _ShortcutItemState extends State<ShortcutItem> {
  bool _isHovered = false;

  // Map icon name to IconData
  IconData _getIcon(String iconName) {
    // This is a simplified mapper. In production, we'd use a more comprehensive map
    // or a package like flutter_iconpicker's map.
    switch (iconName) {
      case 'add_shopping_cart':
        return Icons.add_shopping_cart;
      case 'history':
        return Icons.history;
      case 'attach_money':
        return Icons.attach_money;
      case 'person_add':
        return Icons.person_add;
      case 'account_balance':
        return Icons.account_balance;
      case 'warning_amber':
        return Icons.warning_amber;
      case 'today':
        return Icons.today;
      case 'menu_book':
        return Icons.menu_book;
      case 'cloud_upload':
        return Icons.cloud_upload;
      case 'sync_problem':
        return Icons.sync_problem;
      case 'personal_injury':
        return Icons.personal_injury;
      case 'medication':
        return Icons.medication;
      case 'point_of_sale':
        return Icons.point_of_sale;
      default:
        return Icons.star_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTap: widget.onRightClick,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _isHovered
                ? FuturisticColors.accent1.withOpacity(0.1)
                : widget.config.isPriority
                ? FuturisticColors.primary.withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.config.isPriority
                  ? FuturisticColors.accent1
                  : Colors.white.withOpacity(0.1),
            ),
          ),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      _getIcon(widget.config.definition.iconName),
                      color: FuturisticColors.accent1,
                      size: 20,
                    ),
                    if (widget.badge != null && widget.badge!.hasData)
                      Positioned(
                        right: -8,
                        top: -8,
                        child: _buildBadge(widget.badge!),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
                Text(
                  widget.config.definition.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(ShortcutBadgeData badge) {
    String display;
    if (badge.count != null) {
      display = badge.count.toString();
    } else if (badge.amount != null) {
      // Simple rough formatting K/M
      if (badge.amount! > 1000000) {
        display = '${(badge.amount! / 1000000).toStringAsFixed(1)}M';
      } else if (badge.amount! > 1000) {
        display = '${(badge.amount! / 1000).toStringAsFixed(1)}K';
      } else {
        display = badge.amount!.toInt().toString();
      }
    } else {
      display = '!';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: badge.isWarning
            ? FuturisticColors.error
            : FuturisticColors.accent1,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: FuturisticColors.surface, width: 1.5),
      ),
      child: Text(
        display,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
