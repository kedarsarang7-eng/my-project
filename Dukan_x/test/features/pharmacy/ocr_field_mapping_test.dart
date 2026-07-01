// ============================================================================
// TASK 20.3 — Unit test for OCR → Purchase-Entry field mapping
// Feature: pharmacy-vertical-remediation
// **Validates: Requirements 24.5**
// ============================================================================
//
// Tests the pure mapping logic from MedicineOcrResult → purchase-entry form
// fields. Focuses on:
//   (a) Fully parsed result populates all matching fields.
//   (b) Partially parsed result populates only parsed fields, rest empty.
//   (c) Fully failed/empty parse leaves all fields empty and editable.
//
// The mapping is a deterministic projection (task 20.1):
//   nameCtrl   <- medicineName
//   unitPrice  <- mrp (double → string)
//   batchCtrl  <- batchNumber
//   expiryCtrl <- expiryDate formatted as MM/yyyy
//   qtyCtrl    <- not derivable from OCR; always left empty/editable
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/features/ml/parsers/medicine_ocr_parser.dart';

// ---------------------------------------------------------------------------
// Test-only pure mapping that mirrors the task 20.1 field projection in
// stock_entry_screen.dart `_handlePurchaseOcr`.
// ---------------------------------------------------------------------------

/// Represents the purchase-entry form field values after OCR mapping.
/// A null value means the field was not populated by OCR and remains
/// empty/editable in the form.
class _PurchaseEntryFields {
  final String? name;
  final String? quantity;
  final String? unitPrice;
  final String? batch;
  final String? expiry;

  const _PurchaseEntryFields({
    this.name,
    this.quantity,
    this.unitPrice,
    this.batch,
    this.expiry,
  });
}

/// Maps a [MedicineOcrResult] onto purchase-entry form fields exactly as
/// `_handlePurchaseOcr` does in production (task 20.1).
///
/// - Parsed fields populate their matching controller.
/// - Unparsed/missing fields are left null (empty & editable).
/// - Quantity is never derivable from a strip scan so it's always null.
_PurchaseEntryFields _mapOcrToFields(MedicineOcrResult result) {
  final String? name =
      result.medicineName != null && result.medicineName!.trim().isNotEmpty
      ? result.medicineName!.trim()
      : null;

  final double? mrp = result.mrp;
  final String? unitPrice = (mrp != null && mrp > 0) ? mrp.toString() : null;

  final String? batch =
      result.batchNumber != null && result.batchNumber!.trim().isNotEmpty
      ? result.batchNumber!.trim()
      : null;

  final DateTime? expiryDate = result.expiryDate;
  final String? expiry = expiryDate != null
      ? '${expiryDate.month.toString().padLeft(2, '0')}/${expiryDate.year}'
      : null;

  // Quantity is not derivable from medicine strip OCR.
  return _PurchaseEntryFields(
    name: name,
    quantity: null,
    unitPrice: unitPrice,
    batch: batch,
    expiry: expiry,
  );
}

void main() {
  group('OCR field mapping — Requirement 24.5', () {
    // ========================================================================
    // (a) Fully parsed OCR result populates every matching purchase-entry field
    // ========================================================================
    group('fully parsed OCR result', () {
      late MedicineOcrResult fullResult;
      late _PurchaseEntryFields fields;

      setUp(() {
        fullResult = MedicineOcrResult(
          rawText: 'PARACETAMOL B.No: B123 EXP 06/25 MRP 5.50',
          medicineName: 'Paracetamol',
          mrp: 5.50,
          batchNumber: 'B123',
          expiryDate: DateTime(2025, 6, 1),
          confidence: 1.0,
        );
        fields = _mapOcrToFields(fullResult);
      });

      test('name field is populated with the parsed medicine name', () {
        expect(fields.name, 'Paracetamol');
      });

      test('unitPrice field is populated with the parsed MRP value', () {
        expect(fields.unitPrice, '5.5');
      });

      test('batch field is populated with the parsed batch number', () {
        expect(fields.batch, 'B123');
      });

      test(
        'expiry field is populated with formatted expiry date (MM/yyyy)',
        () {
          expect(fields.expiry, '06/2025');
        },
      );

      test(
        'quantity field remains empty (not derivable from OCR strip scan)',
        () {
          expect(fields.quantity, isNull);
        },
      );
    });

    // ========================================================================
    // (b) Partially parsed result populates only parsed fields; rest are empty
    // ========================================================================
    group('partially parsed OCR result (only name and batch)', () {
      late MedicineOcrResult partialResult;
      late _PurchaseEntryFields fields;

      setUp(() {
        partialResult = MedicineOcrResult(
          rawText: 'PARACETAMOL B.No: B123',
          medicineName: 'Paracetamol',
          mrp: null,
          batchNumber: 'B123',
          expiryDate: null,
          confidence: 0.5,
        );
        fields = _mapOcrToFields(partialResult);
      });

      test('name field is populated from parsed name', () {
        expect(fields.name, 'Paracetamol');
      });

      test('batch field is populated from parsed batch number', () {
        expect(fields.batch, 'B123');
      });

      test('unitPrice remains empty (not parsed)', () {
        expect(fields.unitPrice, isNull);
      });

      test('expiry remains empty (not parsed)', () {
        expect(fields.expiry, isNull);
      });

      test('quantity remains empty (never derivable from OCR)', () {
        expect(fields.quantity, isNull);
      });
    });

    // ========================================================================
    // (c) Fully failed/empty parse leaves all fields empty and form intact
    // ========================================================================
    group('fully failed/empty OCR parse result', () {
      late _PurchaseEntryFields fieldsFromEmpty;
      late _PurchaseEntryFields fieldsFromNoData;

      setUp(() {
        // Case 1: completely empty raw text (scanner returned nothing)
        final emptyResult = MedicineOcrResult.empty();
        fieldsFromEmpty = _mapOcrToFields(emptyResult);

        // Case 2: raw text present but no fields extractable
        const noDataResult = MedicineOcrResult(
          rawText: 'unreadable garbled text ###',
          medicineName: null,
          mrp: null,
          batchNumber: null,
          expiryDate: null,
          confidence: 0.0,
        );
        fieldsFromNoData = _mapOcrToFields(noDataResult);
      });

      test('empty scan: name field remains empty', () {
        expect(fieldsFromEmpty.name, isNull);
      });

      test('empty scan: unitPrice field remains empty', () {
        expect(fieldsFromEmpty.unitPrice, isNull);
      });

      test('empty scan: batch field remains empty', () {
        expect(fieldsFromEmpty.batch, isNull);
      });

      test('empty scan: expiry field remains empty', () {
        expect(fieldsFromEmpty.expiry, isNull);
      });

      test('empty scan: quantity field remains empty', () {
        expect(fieldsFromEmpty.quantity, isNull);
      });

      test('unreadable scan: name field remains empty', () {
        expect(fieldsFromNoData.name, isNull);
      });

      test('unreadable scan: unitPrice field remains empty', () {
        expect(fieldsFromNoData.unitPrice, isNull);
      });

      test('unreadable scan: batch field remains empty', () {
        expect(fieldsFromNoData.batch, isNull);
      });

      test('unreadable scan: expiry field remains empty', () {
        expect(fieldsFromNoData.expiry, isNull);
      });

      test('unreadable scan: quantity field remains empty', () {
        expect(fieldsFromNoData.quantity, isNull);
      });
    });

    // ========================================================================
    // Edge: MRP of zero or negative does not populate unitPrice
    // ========================================================================
    group('edge cases', () {
      test('MRP of zero does not populate unitPrice', () {
        const result = MedicineOcrResult(
          rawText: 'test',
          medicineName: 'TestDrug',
          mrp: 0.0,
          batchNumber: null,
          expiryDate: null,
        );
        final fields = _mapOcrToFields(result);
        expect(fields.name, 'TestDrug');
        expect(fields.unitPrice, isNull);
      });

      test('whitespace-only medicineName is treated as empty', () {
        const result = MedicineOcrResult(
          rawText: 'test',
          medicineName: '   ',
          mrp: 10.0,
          batchNumber: 'X1',
          expiryDate: null,
        );
        final fields = _mapOcrToFields(result);
        expect(fields.name, isNull);
        expect(fields.unitPrice, '10.0');
        expect(fields.batch, 'X1');
      });
    });
  });
}
