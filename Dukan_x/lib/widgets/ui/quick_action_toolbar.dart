import 'package:flutter/material.dart';
import '../../core/theme/futuristic_colors.dart';

class QuickActionToolbar extends StatelessWidget {
  final String title;
  final List<Widget> actions;
  final Widget? searchField;

  const QuickActionToolbar({
    super.key,
    required this.title,
    this.actions = const [],
    this.searchField,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: FuturisticColors.background,
        border: Border(
          bottom: BorderSide(color: FuturisticColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: FuturisticColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          if (searchField != null) ...[
            const SizedBox(width: 32),
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: searchField,
              ),
            ),
          ] else
            const Spacer(),
          const SizedBox(width: 16),
          ...actions.map(
            (a) => Padding(padding: const EdgeInsets.only(left: 12), child: a),
          ),
        ],
      ),
    );
  }
}
