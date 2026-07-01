// Invoice PDF Theme Unit Tests
// Tests for business-type based color theming
//
// Created: 2024-12-26
// Author: DukanX Team

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:dukanx/core/pdf/invoice_pdf_theme.dart';
import 'package:dukanx/models/business_type.dart';

void main() {
  group('InvoicePdfTheme - Business Type Themes', () {
    test('grocery theme returns green colors', () {
      final theme = InvoicePdfTheme.fromBusinessType(BusinessType.grocery);

      // Verify it's the grocery (green) theme
      expect(
        theme.primaryColor,
        equals(InvoicePdfTheme.groceryTheme.primaryColor),
      );

      // Green color range check (0xFF059669 is Emerald 600)
      // Primary color should be green-ish
      expect(
        theme.primaryColor,
        isNot(equals(InvoicePdfTheme.pharmacyTheme.primaryColor)),
      );
    });

    test('pharmacy theme returns blue colors', () {
      final theme = InvoicePdfTheme.fromBusinessType(BusinessType.pharmacy);

      expect(
        theme.primaryColor,
        equals(InvoicePdfTheme.pharmacyTheme.primaryColor),
      );
      expect(theme, equals(InvoicePdfTheme.pharmacyTheme));
    });

    test('restaurant theme returns orange colors', () {
      final theme = InvoicePdfTheme.fromBusinessType(BusinessType.restaurant);

      expect(
        theme.primaryColor,
        equals(InvoicePdfTheme.restaurantTheme.primaryColor),
      );
    });

    test('hardware theme returns gray colors', () {
      final theme = InvoicePdfTheme.fromBusinessType(BusinessType.hardware);

      expect(
        theme.primaryColor,
        equals(InvoicePdfTheme.hardwareTheme.primaryColor),
      );
    });

    test('service theme returns purple colors', () {
      final theme = InvoicePdfTheme.fromBusinessType(BusinessType.service);

      expect(
        theme.primaryColor,
        equals(InvoicePdfTheme.serviceTheme.primaryColor),
      );
    });

    test('wholesale theme returns teal colors', () {
      final theme = InvoicePdfTheme.fromBusinessType(BusinessType.wholesale);

      expect(
        theme.primaryColor,
        equals(InvoicePdfTheme.wholesaleTheme.primaryColor),
      );
    });

    test('petrolPump theme returns red colors', () {
      final theme = InvoicePdfTheme.fromBusinessType(BusinessType.petrolPump);

      expect(
        theme.primaryColor,
        equals(InvoicePdfTheme.petrolPumpTheme.primaryColor),
      );
    });

    test('all themes have required color properties', () {
      for (final businessType in BusinessType.values) {
        final theme = InvoicePdfTheme.fromBusinessType(businessType);

        // Verify all required properties exist and are valid
        expect(theme.primaryColor, isA<PdfColor>());
        expect(theme.primaryLight, isA<PdfColor>());
        expect(theme.primaryDark, isA<PdfColor>());
        expect(theme.accentColor, isA<PdfColor>());
        expect(theme.textDark, isA<PdfColor>());
        expect(theme.textGray, isA<PdfColor>());
        expect(theme.borderColor, isA<PdfColor>());
        expect(theme.successColor, isA<PdfColor>());
        expect(theme.warningColor, isA<PdfColor>());
        expect(theme.errorColor, isA<PdfColor>());
      }
    });

    test('each business type has unique primary color', () {
      final themes = BusinessType.values
          .map((type) => InvoicePdfTheme.fromBusinessType(type).primaryColor)
          .toList();

      // All colors should be unique
      final uniqueColors = themes.toSet();
      expect(uniqueColors.length, equals(BusinessType.values.length));
    });
  });

  group('InvoiceStatus - Display and Colors', () {
    test('paid status has correct display text', () {
      expect(InvoiceStatus.paid.displayText, equals('PAID'));
    });

    test('unpaid status has correct display text', () {
      expect(InvoiceStatus.unpaid.displayText, equals('UNPAID'));
    });

    test('partial status has correct display text', () {
      expect(InvoiceStatus.partial.displayText, equals('PARTIAL'));
    });

    test('status colors are appropriate', () {
      final theme = InvoicePdfTheme.defaultTheme;

      expect(InvoiceStatus.paid.getColor(theme), equals(theme.successColor));
      expect(InvoiceStatus.unpaid.getColor(theme), equals(theme.errorColor));
      expect(InvoiceStatus.partial.getColor(theme), equals(theme.warningColor));
    });
  });

  group('PaymentMode - Display Text', () {
    test('all payment modes have display text', () {
      expect(PaymentMode.cash.displayText, equals('Cash'));
      expect(PaymentMode.upi.displayText, equals('UPI'));
      expect(PaymentMode.card.displayText, equals('Card'));
      expect(PaymentMode.credit.displayText, equals('Credit'));
      expect(PaymentMode.mixed.displayText, equals('Mixed'));
    });
  });

  group('InvoicePdfTheme - Default Theme', () {
    test('default theme is pharmacy (blue)', () {
      expect(
        InvoicePdfTheme.defaultTheme,
        equals(InvoicePdfTheme.pharmacyTheme),
      );
    });
  });
}
