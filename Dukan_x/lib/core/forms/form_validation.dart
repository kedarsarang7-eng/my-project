// ============================================================================
// FORM VALIDATION - Standardized Validators (P2 FIX)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Standardized form field validators
class FormValidators {
  FormValidators._();

  /// Required field validator
  static String? required(String? value, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Email validator
  static String? email(String? value) {
    if (value == null || value.isEmpty) return null;
    
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  /// Phone number validator (Indian format)
  static String? phone(String? value) {
    if (value == null || value.isEmpty) return null;
    
    // Remove all non-numeric characters
    final cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');
    
    if (cleaned.length != 10) {
      return 'Please enter a valid 10-digit mobile number';
    }
    return null;
  }

  /// GSTIN validator (Indian GST)
  static String? gstin(String? value) {
    if (value == null || value.isEmpty) return null;
    
    final gstRegex = RegExp(
      r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$',
    );
    
    if (!gstRegex.hasMatch(value.toUpperCase())) {
      return 'Please enter a valid GSTIN';
    }
    return null;
  }

  /// PAN validator (Indian PAN)
  static String? pan(String? value) {
    if (value == null || value.isEmpty) return null;
    
    final panRegex = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$');
    
    if (!panRegex.hasMatch(value.toUpperCase())) {
      return 'Please enter a valid PAN';
    }
    return null;
  }

  /// PIN code validator (Indian PIN)
  static String? pincode(String? value) {
    if (value == null || value.isEmpty) return null;
    
    final pinRegex = RegExp(r'^[0-9]{6}$');
    
    if (!pinRegex.hasMatch(value)) {
      return 'Please enter a valid 6-digit PIN code';
    }
    return null;
  }

  /// Amount validator
  static String? amount(String? value, {double? min, double? max}) {
    if (value == null || value.isEmpty) return null;
    
    final amount = double.tryParse(value.replaceAll(',', ''));
    
    if (amount == null) {
      return 'Please enter a valid amount';
    }
    
    if (amount < 0) {
      return 'Amount cannot be negative';
    }
    
    if (min != null && amount < min) {
      return 'Amount must be at least ₹${min.toStringAsFixed(2)}';
    }
    
    if (max != null && amount > max) {
      return 'Amount cannot exceed ₹${max.toStringAsFixed(2)}';
    }
    
    return null;
  }

  /// Quantity validator
  static String? quantity(String? value, {double? min, double? max}) {
    if (value == null || value.isEmpty) return null;
    
    final qty = double.tryParse(value);
    
    if (qty == null) {
      return 'Please enter a valid quantity';
    }
    
    if (qty <= 0) {
      return 'Quantity must be greater than zero';
    }
    
    if (min != null && qty < min) {
      return 'Minimum quantity is $min';
    }
    
    if (max != null && qty > max) {
      return 'Maximum quantity is $max';
    }
    
    return null;
  }

  /// Percentage validator (0-100)
  static String? percentage(String? value) {
    if (value == null || value.isEmpty) return null;
    
    final pct = double.tryParse(value);
    
    if (pct == null) {
      return 'Please enter a valid percentage';
    }
    
    if (pct < 0 || pct > 100) {
      return 'Percentage must be between 0 and 100';
    }
    
    return null;
  }

  /// Minimum length validator
  static String? minLength(String? value, int minLength, {String? fieldName}) {
    if (value == null || value.isEmpty) return null;
    
    if (value.length < minLength) {
      return '${fieldName ?? 'This field'} must be at least $minLength characters';
    }
    return null;
  }

  /// Maximum length validator
  static String? maxLength(String? value, int maxLength, {String? fieldName}) {
    if (value == null || value.isEmpty) return null;
    
    if (value.length > maxLength) {
      return '${fieldName ?? 'This field'} must not exceed $maxLength characters';
    }
    return null;
  }

  /// URL validator
  static String? url(String? value) {
    if (value == null || value.isEmpty) return null;
    
    final urlRegex = RegExp(
      r'^(http|https)://[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(/.*)?$',
    );
    
    if (!urlRegex.hasMatch(value)) {
      return 'Please enter a valid URL';
    }
    return null;
  }

  /// Date validator (DD/MM/YYYY format)
  static String? date(String? value) {
    if (value == null || value.isEmpty) return null;
    
    final parts = value.split('/');
    if (parts.length != 3) {
      return 'Please enter date in DD/MM/YYYY format';
    }
    
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    
    if (day == null || month == null || year == null) {
      return 'Please enter a valid date';
    }
    
    if (day < 1 || day > 31 || month < 1 || month > 12 || year < 1900) {
      return 'Please enter a valid date';
    }
    
    return null;
  }

  /// Combine multiple validators
  static String? compose(String? value, List<String? Function(String?)> validators) {
    for (final validator in validators) {
      final result = validator(value);
      if (result != null) return result;
    }
    return null;
  }
}

/// Standardized input formatters
class FormFormatters {
  FormFormatters._();

  /// Indian currency formatter (adds commas)
  static final currency = FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'));
  
  /// Numbers only
  static final numeric = FilteringTextInputFormatter.digitsOnly;
  
  /// Decimal numbers
  static final decimal = FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'));
  
  /// Phone number formatter (Indian)
  static final phone = FilteringTextInputFormatter.allow(RegExp(r'[0-9\+\-\s]'));
  
  /// Uppercase text
  static final uppercase = TextInputFormatter.withFunction((oldValue, newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  });
  
  /// Lowercase text
  static final lowercase = TextInputFormatter.withFunction((oldValue, newValue) {
    return newValue.copyWith(text: newValue.text.toLowerCase());
  });
  
  /// Remove special characters (alphanumeric only)
  static final alphanumeric = FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]'));
}

/// Standardized form field configurations
class FormFields {
  FormFields._();

  /// Standard text field
  static Widget text({
    required String label,
    String? hint,
    TextEditingController? controller,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
    TextInputType? keyboardType,
    int? maxLines,
    int? maxLength,
    bool enabled = true,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      inputFormatters: inputFormatters,
      keyboardType: keyboardType,
      maxLines: maxLines ?? 1,
      maxLength: maxLength,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        border: const OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.blue, width: 2),
        ),
        errorBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.red),
        ),
      ),
    );
  }

  /// Standard amount field (INR)
  static Widget amount({
    required String label,
    TextEditingController? controller,
    double? min,
    double? max,
    bool enabled = true,
    Function(String)? onChanged,
  }) {
    return text(
      label: label,
      controller: controller,
      hint: '0.00',
      validator: (v) => FormValidators.amount(v, min: min, max: max),
      inputFormatters: [FormFormatters.decimal],
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      prefixIcon: const Text('₹ ', style: TextStyle(fontSize: 18)),
      enabled: enabled,
    );
  }

  /// Phone number field
  static Widget phone({
    TextEditingController? controller,
    bool enabled = true,
  }) {
    return text(
      label: 'Phone Number',
      hint: '10-digit mobile number',
      controller: controller,
      validator: FormValidators.phone,
      inputFormatters: [FormFormatters.phone, LengthLimitingTextInputFormatter(10)],
      keyboardType: TextInputType.phone,
      prefixIcon: const Icon(Icons.phone),
      enabled: enabled,
    );
  }

  /// Email field
  static Widget email({
    TextEditingController? controller,
    bool enabled = true,
  }) {
    return text(
      label: 'Email',
      hint: 'example@email.com',
      controller: controller,
      validator: FormValidators.email,
      keyboardType: TextInputType.emailAddress,
      prefixIcon: const Icon(Icons.email),
      enabled: enabled,
    );
  }

  /// GSTIN field
  static Widget gstin({
    TextEditingController? controller,
    bool enabled = true,
  }) {
    return text(
      label: 'GSTIN',
      hint: '22AAAAA0000A1Z5',
      controller: controller,
      validator: FormValidators.gstin,
      inputFormatters: [FormFormatters.uppercase, LengthLimitingTextInputFormatter(15)],
      prefixIcon: const Icon(Icons.receipt),
      enabled: enabled,
    );
  }

  /// PAN field
  static Widget pan({
    TextEditingController? controller,
    bool enabled = true,
  }) {
    return text(
      label: 'PAN',
      hint: 'AAAAA0000A',
      controller: controller,
      validator: FormValidators.pan,
      inputFormatters: [FormFormatters.uppercase, LengthLimitingTextInputFormatter(10)],
      prefixIcon: const Icon(Icons.credit_card),
      enabled: enabled,
    );
  }

  /// PIN code field
  static Widget pincode({
    TextEditingController? controller,
    bool enabled = true,
  }) {
    return text(
      label: 'PIN Code',
      hint: '6-digit PIN',
      controller: controller,
      validator: FormValidators.pincode,
      inputFormatters: [FormFormatters.numeric, LengthLimitingTextInputFormatter(6)],
      keyboardType: TextInputType.number,
      prefixIcon: const Icon(Icons.location_on),
      enabled: enabled,
    );
  }

  /// Quantity field
  static Widget quantity({
    required String label,
    TextEditingController? controller,
    double? min,
    double? max,
    bool enabled = true,
  }) {
    return text(
      label: label,
      controller: controller,
      validator: (v) => FormValidators.quantity(v, min: min, max: max),
      inputFormatters: [FormFormatters.decimal],
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      prefixIcon: const Icon(Icons.numbers),
      enabled: enabled,
    );
  }

  /// Percentage field
  static Widget percentage({
    required String label,
    TextEditingController? controller,
    bool enabled = true,
  }) {
    return text(
      label: label,
      controller: controller,
      validator: FormValidators.percentage,
      inputFormatters: [FormFormatters.decimal],
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      suffixIcon: const Text('%', style: TextStyle(fontSize: 18)),
      enabled: enabled,
    );
  }
}
