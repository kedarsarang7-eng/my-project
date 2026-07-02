// ============================================================================
// TEST: Phase 1 Dashboard Truth, Config Leak, and Dead-Button Fix
// ============================================================================
// Example tests verifying the Phase 1 critical fixes for the wholesale vertical:
//   1. Wholesale alerts use real `alertCountsProvider` (never '15'/'7' literals)
//   2. Wholesale `optionalFields` does NOT contain `ItemField.drugSchedule`
//   3. "Bulk Scan" quick action invokes `WholesaleBulkScannerWidget` (not empty onTap)
//
// Feature: wholesale-vertical-remediation
// Validates: Requirements 4.1, 4.2, 4.3, 4.4, 4.5, 4.6
// ============================================================================

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dukanx/core/billing/business_type_config.dart';

void main() {
  // =========================================================================
  // 1. Wholesale alert branch reads counts from alertCountsProvider
  //    (never hardcoded '15'/'7')
  // =========================================================================
  group(
    'Feature: wholesale-vertical-remediation — Dashboard truth (Req 4.1, 4.2, 4.3, 4.4)',
    () {
      test(
        'business_alerts_widget wholesale branch does NOT contain hardcoded "15" or "7" alert count literals',
        () {
          // Source-level assertion: the wholesale branch in business_alerts_widget.dart
          // must not contain `count: '15'` or `count: '7'` string literals.
          final alertsFile = File(
            'lib/features/dashboard/v2/widgets/business_alerts_widget.dart',
          );
          expect(
            alertsFile.existsSync(),
            isTrue,
            reason: 'business_alerts_widget.dart must exist',
          );

          final source = alertsFile.readAsStringSync();

          // Locate the wholesale case block (from `case BusinessType.wholesale:` to the
          // next `case BusinessType.` or `default:`)
          final wholesaleStart = source.indexOf('case BusinessType.wholesale:');
          expect(
            wholesaleStart,
            isNot(-1),
            reason: 'Wholesale case must exist in _buildAlertsForBusiness',
          );

          // Find the end of the wholesale case (next `case BusinessType.` or `break;`)
          final afterWholesale = source.substring(wholesaleStart);
          final nextCase = afterWholesale.indexOf(
            RegExp(r'case BusinessType\.\w+:'),
            'case BusinessType.wholesale:'.length,
          );
          final wholesaleBlock = nextCase > 0
              ? afterWholesale.substring(0, nextCase)
              : afterWholesale;

          // Assert no hardcoded '15' or '7' count literals
          expect(
            wholesaleBlock.contains("count: '15'"),
            isFalse,
            reason:
                'Wholesale alerts must NOT contain hardcoded count "15" — '
                'must use real alertCountsProvider (§5, §8)',
          );
          expect(
            wholesaleBlock.contains("count: '7'"),
            isFalse,
            reason:
                'Wholesale alerts must NOT contain hardcoded count "7" — '
                'must use real wholesaleCreditAlertCountsProvider (§5, §8)',
          );
        },
      );

      test(
        'wholesale alert branch references alertCountsProvider counts (lowStock key)',
        () {
          final alertsFile = File(
            'lib/features/dashboard/v2/widgets/business_alerts_widget.dart',
          );
          final source = alertsFile.readAsStringSync();

          // Find the SECOND occurrence of 'case BusinessType.wholesale:' which is
          // the alerts builder (the first one is the title resolver).
          final firstOccurrence = source.indexOf(
            'case BusinessType.wholesale:',
          );
          final wholesaleStart = source.indexOf(
            'case BusinessType.wholesale:',
            firstOccurrence + 1,
          );
          expect(
            wholesaleStart,
            isNot(-1),
            reason: 'Wholesale alert-builder case must exist',
          );

          final afterWholesale = source.substring(wholesaleStart);
          final nextCase = afterWholesale.indexOf(
            RegExp(r'case BusinessType\.\w+:'),
            'case BusinessType.wholesale:'.length,
          );
          final wholesaleBlock = nextCase > 0
              ? afterWholesale.substring(0, nextCase)
              : afterWholesale;

          // The wholesale branch must reference 'lowStock' key from the counts map
          // confirming it reads from the real alertCountsProvider query.
          expect(
            wholesaleBlock.contains("'lowStock'"),
            isTrue,
            reason:
                'Wholesale branch must consume lowStock from the counts map '
                '(alertCountsProvider), not a fabricated literal',
          );
        },
      );

      test(
        'wholesale alert branch handles unavailable/zero states without fabrication',
        () {
          final alertsFile = File(
            'lib/features/dashboard/v2/widgets/business_alerts_widget.dart',
          );
          final source = alertsFile.readAsStringSync();

          // Find the SECOND occurrence (alerts builder, not title resolver)
          final firstOccurrence = source.indexOf(
            'case BusinessType.wholesale:',
          );
          final wholesaleStart = source.indexOf(
            'case BusinessType.wholesale:',
            firstOccurrence + 1,
          );
          final afterWholesale = source.substring(wholesaleStart);
          final nextCase = afterWholesale.indexOf(
            RegExp(r'case BusinessType\.\w+:'),
            'case BusinessType.wholesale:'.length,
          );
          final wholesaleBlock = nextCase > 0
              ? afterWholesale.substring(0, nextCase)
              : afterWholesale;

          // Must show "Data unavailable" or similar indication on missing data
          expect(
            wholesaleBlock.contains('unavailable') ||
                wholesaleBlock.contains('Unavailable'),
            isTrue,
            reason:
                'Wholesale branch must show unavailable indicator when data is missing',
          );
        },
      );
    },
  );

  // =========================================================================
  // 2. Wholesale optionalFields does NOT contain ItemField.drugSchedule
  // =========================================================================
  group(
    'Feature: wholesale-vertical-remediation — Config leak fix (Req 4.5)',
    () {
      test(
        'wholesale optionalFields does NOT contain ItemField.drugSchedule',
        () {
          final config = BusinessTypeRegistry.getConfig(BusinessType.wholesale);

          expect(
            config.optionalFields.contains(ItemField.drugSchedule),
            isFalse,
            reason:
                'Wholesale optionalFields must NOT contain drugSchedule — '
                'it is a pharmacy-only field (§13, §18). Phase 1 removed it.',
          );
        },
      );

      test(
        'wholesale optionalFields retains expected fields (unit, discount, gst, hsnCode, batchNo, expiryDate)',
        () {
          final config = BusinessTypeRegistry.getConfig(BusinessType.wholesale);

          // These fields should remain after drugSchedule removal
          expect(config.optionalFields, contains(ItemField.unit));
          expect(config.optionalFields, contains(ItemField.discount));
          expect(config.optionalFields, contains(ItemField.gst));
          expect(config.optionalFields, contains(ItemField.hsnCode));
          expect(config.optionalFields, contains(ItemField.batchNo));
          expect(config.optionalFields, contains(ItemField.expiryDate));
        },
      );

      test('wholesale defaultGstRate and gstEditable are unchanged', () {
        final config = BusinessTypeRegistry.getConfig(BusinessType.wholesale);

        // Phase 1 must NOT alter these values
        expect(config.defaultGstRate, 18.0);
        expect(config.gstEditable, isTrue);
      });
    },
  );

  // =========================================================================
  // 3. "Bulk Scan" quick action invokes WholesaleBulkScannerWidget (not empty onTap)
  // =========================================================================
  group('Feature: wholesale-vertical-remediation — Dead button fix (Req 4.6)', () {
    test(
      'business_quick_actions wholesale branch does NOT have empty onTap for Bulk Scan',
      () {
        final quickActionsFile = File(
          'lib/features/dashboard/v2/widgets/business_quick_actions.dart',
        );
        expect(
          quickActionsFile.existsSync(),
          isTrue,
          reason: 'business_quick_actions.dart must exist',
        );

        final source = quickActionsFile.readAsStringSync();

        // Locate the wholesale case
        final wholesaleStart = source.indexOf('case BusinessType.wholesale:');
        expect(
          wholesaleStart,
          isNot(-1),
          reason: 'Wholesale case must exist in business_quick_actions',
        );

        final afterWholesale = source.substring(wholesaleStart);

        // Find the Bulk Scan section
        final bulkScanIdx = afterWholesale.indexOf('Bulk Scan');
        expect(
          bulkScanIdx,
          isNot(-1),
          reason: '"Bulk Scan" quick action must exist in wholesale branch',
        );

        // The area around "Bulk Scan" must NOT have `onTap: () {}`
        final bulkScanContext = afterWholesale.substring(
          (bulkScanIdx - 200).clamp(0, bulkScanIdx),
          (bulkScanIdx + 400).clamp(0, afterWholesale.length),
        );
        expect(
          bulkScanContext.contains('onTap: () {}'),
          isFalse,
          reason:
              '"Bulk Scan" must NOT have an empty onTap — it was a dead '
              'no-op before Phase 1 wired it to the BarcodeScanner flow (§3, §15, §17)',
        );
      },
    );

    test('"Bulk Scan" quick action references WholesaleBulkScannerWidget', () {
      final quickActionsFile = File(
        'lib/features/dashboard/v2/widgets/business_quick_actions.dart',
      );
      final source = quickActionsFile.readAsStringSync();

      // The file must import or reference WholesaleBulkScannerWidget
      expect(
        source.contains('WholesaleBulkScannerWidget'),
        isTrue,
        reason:
            '"Bulk Scan" must invoke WholesaleBulkScannerWidget (the real '
            'barcode scanner flow), not an empty callback',
      );
    });

    test(
      '"Bulk Scan" quick action is wired to a dialog/showDialog invocation',
      () {
        final quickActionsFile = File(
          'lib/features/dashboard/v2/widgets/business_quick_actions.dart',
        );
        final source = quickActionsFile.readAsStringSync();

        final wholesaleStart = source.indexOf('case BusinessType.wholesale:');
        final afterWholesale = source.substring(wholesaleStart);

        // Find the section around Bulk Scan and verify it uses showDialog
        final bulkScanIdx = afterWholesale.indexOf('Bulk Scan');
        final surroundingArea = afterWholesale.substring(
          (bulkScanIdx - 300).clamp(0, bulkScanIdx),
          (bulkScanIdx + 500).clamp(0, afterWholesale.length),
        );

        expect(
          surroundingArea.contains('showDialog') ||
              surroundingArea.contains('WholesaleBulkScannerWidget'),
          isTrue,
          reason:
              '"Bulk Scan" should invoke WholesaleBulkScannerWidget via showDialog',
        );
      },
    );
  });
}
