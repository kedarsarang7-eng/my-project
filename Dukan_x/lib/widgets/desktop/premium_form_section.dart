import 'package:flutter/material.dart';
import '../../core/theme/futuristic_colors.dart';

/// Premium Form Section
///
/// A futuristic form section with:
/// - Section title with optional subtitle
/// - Glass card container
/// - 2 or 3 column grid layout for fields
/// - Consistent spacing
class PremiumFormSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final int columns;
  final double columnSpacing;
  final double rowSpacing;
  final EdgeInsets? padding;
  final Color? accentColor;

  const PremiumFormSection({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
    this.columns = 2,
    this.columnSpacing = 24,
    this.rowSpacing = 20,
    this.padding,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? FuturisticColors.premiumBlue;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: FuturisticColors.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withOpacity(0.05),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 12,
                            color: FuturisticColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Form Fields
          Padding(
            padding: padding ?? const EdgeInsets.all(24),
            child: _buildFieldGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldGrid() {
    // If only one column or few items, use simple column
    if (columns == 1 || children.length <= 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children.asMap().entries.map((entry) {
          final index = entry.key;
          final child = entry.value;
          return Padding(
            padding: EdgeInsets.only(
              bottom: index < children.length - 1 ? rowSpacing : 0,
            ),
            child: child,
          );
        }).toList(),
      );
    }

    // Build grid
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += columns) {
      final rowChildren = <Widget>[];
      for (var j = 0; j < columns; j++) {
        final index = i + j;
        if (index < children.length) {
          rowChildren.add(Expanded(child: children[index]));
        } else {
          rowChildren.add(const Expanded(child: SizedBox.shrink()));
        }
        if (j < columns - 1) {
          rowChildren.add(SizedBox(width: columnSpacing));
        }
      }
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rowChildren,
        ),
      );
      if (i + columns < children.length) {
        rows.add(SizedBox(height: rowSpacing));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}

/// Premium Text Field
///
/// A styled text field for futuristic forms
class PremiumTextField extends StatefulWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool enabled;
  final int? maxLines;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool readOnly;

  const PremiumTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.prefixIcon,
    this.suffix,
    this.enabled = true,
    this.maxLines = 1,
    this.onChanged,
    this.onTap,
    this.readOnly = false,
  });

  @override
  State<PremiumTextField> createState() => _PremiumTextFieldState();
}

class _PremiumTextFieldState extends State<PremiumTextField> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label
        Text(
          widget.label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: _isFocused
                ? FuturisticColors.premiumBlue
                : FuturisticColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        // Input
        Focus(
          onFocusChange: (focused) => setState(() => _isFocused = focused),
          child: TextFormField(
            controller: widget.controller,
            validator: widget.validator,
            keyboardType: widget.keyboardType,
            obscureText: widget.obscureText,
            enabled: widget.enabled,
            maxLines: widget.maxLines,
            onChanged: widget.onChanged,
            onTap: widget.onTap,
            readOnly: widget.readOnly,
            style: const TextStyle(fontSize: 14, color: Colors.white),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: TextStyle(
                fontSize: 14,
                color: FuturisticColors.textSecondary.withOpacity(0.5),
              ),
              prefixIcon: widget.prefixIcon != null
                  ? Icon(
                      widget.prefixIcon,
                      size: 20,
                      color: _isFocused
                          ? FuturisticColors.premiumBlue
                          : FuturisticColors.textSecondary,
                    )
                  : null,
              suffix: widget.suffix,
              filled: true,
              fillColor: FuturisticColors.background.withOpacity(0.5),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: FuturisticColors.border.withOpacity(0.5),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: FuturisticColors.premiumBlue.withOpacity(0.7),
                  width: 1.5,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: FuturisticColors.error.withOpacity(0.7),
                  width: 1,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: FuturisticColors.error,
                  width: 1.5,
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: FuturisticColors.border.withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Premium Dropdown Field
class PremiumDropdownField<T> extends StatefulWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? hint;
  final IconData? prefixIcon;

  const PremiumDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
    this.prefixIcon,
  });

  @override
  State<PremiumDropdownField<T>> createState() =>
      _PremiumDropdownFieldState<T>();
}

class _PremiumDropdownFieldState<T> extends State<PremiumDropdownField<T>> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: _isFocused
                ? FuturisticColors.premiumBlue
                : FuturisticColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Focus(
          onFocusChange: (focused) => setState(() => _isFocused = focused),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: FuturisticColors.background.withOpacity(0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _isFocused
                    ? FuturisticColors.premiumBlue.withOpacity(0.7)
                    : FuturisticColors.border.withOpacity(0.5),
                width: _isFocused ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                if (widget.prefixIcon != null) ...[
                  Icon(
                    widget.prefixIcon,
                    size: 20,
                    color: _isFocused
                        ? FuturisticColors.premiumBlue
                        : FuturisticColors.textSecondary,
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<T>(
                      value: widget.value,
                      items: widget.items,
                      onChanged: widget.onChanged,
                      hint: widget.hint != null
                          ? Text(
                              widget.hint!,
                              style: TextStyle(
                                fontSize: 14,
                                color: FuturisticColors.textSecondary
                                    .withOpacity(0.5),
                              ),
                            )
                          : null,
                      isExpanded: true,
                      dropdownColor: FuturisticColors.surface,
                      style: const TextStyle(fontSize: 14, color: Colors.white),
                      icon: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: FuturisticColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
