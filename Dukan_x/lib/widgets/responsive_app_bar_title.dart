import 'package:flutter/material.dart';
import 'package:dukanx/core/responsive/responsive_layout.dart';

/// A responsive AppBar title widget that prevents text overflow on mobile.
///
/// Ensures the title renders on a single line with ellipsis truncation
/// and uses a responsive font size (16 on mobile, 20 on desktop/tablet).
class ResponsiveAppBarTitle extends StatelessWidget {
  /// The title text to display.
  final String title;

  /// Optional text style override. If provided, font size will be adjusted
  /// for mobile while preserving other style properties.
  final TextStyle? style;

  const ResponsiveAppBarTitle({super.key, required this.title, this.style});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style:
          style?.copyWith(fontSize: context.isMobile ? 16 : style!.fontSize) ??
          TextStyle(fontSize: context.isMobile ? 16 : 20),
    );
  }
}
