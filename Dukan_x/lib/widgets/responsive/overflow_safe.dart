import 'package:flutter/material.dart';

/// A label-on-left / value-on-right row that never overflows or overlaps at
/// elevated text scales or on narrow viewports.
///
/// Both children are wrapped in [Flexible] so the underlying [Row] can never
/// exceed its width budget (no `RenderFlex` overflow). The label is allowed to
/// shrink/ellipsize on a single line; the value is kept whole where it fits and
/// shrinks-to-fit (via [FittedBox] with [BoxFit.scaleDown]) rather than being
/// clipped when it cannot. A guaranteed [minGap] keeps the label and value
/// visually separated.
///
/// The row uses [MainAxisAlignment.spaceBetween] so that, whenever there is
/// free width, the label stays pinned to the leading edge and the value to the
/// trailing (right) edge — matching the original `Row(spaceBetween)` layout
/// these rows replaced (preserves the Windows desktop render under R11.3).
/// When width is tight, the `Flexible` children absorb the pressure (the label
/// ellipsizes, the value scales down) instead of overflowing, and [minGap]
/// still guarantees a positive separation.
///
/// Empty [label]/[value] strings are accepted without throwing.
class OverflowSafeLabelValueRow extends StatelessWidget {
  /// The label shown on the left side of the row.
  final String label;

  /// The value shown on the right side of the row. Ignored when
  /// [valueOverride] is provided.
  final String value;

  /// Optional style for the label text.
  final TextStyle? labelStyle;

  /// Optional style for the value text.
  final TextStyle? valueStyle;

  /// The guaranteed horizontal gap between the label and the value.
  final double minGap;

  /// Optional widget rendered in place of the value text (e.g. an inline
  /// input field). When supplied it is laid out inside the value's [Flexible]
  /// slot so the row remains overflow-safe.
  final Widget? valueOverride;

  const OverflowSafeLabelValueRow({
    super.key,
    required this.label,
    this.value = '',
    this.labelStyle,
    this.valueStyle,
    this.minGap = 12,
    this.valueOverride,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      // Keep the label leading-aligned and the value trailing-aligned (right
      // edge) whenever there is spare width, restoring the pre-hardening
      // spaceBetween appearance while the Flexible children keep it
      // overflow-safe when width is tight.
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Label: single line, ellipsizes when it cannot fit.
        Flexible(
          child: Text(
            label,
            style: labelStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: minGap),
        // Value: shrinks-to-fit and stays on a single visible row. A caller
        // can substitute their own widget via [valueOverride].
        Flexible(
          child:
              valueOverride ??
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  value,
                  style: valueStyle,
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
        ),
      ],
    );
  }
}

/// A bounded-width info banner with a leading icon and wrapping message text.
///
/// The banner is laid out as a [Row] whose [Text] is wrapped in an [Expanded]
/// so the message receives a real width budget and wraps naturally across the
/// banner instead of degenerating to one word per line. Because the icon has a
/// fixed intrinsic width and the text is constrained by [Expanded], the [Row]
/// can never overflow horizontally regardless of viewport or text scale.
///
/// The outer [Container] is explicitly `double.infinity` wide so the banner
/// always has a real width to fill, independent of the parent layout path.
///
/// An empty [message] is accepted without throwing (it simply renders nothing
/// while preserving the banner's layout constraints).
class OverflowSafeInfoBanner extends StatelessWidget {
  /// The leading icon shown at the start of the banner.
  final IconData icon;

  /// The message text. Wraps across the available banner width.
  final String message;

  /// Optional accent color applied to the icon, text, background tint and
  /// border. When null, the banner falls back to the theme's primary color.
  final Color? color;

  const OverflowSafeInfoBanner({
    super.key,
    required this.icon,
    required this.message,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final accent = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 20),
          const SizedBox(width: 12),
          // Expanded gives the text a bounded width so it wraps across the
          // banner rather than overflowing or breaking one word per line.
          Expanded(
            child: Text(
              message,
              softWrap: true,
              style: TextStyle(color: accent),
            ),
          ),
        ],
      ),
    );
  }
}
