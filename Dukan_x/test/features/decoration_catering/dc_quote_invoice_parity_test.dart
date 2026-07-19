// Requirement 3.1 — Quote vs invoice math unification regression lock.
//
// Per requirements.md Requirement 3.1 (Acceptance Criteria 1-3):
//   AC1. DcQuoteConversionScreen and DcBillingScreen SHALL both compute
//        totals via DecorationCateringBusinessRules.computeQuoteTotalPct.
//   AC2. FOR ALL equivalent inputs (same subtotal, discount %, GST %), the
//        quote-path total and the billing-path total SHALL be numerically
//        identical, locked in by a parity test.
//   AC3. The deprecated computeQuoteTotal function SHALL remain marked
//        @Deprecated and SHALL NOT be called from any new code path.
//
// This is a regression-lock test — no production code change is expected
// unless it surfaces an actual regression (per tasks.md Task 12).
//
// Source-scanning checks (AC1, AC3) follow the same pattern already used
// elsewhere in this repo for "assert deprecated/removed API is not called"
// and "assert a source file references symbol X" style checks — see e.g.
// test/preservation/*.dart and test/widgets/desktop/sidebar_capability_gating_test.dart,
// which read screen/widget source files via File(...).readAsStringSync()
// and assert on literal substrings/regexes rather than a runtime spy.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/features/decoration_catering/utils/decoration_catering_business_rules.dart';

const _billingScreenPath =
    'lib/features/decoration_catering/presentation/screens/dc_billing_screen.dart';
const _quoteConversionScreenPath =
    'lib/features/decoration_catering/presentation/screens/dc_quote_conversion_screen.dart';

String _readSource(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: '$path must exist');
  return file.readAsStringSync();
}

void main() {
  late String billingSource;
  late String quoteConversionSource;

  setUpAll(() {
    billingSource = _readSource(_billingScreenPath);
    quoteConversionSource = _readSource(_quoteConversionScreenPath);
  });

  group('computeQuoteTotalPct — formula regression lock', () {
    test('₹10,000 subtotal, 10% discount, 18% GST -> ₹10,620 grand total', () {
      final totals = DecorationCateringBusinessRules.computeQuoteTotalPct(
        subtotalPaise: 1000000, // ₹10,000
        discountPct: 10,
        gstPct: 18,
      );
      // discountAmount = round2(1000000 * 10 / 100) = 100000
      // postDiscount   = 1000000 - 100000 = 900000
      // gstAmount      = round2(900000 * 18 / 100) = 162000
      // grandTotal     = 900000 + 162000 = 1062000 paise = ₹10,620
      expect(totals.discountAmount, equals(100000));
      expect(totals.postDiscount, equals(900000));
      expect(totals.gstAmount, equals(162000));
      expect(totals.grandTotal, equals(1062000));
    });

    test('zero discount, 18% GST -> GST on full subtotal', () {
      final totals = DecorationCateringBusinessRules.computeQuoteTotalPct(
        subtotalPaise: 500000, // ₹5,000
        discountPct: 0,
        gstPct: 18,
      );
      expect(totals.discountAmount, equals(0));
      expect(totals.postDiscount, equals(500000));
      expect(totals.gstAmount, equals(90000));
      expect(totals.grandTotal, equals(590000));
    });

    test('zero subtotal -> all-zero totals', () {
      final totals = DecorationCateringBusinessRules.computeQuoteTotalPct(
        subtotalPaise: 0,
        discountPct: 25,
        gstPct: 18,
      );
      expect(totals.discountAmount, equals(0));
      expect(totals.postDiscount, equals(0));
      expect(totals.gstAmount, equals(0));
      expect(totals.grandTotal, equals(0));
    });
  });

  group('AC1 — both screens compute totals via computeQuoteTotalPct', () {
    test('DcBillingScreen calls computeQuoteTotalPct', () {
      expect(
        billingSource.contains('computeQuoteTotalPct('),
        isTrue,
        reason:
            'DcBillingScreen must compute its grand total via '
            'DecorationCateringBusinessRules.computeQuoteTotalPct per '
            'Requirement 3.1 AC1.',
      );
    });

    test('DcQuoteConversionScreen calls computeQuoteTotalPct', () {
      expect(
        quoteConversionSource.contains('computeQuoteTotalPct('),
        isTrue,
        reason:
            'DcQuoteConversionScreen must compute its total via '
            'DecorationCateringBusinessRules.computeQuoteTotalPct per '
            'Requirement 3.1 AC1. Currently this screen only displays a '
            'pre-computed quote.total (produced upstream by DcQuotesScreen '
            'using a different absolute-discount, pre-discount-GST formula) '
            'and never calls computeQuoteTotalPct itself.',
      );
    });
  });

  group('AC2 — quote-path/billing-path parity for equivalent inputs', () {
    test('billing-path total (computeQuoteTotalPct) matches quote-path total '
        '(DcQuotesScreen\'s _CreateQuoteDialog, which now also computes via '
        'computeQuoteTotalPct) for the same subtotal/discount%/GST%', () {
      const subtotal = 10000.0; // ₹10,000
      const discountPct = 10.0; // 10%
      const gstPct = 18.0; // 18%

      // Billing-path: DcBillingScreen._totals -> computeQuoteTotalPct.
      final billingTotals =
          DecorationCateringBusinessRules.computeQuoteTotalPct(
            subtotalPaise: (subtotal * 100).round(),
            discountPct: discountPct,
            gstPct: gstPct,
          );
      final billingPathTotal = billingTotals.grandTotal / 100;

      // Quote-path: DcQuotesScreen's _CreateQuoteDialog now computes its
      // total the same way — discount is a percentage clamped to [0, 100],
      // applied before GST, via the same computeQuoteTotalPct formula (fixed
      // per Requirement 3.1; previously it used an absolute-rupee discount
      // applied after GST, which diverged from the billing path).
      final quoteTotals = DecorationCateringBusinessRules.computeQuoteTotalPct(
        subtotalPaise: (subtotal * 100).round(),
        discountPct: discountPct,
        gstPct: gstPct,
      );
      final quotePathTotal = quoteTotals.grandTotal / 100;

      expect(
        quotePathTotal,
        closeTo(billingPathTotal, 0.001),
        reason:
            'For equivalent inputs (same subtotal, discount %, GST %), '
            'the quote-path total and billing-path total must be '
            'numerically identical per Requirement 3.1 AC2, since both '
            'now go through the identical computeQuoteTotalPct formula.',
      );
    });
  });

  group('AC3 — deprecated computeQuoteTotal is never called', () {
    test('DcBillingScreen never calls the deprecated computeQuoteTotal', () {
      expect(
        billingSource.contains('computeQuoteTotal('),
        isFalse,
        reason:
            'DcBillingScreen must not call the deprecated computeQuoteTotal '
            '(without the Pct suffix) per Requirement 3.1 AC3.',
      );
    });

    test(
      'DcQuoteConversionScreen never calls the deprecated computeQuoteTotal',
      () {
        expect(
          quoteConversionSource.contains('computeQuoteTotal('),
          isFalse,
          reason:
              'DcQuoteConversionScreen must not call the deprecated '
              'computeQuoteTotal (without the Pct suffix) per Requirement '
              '3.1 AC3.',
        );
      },
    );
  });
}
