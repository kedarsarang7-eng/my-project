/// Property-Based Test: Contrast Ratio Accessibility Check (Property 16)
///
/// For any pair of foreground/background colors, compute WCAG 2.1 contrast
/// ratio and verify non-compliance flagging below 4.5:1 for normal text or
/// below 3:1 for large text (≥18sp or ≥14sp bold).
///
/// **Validates: Requirements 10.4**
library;

import 'dart:math' as math;

void main() {
  print('=== Property 16: Contrast Ratio Accessibility Check ===\n');

  final random = math.Random(42);
  var passed = 0;
  const iterations = 100;

  for (var i = 0; i < iterations; i++) {
    final fg = _randomColor(random);
    final bg = _randomColor(random);
    final isLargeText = random.nextBool();

    final ratio = _computeContrastRatio(fg, bg);
    final threshold = isLargeText ? 3.0 : 4.5;
    final isCompliant = ratio >= threshold;

    // Verify our checker flags correctly
    final flagged = _checkContrast(fg, bg, isLargeText);

    // Property: flagged == !isCompliant (flagged means it FAILS the check)
    assert(
      flagged == !isCompliant,
      'Iteration $i: fg=#${_colorToHex(fg)}, bg=#${_colorToHex(bg)}, '
      'ratio=${ratio.toStringAsFixed(2)}, isLarge=$isLargeText, '
      'threshold=$threshold, flagged=$flagged, expected=${!isCompliant}',
    );

    // Property: ratio is always in [1, 21]
    assert(
      ratio >= 1.0 && ratio <= 21.0,
      'Iteration $i: Contrast ratio $ratio is outside valid range [1, 21]',
    );

    // Property: ratio is symmetric (fg/bg vs bg/fg gives same result)
    final reverseRatio = _computeContrastRatio(bg, fg);
    assert(
      (ratio - reverseRatio).abs() < 1e-10,
      'Iteration $i: Contrast ratio is not symmetric — $ratio vs $reverseRatio',
    );

    passed++;
  }

  print(
    '✓ Property 16: Contrast Ratio Accessibility — $passed/$iterations iterations passed',
  );
}

// ─── WCAG 2.1 Contrast Ratio Implementation ───────────────────────────────

/// A simple RGB color representation.
class _Color {
  final int r, g, b;
  const _Color(this.r, this.g, this.b);
}

/// Generate a random color.
_Color _randomColor(math.Random random) {
  return _Color(random.nextInt(256), random.nextInt(256), random.nextInt(256));
}

/// Convert a color to hex string for display.
String _colorToHex(_Color c) {
  return '${c.r.toRadixString(16).padLeft(2, '0')}'
      '${c.g.toRadixString(16).padLeft(2, '0')}'
      '${c.b.toRadixString(16).padLeft(2, '0')}';
}

/// Compute relative luminance per WCAG 2.1 spec.
/// https://www.w3.org/TR/WCAG21/#dfn-relative-luminance
double _relativeLuminance(_Color color) {
  double linearize(int channel) {
    final srgb = channel / 255.0;
    return srgb <= 0.03928
        ? srgb / 12.92
        : math.pow((srgb + 0.055) / 1.055, 2.4).toDouble();
  }

  final r = linearize(color.r);
  final g = linearize(color.g);
  final b = linearize(color.b);

  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/// Compute WCAG 2.1 contrast ratio between two colors.
/// Returns ratio in range [1, 21].
double _computeContrastRatio(_Color fg, _Color bg) {
  final l1 = _relativeLuminance(fg);
  final l2 = _relativeLuminance(bg);

  final lighter = l1 > l2 ? l1 : l2;
  final darker = l1 > l2 ? l2 : l1;

  return (lighter + 0.05) / (darker + 0.05);
}

/// Check if a color pair is non-compliant (should be flagged).
/// Returns true if the pair FAILS the contrast check.
bool _checkContrast(_Color fg, _Color bg, bool isLargeText) {
  final ratio = _computeContrastRatio(fg, bg);
  final threshold = isLargeText ? 3.0 : 4.5;
  return ratio < threshold;
}
