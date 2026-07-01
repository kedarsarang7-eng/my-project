import 'package:flutter/material.dart';

class SmartForm extends StatelessWidget {
  final GlobalKey<FormState>? formKey;
  final Widget child;
  final EdgeInsets? padding;

  const SmartForm({super.key, this.formKey, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Padding(
        padding: padding ?? const EdgeInsets.all(24.0),
        child: child,
      ),
    );
  }
}

class SmartTextFormField extends StatelessWidget {
  final String label;
  final String? hintText;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int? maxLines;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final VoidCallback? onTap;

  const SmartTextFormField({
    super.key,
    required this.label,
    this.hintText,
    this.controller,
    this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.maxLines = 1,
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
    this.readOnly = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          obscureText: obscureText,
          maxLines: maxLines,
          onChanged: onChanged,
          readOnly: readOnly,
          onTap: onTap,
          style: theme.textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: theme.hintColor),
            prefixIcon: prefixIcon != null
                ? IconTheme(
                    data: IconThemeData(color: theme.primaryColor),
                    child: prefixIcon!,
                  )
                : null,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: theme.cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.dividerColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.dividerColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.colorScheme.primary,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.colorScheme.error),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }
}
