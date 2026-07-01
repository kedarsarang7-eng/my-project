import 'package:flutter/material.dart';

/// Common screen wrapper for Academic Coaching module.
/// Provides consistent layout with title bar and action buttons.
class AcScreenWrapper extends StatelessWidget {
  final String title;
  final List<Widget>? actions;
  final Widget child;

  const AcScreenWrapper({
    super.key,
    required this.title,
    this.actions,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                ),
                if (actions != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: actions!,
                  ),
              ],
            ),
            const SizedBox(height: 24),
            // Content
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
