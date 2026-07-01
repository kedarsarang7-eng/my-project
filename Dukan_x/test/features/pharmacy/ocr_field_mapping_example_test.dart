// ============================================================================
// TASK 20.3 — EXAMPLE TEST for OCR → Purchase-Entry field mapping
// Feature: pharmacy-vertical-remediation, Requirement 24.5
// **Validates: Requirements 24.5**
// ============================================================================
//
// Requirement 24.5:
//   "THE System SHALL include a test verifying that successfully parsed OCR
//    fields populate the matching purchase entry fields and that unparsed or
//    missing fields remain empty and editable."
//
// Task 20.1 wired `MedicineOcrParser` output into the purchase-entry form
// (`_handlePurchaseOcr` in stock_entry_screen.dart). The form-population step
// is a deterministic projection of the parsed result:
//
//   nameCtrl   <- medicine.medicineName ?? parsed['detectedName']
//   rateCtrl   <- medicine.mrp          ?? parsed['detectedPrice']   (unit price)
//   batchCtrl  <- medicine.batchNumber  ?? parsed['batchNo']
//   expiryCtrl <- medicine.expiryDate (MM/yyyy) ?? parsed['expiryDate']
//
// A field is only assigned when its parsed value is non-null; otherwise the
// controller is left untouched (empty string) so the operator can edit it
// manually. This example test drives the REAL `MedicineOcrParser` with concrete
// label text and asserts the resulting purchase-entry field values via a small
// pure projection (`_mapOcrToPurchaseFields`) that mirrors the widget mapping
// above. It is TEST-ONLY: no production code is changed by this task.
//
// NOTE: If task 20.2 extracts a shared pure mapping helper, that helper should
// be imported and used here read-only; until then this local mirror documents
// and verifies the exact mapping contract.
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/features/ml/parsers/medicine_ocr_parser.dart';

/// Purchase-entry field values produced from an OCR scan result.
///
/// Each field is `null` when the corresponding OCR field could not be parsed,
/// which the form renders as an empty, editable input.
class _PurchaseFields {
  final String? name;
  final String? unitPrice;
  final String? batch;
  final String? expiry;

  const _PurchaseFields({this.name, this.unitPrice, this.batch, this.expiry});
}

/// Pure mirror of the `_handlePurchaseOcr` field projection (Task 20.1).
///
/// [parsed] is the generic heuristic map (`OcrRouterResult.parsedResult`); here
/// it defaults to empty so the medicine-parser fields are exercised directly.
_PurchaseFields _mapOcrToPurchaseFields(
  MedicineOcrResult? medicine, {
  Map<String, dynamic> parsed = const <String, dynamic>{},
}) {
  String? str(dynamic v) =>
      v is String && v.trim().isNotEmpty ? v.trim() : null;

  final name = str(medicine?.medicineName) ?? str(parsed['detectedName']);

  final double? mrp =
      medicine?.mrp ??
      (parsed['detectedPrice'] is num
          ? (parsed['detectedPrice'] as num).toDouble()
          : null);
  final unitPrice = (mrp != null && mrp > 0) ? mrp.toString() : null;

  final batch = str(medicine?.batchNumber) ?? str(parsed['batchNo']);

  final expiryDate = medicine?.expiryDate;
  final expiry = expiryDate != null
      ? '${expiryDate.month.toString().padLeft(2, '0')}/${expiryDate.year}'
      : str(parsed['expiryDate']);

  return _PurchaseFields(
    name: name,
    unitPrice: unitPrice,
    batch: batch,
    expiry: expiry,
  );
}

void main() {
  group('OCR field mapping — fully parsed strip populates matching fields', () {
    test('batch, expiry, and unit price all populate from a full label', () {
      // A well-formed medicine strip with batch, expiry, and MRP present.
      const rawText =
          'PARACETAMOL 500mg\nB.No: ABC123\nEXP: 03/26\nMRP: Rs 45.50';

      final result = MedicineOcrParser.parse(rawText);

      // The real parser extracts every pharmacy field.
      expect(result.batchNumber, 'ABC123');
      expect(result.mrp, 45.50);
      expect(result.strength, '500mg');
      expect(result.expiryDate, isNotNull);
      // MM/YY -> last day of the expiry month (Mar 2026).
      expect(result.expiryDate!.year, 2026);
      expect(result.expiryDate!.month, 3);
      expect(result.hasPharmacyData, isTrue);

      // Projection onto purchase-entry fields: each matching field is populated.
      final fields = _mapOcrToPurchaseFields(result);
      expect(fields.batch, 'ABC123');
      expect(fields.unitPrice, '45.5');
      expect(fields.expiry, '03/2026');
    });
  });

  group('OCR field mapping — partial result leaves missing fields empty', () {
    test('only batch parsed: expiry and unit price remain empty/editable', () {
      // Label with a batch number but no expiry or MRP printed/readable.
      const rawText = 'AMOXICILLIN 250mg\nBATCH: XYZ789';

      final result = MedicineOcrParser.parse(rawText);

      expect(result.batchNumber, 'XYZ789');
      expect(result.expiryDate, isNull);
      expect(result.mrp, isNull);

      final fields = _mapOcrToPurchaseFields(result);
      // Parsed field populates.
      expect(fields.batch, 'XYZ789');
      // Unparsed/missing fields stay null -> empty & editable in the form.
      expect(fields.expiry, isNull);
      expect(fields.unitPrice, isNull);
    });

    test('only expiry and price parsed: batch remains empty/editable', () {
      const rawText = 'EXP 12/2027\nMRP 120';

      final result = MedicineOcrParser.parse(rawText);

      expect(result.mrp, 120.0);
      expect(result.expiryDate, isNotNull);
      expect(result.expiryDate!.year, 2027);
      expect(result.expiryDate!.month, 12);
      expect(result.batchNumber, isNull);

      final fields = _mapOcrToPurchaseFields(result);
      expect(fields.unitPrice, '120.0');
      expect(fields.expiry, '12/2027');
      // Missing batch stays empty & editable.
      expect(fields.batch, isNull);
    });
  });

  group('OCR field mapping — unreadable scan keeps every field empty', () {
    test('empty raw text yields an empty result and no populated fields', () {
      final result = MedicineOcrParser.parse('');

      expect(result.hasPharmacyData, isFalse);

      final fields = _mapOcrToPurchaseFields(result);
      expect(fields.name, isNull);
      expect(fields.unitPrice, isNull);
      expect(fields.batch, isNull);
      expect(fields.expiry, isNull);
    });
  });

  group('OCR field mapping — generic fallback fills only unmatched fields', () {
    test('name from generic parse fills the otherwise-empty name field', () {
      // Medicine parser finds batch/expiry/mrp; generic parse supplies a name.
      const rawText = 'B.No DEF456\nEXP 06/28\nMRP 99.00';
      final result = MedicineOcrParser.parse(rawText);

      final fields = _mapOcrToPurchaseFields(
        result,
        parsed: const {'detectedName': 'Azithromycin 500'},
      );

      expect(fields.name, 'Azithromycin 500');
      expect(fields.batch, 'DEF456');
      expect(fields.unitPrice, '99.0');
      expect(fields.expiry, '06/2028');
    });
  });
}
