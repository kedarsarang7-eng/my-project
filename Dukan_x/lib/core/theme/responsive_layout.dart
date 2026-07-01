// ============================================================================
// DESKTOP WINDOW-COMFORT HELPERS
// ============================================================================
// This file used to host an INDEPENDENT desktop breakpoint system
// (1280/1440/1920) with its own Form_Factor-style classification. That role has
// been consolidated into the single Responsive_System under
// `lib/core/responsive/` (see `responsive.dart`).
//
// Per Req 2.5, the legacy utilities here MUST NOT define breakpoint thresholds
// or Form_Factor classification independently. What remains is a small set of
// desktop window-comfort helpers (comfortable padding, content max-width, and a
// "window too small for the desktop layout" guard) that DEFER entirely to the
// consolidated `ResponsiveBreakpoints` / `ResponsiveContext` for all
// breakpoints and classification.
//
// For cross-platform responsive design (mobile/tablet/desktop), import the
// single barrel:
//
//     import 'package:dukanx/core/responsive/responsive.dart';
//
// Part of: cross-platform-responsive-ui

import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart';

import 'package:dukanx/core/responsive/responsive.dart';

/// Desktop window-comfort helpers.
///
/// These convenience helpers add comfortable spacing for desktop windows. They
/// hold NO breakpoint thresholds or Form_Factor classification of their own —
/// every decision defers to the consolidated Responsive_System
/// (`ResponsiveBreakpoints` / `responsiveValue`), which is the single source of
/// truth (Req 2.5).
class DesktopWindowComfort {
  const DesktopWindowComfort._();

  /// Maximum content width for desktop windows, so wide windows do not stretch
  /// content edge-to-edge. Defers to the single source of truth.
  static double get maxContentWidth => ResponsiveBreakpoints.maxContentWidth;

  /// Comfortable page padding that grows with the current Form_Factor.
  ///
  /// Defers to the consolidated classifier via [responsiveValue]; it does not
  /// define any width thresholds of its own. The tiers (16 / 24 / 32) mirror
  /// the legacy desktop comfort tiers, now expressed across the canonical
  /// Mobile / Tablet / Desktop Form_Factors.
  static EdgeInsets padding(BuildContext context) =>
      responsiveValue<EdgeInsets>(
        context,
        mobile: const EdgeInsets.all(16),
        tablet: const EdgeInsets.all(24),
        desktop: const EdgeInsets.all(32),
      );

  /// Comfortable horizontal page padding that grows with the current
  /// Form_Factor. Defers to the consolidated classifier via [responsiveValue].
  static EdgeInsets horizontalPadding(BuildContext context) =>
      responsiveValue<EdgeInsets>(
        context,
        mobile: const EdgeInsets.symmetric(horizontal: 16),
        tablet: const EdgeInsets.symmetric(horizontal: 24),
        desktop: const EdgeInsets.symmetric(horizontal: 32),
      );
}

/// Guards the desktop layout against an uncomfortably small window.
///
/// On non-desktop platforms (Android, iOS) this always passes through to the
/// [child], since those devices adapt naturally through the Responsive_System.
///
/// On desktop platforms (Windows, macOS, Linux, Web) it shows an informational
/// notice when the window has been shrunk below the Desktop Form_Factor. The
/// "is this a comfortable desktop window" decision DEFERS entirely to the
/// consolidated classifier via `context.isDesktop` (width >= 1100); this widget
/// defines no breakpoint thresholds of its own (Req 2.5).
class SafeResponsiveArea extends StatelessWidget {
  final Widget child;

  const SafeResponsiveArea({super.key, required this.child});

  /// Whether the host OS is a desktop platform. This is platform detection, not
  /// Form_Factor classification, so it is not a breakpoint authority.
  static bool get _isDesktopPlatform {
    if (kIsWeb) return true; // Web is treated as desktop here.
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  @override
  Widget build(BuildContext context) {
    // Mobile/tablet platforms always render the child — they adapt naturally
    // and must never be blocked by a desktop-only size warning.
    if (!_isDesktopPlatform) {
      return child;
    }

    // Defer the "comfortable desktop window" decision to the consolidated
    // Responsive_System. A desktop-platform window at Desktop width renders the
    // child directly; a window shrunk below the Desktop Form_Factor shows the
    // notice.
    if (context.isDesktop) {
      return child;
    }

    final size = MediaQuery.sizeOf(context);
    return Scaffold(
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange[200]!),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 48,
                color: Colors.orange[600],
              ),
              const SizedBox(height: 16),
              Text(
                'Window Too Small',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'The desktop layout is best viewed at a wider window. '
                'Current: ${size.width.toInt()}x${size.height.toInt()}',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.orange[700]),
              ),
              const SizedBox(height: 16),
              Text(
                'Some features may not display correctly.',
                style: TextStyle(fontSize: 12, color: Colors.orange[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
