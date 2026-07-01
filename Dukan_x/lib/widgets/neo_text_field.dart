import 'package:flutter/material.dart';

class NeoTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final TextInputType keyboardType;
  final bool isPassword;
  final VoidCallback? onTap;
  final bool readOnly;
  final ValueChanged<String>? onChanged;

  const NeoTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.keyboardType = TextInputType.text,
    this.isPassword = false,
    this.onTap,
    this.readOnly = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fillColor = isDark
        ? const Color(0xFF1E293B) // Slate 800 (original dark)
        : theme.colorScheme.surfaceContainerHighest;
    final borderColor = isDark
        ? Colors.white.withOpacity(0.1)
        : theme.colorScheme.outline.withOpacity(0.2);
    final textColor = isDark ? Colors.white : theme.colorScheme.onSurface;
    final hintColor = isDark ? Colors.white24 : theme.hintColor;
    final labelColor = isDark ? Colors.white54 : theme.colorScheme.onSurfaceVariant;
    final iconColor = isDark ? Colors.white54 : theme.colorScheme.onSurfaceVariant;

    return Container(
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.1 : 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: isPassword,
        onTap: onTap,
        readOnly: readOnly,
        onChanged: onChanged,
        style: theme.textTheme.bodyLarge?.copyWith(color: textColor),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintMaxLines: 1,
          prefixIcon: icon != null ? Icon(icon, color: iconColor) : null,
          labelStyle: TextStyle(color: labelColor),
          hintStyle: TextStyle(color: hintColor),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}

