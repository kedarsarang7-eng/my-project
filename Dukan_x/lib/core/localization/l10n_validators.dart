// =============================================================================
// L10nValidators — Localized form validators
// =============================================================================
// All validation error messages come from ARB translations.
// Zero hardcoded English strings.
//
// Usage:
//   TextFormField(
//     validator: L10nValidators.required(context, fieldName: l10n.emailLabel),
//   )
//
//   TextFormField(
//     validator: L10nValidators.compose([
//       L10nValidators.required(context, fieldName: l10n.phone),
//       L10nValidators.phone(context),
//     ]),
//   )
// =============================================================================

import 'package:flutter/material.dart';
import '../../generated/app_localizations.dart';

typedef FormValidator = String? Function(String?);

class L10nValidators {
  L10nValidators._();

  // ---------------------------------------------------------------------------
  // CORE VALIDATORS
  // ---------------------------------------------------------------------------

  /// Field is required (non-empty).
  static FormValidator required(
    BuildContext context, {
    required String fieldName,
  }) {
    final l = AppLocalizations.of(context)!;
    return (value) {
      if (value == null || value.trim().isEmpty) {
        return l.validationRequired(fieldName);
      }
      return null;
    };
  }

  /// Minimum length check.
  static FormValidator minLength(
    BuildContext context, {
    required String fieldName,
    required int min,
  }) {
    final l = AppLocalizations.of(context)!;
    return (value) {
      if (value != null && value.trim().length < min) {
        return l.validationMinLength(fieldName, min);
      }
      return null;
    };
  }

  /// Maximum length check.
  static FormValidator maxLength(
    BuildContext context, {
    required String fieldName,
    required int max,
  }) {
    final l = AppLocalizations.of(context)!;
    return (value) {
      if (value != null && value.trim().length > max) {
        return l.validationMaxLength(fieldName, max);
      }
      return null;
    };
  }

  // ---------------------------------------------------------------------------
  // CONTACT VALIDATORS
  // ---------------------------------------------------------------------------

  /// Valid email address.
  static FormValidator email(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
    );
    return (value) {
      if (value == null || value.trim().isEmpty) return null;
      if (!emailRegex.hasMatch(value.trim())) {
        return l.validationInvalidEmail;
      }
      return null;
    };
  }

  /// Valid Indian 10-digit mobile number.
  static FormValidator phone(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final phoneRegex = RegExp(r'^[6-9]\d{9}$');
    return (value) {
      if (value == null || value.trim().isEmpty) return null;
      final digits = value.replaceAll(RegExp(r'[\s\-+()]'), '');
      final normalized = digits.startsWith('91') && digits.length == 12
          ? digits.substring(2)
          : digits;
      if (!phoneRegex.hasMatch(normalized)) {
        return l.validationInvalidPhone;
      }
      return null;
    };
  }

  // ---------------------------------------------------------------------------
  // BUSINESS VALIDATORS
  // ---------------------------------------------------------------------------

  /// Valid 15-character GSTIN.
  static FormValidator gstin(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    // Format: 2-digit state code + 10-char PAN + 1Z + 1 check digit
    final gstinRegex = RegExp(
      r'^[0-3][0-9][A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$',
    );
    return (value) {
      if (value == null || value.trim().isEmpty) return null;
      if (!gstinRegex.hasMatch(value.trim().toUpperCase())) {
        return l.validationInvalidGstin;
      }
      return null;
    };
  }

  /// Valid 10-character PAN.
  static FormValidator pan(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final panRegex = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$');
    return (value) {
      if (value == null || value.trim().isEmpty) return null;
      if (!panRegex.hasMatch(value.trim().toUpperCase())) {
        return l.validationInvalidPan;
      }
      return null;
    };
  }

  /// Positive number (int or double).
  static FormValidator positiveNumber(
    BuildContext context, {
    required String fieldName,
    bool allowZero = false,
  }) {
    final l = AppLocalizations.of(context)!;
    return (value) {
      if (value == null || value.trim().isEmpty) return null;
      final parsed = double.tryParse(value.trim());
      if (parsed == null) {
        return l.validationPositiveNumber(fieldName);
      }
      if (!allowZero && parsed <= 0) {
        return l.validationAmountZero;
      }
      if (allowZero && parsed < 0) {
        return l.validationPositiveNumber(fieldName);
      }
      return null;
    };
  }

  /// Amount > 0.
  static FormValidator amount(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return (value) {
      if (value == null || value.trim().isEmpty) return null;
      final parsed = double.tryParse(
        value.trim().replaceAll(',', '').replaceAll('₹', ''),
      );
      if (parsed == null || parsed <= 0) {
        return l.validationAmountZero;
      }
      return null;
    };
  }

  // ---------------------------------------------------------------------------
  // DATE VALIDATORS
  // ---------------------------------------------------------------------------

  /// Date must be in the future (for due dates).
  static FormValidator futureDate(
    BuildContext context, {
    required String fieldName,
  }) {
    final l = AppLocalizations.of(context)!;
    return (value) {
      if (value == null || value.trim().isEmpty) return null;
      final parts = value.split('/');
      if (parts.length != 3) return l.validationFutureDate(fieldName);
      final date = DateTime.tryParse(
        '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}',
      );
      if (date == null) return l.validationFutureDate(fieldName);
      if (date.isBefore(DateTime.now())) {
        return l.validationFutureDate(fieldName);
      }
      return null;
    };
  }

  /// Date must be in the past (for birthdates, purchase dates).
  static FormValidator pastDate(
    BuildContext context, {
    required String fieldName,
  }) {
    final l = AppLocalizations.of(context)!;
    return (value) {
      if (value == null || value.trim().isEmpty) return null;
      final parts = value.split('/');
      if (parts.length != 3) return l.validationPastDate(fieldName);
      final date = DateTime.tryParse(
        '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}',
      );
      if (date == null) return l.validationPastDate(fieldName);
      if (date.isAfter(DateTime.now())) {
        return l.validationPastDate(fieldName);
      }
      return null;
    };
  }

  // ---------------------------------------------------------------------------
  // PASSWORD VALIDATORS
  // ---------------------------------------------------------------------------

  /// Strong password: 8+ chars, uppercase, number.
  static FormValidator password(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return (value) {
      if (value == null || value.isEmpty) return null;
      if (value.length < 8 ||
          !value.contains(RegExp(r'[A-Z]')) ||
          !value.contains(RegExp(r'[0-9]'))) {
        return l.validationPasswordWeak;
      }
      return null;
    };
  }

  /// Confirm password matches.
  static FormValidator confirmPassword(
    BuildContext context, {
    required String Function() getPassword,
  }) {
    final l = AppLocalizations.of(context)!;
    return (value) {
      if (value == null || value.isEmpty) return null;
      if (value != getPassword()) {
        return l.validationMismatch(l.passwordLabel, l.passwordLabel);
      }
      return null;
    };
  }

  // ---------------------------------------------------------------------------
  // COMPOSE — combine multiple validators
  // ---------------------------------------------------------------------------

  /// Runs validators in order, returns first error found.
  static FormValidator compose(List<FormValidator> validators) {
    return (value) {
      for (final v in validators) {
        final result = v(value);
        if (result != null) return result;
      }
      return null;
    };
  }

  /// Marks a field as required AND applies additional validators.
  static FormValidator requiredWith(
    BuildContext context, {
    required String fieldName,
    List<FormValidator> additional = const [],
  }) {
    return compose([required(context, fieldName: fieldName), ...additional]);
  }
}
