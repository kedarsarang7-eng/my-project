// Feature: pharmacy-vertical-remediation
// Task 11.4 — Example test for configured/absent Drug License Number rendering.
//
// REQUIREMENT UNDER TEST
//   R14.5: "THE System SHALL include an automated test verifying that the
//   configured Drug License Number value appears in the pharmacy invoice header
//   output when a value is configured, and is absent when no value is
//   configured." (supported by R14.2 — render when configured; R14.3 — omit
//   without error when absent.)
//
// UNIT UNDER TEST
//   `InvoicePdfWidgets.buildHeader(... drugLicenseNumber: ...)`
//   (lib/core/pdf/invoice_pdf_widgets.dart). This is the real pharmacy invoice
//   header builder wired up by task 11.1. We exercise it through the existing
//   rendering API rather than refactoring a helper out of it.
//
// HOW THE ASSERTION WORKS
//   We build a one-page PDF whose body is the header widget, then render the
//   document to bytes with compression disabled. With the default built-in
//   (Helvetica) font, `pw.Text` content is written verbatim into the PDF
//   content stream, so the configured license value can be located by scanning
//   the decoded bytes. The renderer emits each whitespace-separated word as its
//   own text token, so we assert on contiguous tokens: the "D.L." label word
//   and the plain-alphanumeric license value (which has no spaces).
//
//   * CONFIGURED  -> the value (and the "D.L. No:" label) is present in output.
//   * NOT CONFIGURED (null / empty) -> the value and label are absent, and the
//     export completes without throwing (R14.3).

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:dukanx/core/di/service_locator.dart';
import 'package:dukanx/core/services/currency_service.dart';
import 'package:dukanx/core/pdf/invoice_pdf_theme.dart';
import 'package:dukanx/core/pdf/invoice_pdf_widgets.dart';

void main() {
  // The InvoicePdfWidgets constructor reads the active currency symbol via the
  // service locator. Register a real CurrencyService once for these tests.
  setUpAll(() {
    if (!sl.isRegistered<CurrencyService>()) {
      sl.registerSingleton<CurrencyService>(CurrencyService());
    }
  });

  /// Builds the pharmacy invoice header with the given (optional) license and
  /// returns the rendered PDF bytes decoded as a searchable string.
  Future<String> renderHeaderText({String? drugLicenseNumber}) async {
    final widgets = InvoicePdfWidgets(
      theme: InvoicePdfTheme.pharmacyTheme,
      labels: const {'proprietor': 'Proprietor', 'mobile': 'Mobile'},
    );

    // compress: false keeps the content stream uncompressed so built-in-font
    // text is recoverable from the raw bytes.
    final doc = pw.Document(compress: false);
    doc.addPage(
      pw.Page(
        build: (context) => widgets.buildHeader(
          shopName: 'City Care Pharmacy',
          ownerName: 'A. Sharma',
          address: '12 MG Road, Pune',
          mobile: '9999999999',
          drugLicenseNumber: drugLicenseNumber,
        ),
      ),
    );

    final Uint8List bytes = await doc.save();
    return latin1.decode(bytes, allowInvalid: true);
  }

  group('Drug License Number invoice header rendering (R14.5)', () {
    const license = 'MH20B123456';

    test(
      'configured value appears in the pharmacy invoice header output',
      () async {
        final output = await renderHeaderText(drugLicenseNumber: license);

        // The configured value is rendered (R14.2)...
        expect(
          output.contains(license),
          isTrue,
          reason: 'Configured Drug License Number should appear in header.',
        );
        // ...alongside its label (rendered as the "D.L." word token; the
        // renderer emits each whitespace-separated word as its own token).
        expect(
          output.contains('D.L.'),
          isTrue,
          reason: 'The Drug License label should be rendered when configured.',
        );
      },
    );

    test(
      'value is absent when none is configured (null) without error',
      () async {
        // R14.3: omit the field and complete the export without raising an error.
        final output = await renderHeaderText(drugLicenseNumber: null);

        expect(
          output.contains('D.L.'),
          isFalse,
          reason: 'No Drug License line should render when unconfigured.',
        );
        expect(output.contains(license), isFalse);
      },
    );

    test(
      'value is absent when configured value is empty without error',
      () async {
        // An empty string is treated as "not configured" by the header builder.
        final output = await renderHeaderText(drugLicenseNumber: '');

        expect(
          output.contains('D.L.'),
          isFalse,
          reason: 'Empty Drug License Number must be omitted from the header.',
        );
        expect(output.contains(license), isFalse);
      },
    );
  });
}
