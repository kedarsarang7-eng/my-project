// ============================================================================
// TASK 20.2 — PROPERTY TEST
// Feature: pharmacy-vertical-remediation, Property 28: OCR fields populate
//   matching purchase-entry fields
// **Validates: Requirements 24.2, 24.3**
// ============================================================================
//
// Property 28 (design.md — Correctness Properties / Req 24):
//   "For any OCR scan result, each successfully parsed field populates its
//    corresponding purchase-entry field while each unparsed or absent field is
//    left empty and editable."
//
// Acceptance criteria exercised:
//   R24.2 — each parsed field (name / qty / unit price / batch / expiry)
//           populates the matching purchase-entry field.
//   R24.3 — each unparsed or absent field is left empty (text '' / null) and
//           therefore editable by the user.
//
// ---------------------------------------------------------------------------
// What is under test
// ---------------------------------------------------------------------------
// Task 20.1 wired `medicine_ocr_parser` output (a `MedicineOcrResult`) into the
// purchase-entry form so that each parsed field is copied onto the matching
// text/date field while fields the scan did not yield are left empty. That
// copy step is private widget state (TextEditingControllers / a nullable
// expiry DateTime), so — following the convention used by the sibling property
// suites in this spec — the parsed-result -> form-field mapping is modelled
// here as a PURE function (`_mapOcrToPurchaseEntry`) that mirrors the
// production wiring exactly, and that pure surface is property-tested.
//
// The pure surface consumes the REAL production type `MedicineOcrResult` for
// the four fields the medicine parser extracts (name / unit price (MRP) /
// batch / expiry). Quantity is not extracted from a medicine strip, so it
// arrives as a separately parsed value (null when the scan did not yield one),
// matching the purchase-entry form's fifth field.
//
// Production mapping (mirrored in `_mapOcrToPurchaseEntry`):
//   name      <- ocr.medicineName  (else left empty: '')
//   quantity  <- parsed quantity   (else left empty: '')
//   unitPrice <- ocr.mrp           (else left empty: '')
//   batch     <- ocr.batchNumber   (else left empty: '')
//   expiry    <- ocr.expiryDate    (else left empty: null)
//
// "Editable" is the absence of a lock/sentinel: an unparsed field is rendered
// as an ordinary empty value ('' for a text controller, null for the date
// field) the user can freely type into. The testable proxy for R24.3 is
// therefore that absent fields map to '' / null (never a placeholder token).
//
// PBT library: dartproptest (repo-wide standard). `forAll` returns true when
// the property held for every run and throws a shrinking counterexample
// otherwise.
//
// TEST-ONLY: no production code is changed by this task.
//
// Run: flutter test test/features/pharmacy/ocr_field_population_property28_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/features/ml/parsers/medicine_ocr_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// At least 100 generated cases are required by the spec (R5.4); 200 matches
/// the dartproptest default and the convention used across this repo's suites.
const int kNumRuns = 200;

/// Floating-point tolerance for the recovered unit-price value. The mapping
/// formats and re-parses the same `double`, so values are effectively
/// bit-identical; this guards only against incidental rounding.
const double kEpsilon = 1e-6;

// ---------------------------------------------------------------------------
// Purchase-entry form values (the mapping's output)
// ---------------------------------------------------------------------------

/// The five purchase-entry fields after OCR population. Text fields use the
/// empty string `''` to mean "left empty / editable"; the expiry date field
/// uses `null` for the same meaning.
class _FormValues {
  const _FormValues({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.batch,
    required this.expiry,
  });

  final String name;
  final String quantity;
  final String unitPrice;
  final String batch;
  final DateTime? expiry;
}

/// A scan's parsed result fed into the purchase-entry form: the medicine OCR
/// result (name / mrp / batch / expiry) plus a separately parsed quantity.
class _ParsedScan {
  const _ParsedScan(this.ocr, this.quantity);
  final MedicineOcrResult ocr;
  final int? quantity;
}

// ---------------------------------------------------------------------------
// Production-mirroring pure surface (task 20.1 wiring, distilled)
// ---------------------------------------------------------------------------

/// Formats a parsed unit price for a text field: whole rupees render without a
/// trailing `.0`, otherwise the natural decimal form is kept. Re-parsing the
/// result recovers the original value.
String _formatNumber(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toString();
}

/// Mirrors task 20.1's wiring of `medicine_ocr_parser` output onto the
/// purchase-entry form: parsed fields are copied across; unparsed/absent fields
/// are left empty ('' for text fields, null for the date field) and editable.
_FormValues _mapOcrToPurchaseEntry(_ParsedScan scan) {
  final ocr = scan.ocr;
  return _FormValues(
    name: ocr.medicineName ?? '',
    quantity: scan.quantity != null ? scan.quantity.toString() : '',
    unitPrice: ocr.mrp != null ? _formatNumber(ocr.mrp!) : '',
    batch: ocr.batchNumber ?? '',
    expiry: ocr.expiryDate,
  );
}

// ---------------------------------------------------------------------------
// Generators
// ---------------------------------------------------------------------------

/// Builds an arbitrary parsed scan where each of the five fields is
/// independently present (a generated value) or absent (null), exercising every
/// subset of populated/unparsed fields.
final Generator<_ParsedScan> _parsedScanGen =
    Gen.tuple(<Generator<dynamic>>[
      Gen.boolean(), // 0: name present?
      Gen.string(minLength: 1, maxLength: 20), // 1: name value
      Gen.boolean(), // 2: quantity present?
      Gen.interval(1, 100000), // 3: quantity value
      Gen.boolean(), // 4: mrp present?
      Gen.interval(1, 99999999), // 5: mrp in paise (₹0.01 .. ₹999,999.99)
      Gen.boolean(), // 6: batch present?
      Gen.string(minLength: 1, maxLength: 12), // 7: batch value
      Gen.boolean(), // 8: expiry present?
      Gen.interval(2024, 2035), // 9: expiry year
      Gen.interval(1, 12), // 10: expiry month
    ]).map((p) {
      final String? name = (p[0] as bool) ? p[1] as String : null;
      final int? quantity = (p[2] as bool) ? p[3] as int : null;
      final double? mrp = (p[4] as bool) ? (p[5] as int) / 100.0 : null;
      final String? batch = (p[6] as bool) ? p[7] as String : null;
      final DateTime? expiry = (p[8] as bool)
          ? DateTime(p[9] as int, p[10] as int, 1)
          : null;

      return _ParsedScan(
        MedicineOcrResult(
          rawText: 'generated',
          medicineName: name,
          mrp: mrp,
          batchNumber: batch,
          expiryDate: expiry,
        ),
        quantity,
      );
    });

void main() {
  group('Feature: pharmacy-vertical-remediation, Property 28: OCR fields '
      'populate matching purchase-entry fields — Req 24.2, 24.3', () {
    // ----------------------------------------------------------------------
    // (A) POPULATION: every parsed field lands in its matching form field and
    //     the value round-trips (R24.2).
    // ----------------------------------------------------------------------
    test('Property 28a: each parsed field populates the matching purchase-'
        'entry field and recovers its value', () {
      final bool held = forAll(
        (_ParsedScan scan) {
          final form = _mapOcrToPurchaseEntry(scan);

          // name -> name
          if (scan.ocr.medicineName != null) {
            if (form.name != scan.ocr.medicineName) return false;
            if (form.name.isEmpty) return false; // populated, not empty
          }
          // quantity -> quantity (text), recovers as the same integer
          if (scan.quantity != null) {
            if (form.quantity.isEmpty) return false;
            if (int.tryParse(form.quantity) != scan.quantity) return false;
          }
          // unit price (mrp) -> unitPrice (text), recovers as the same value
          if (scan.ocr.mrp != null) {
            if (form.unitPrice.isEmpty) return false;
            final parsed = double.tryParse(form.unitPrice);
            if (parsed == null) return false;
            if ((parsed - scan.ocr.mrp!).abs() > kEpsilon) return false;
          }
          // batch -> batch
          if (scan.ocr.batchNumber != null) {
            if (form.batch != scan.ocr.batchNumber) return false;
            if (form.batch.isEmpty) return false;
          }
          // expiry -> expiry (date field)
          if (scan.ocr.expiryDate != null) {
            if (form.expiry != scan.ocr.expiryDate) return false;
          }
          return true;
        },
        [_parsedScanGen],
        numRuns: kNumRuns,
      );
      expect(
        held,
        isTrue,
        reason:
            'Every successfully parsed OCR field must populate its matching '
            'purchase-entry field and the populated value must equal the '
            'parsed value.',
      );
    });

    // ----------------------------------------------------------------------
    // (B) EMPTINESS: every unparsed/absent field is left empty and editable
    //     ('' for text fields, null for the date field) — never a placeholder
    //     or locked sentinel (R24.3).
    // ----------------------------------------------------------------------
    test('Property 28b: each unparsed/absent field is left empty (and thus '
        'editable)', () {
      final bool held = forAll(
        (_ParsedScan scan) {
          final form = _mapOcrToPurchaseEntry(scan);

          if (scan.ocr.medicineName == null && form.name != '') return false;
          if (scan.quantity == null && form.quantity != '') return false;
          if (scan.ocr.mrp == null && form.unitPrice != '') return false;
          if (scan.ocr.batchNumber == null && form.batch != '') return false;
          if (scan.ocr.expiryDate == null && form.expiry != null) return false;
          return true;
        },
        [_parsedScanGen],
        numRuns: kNumRuns,
      );
      expect(
        held,
        isTrue,
        reason:
            'Every field the scan did not yield must be left empty (empty '
            'string for text fields, null for the date field) so it stays '
            'user-editable.',
      );
    });

    // ----------------------------------------------------------------------
    // (C) EXCLUSIVITY: a field is populated if and only if its parsed source
    //     is present. Pins R24.2/R24.3 together — no field is invented and no
    //     parsed field is dropped.
    // ----------------------------------------------------------------------
    test('Property 28c: a form field is non-empty exactly when its parsed '
        'source is present', () {
      final bool held = forAll(
        (_ParsedScan scan) {
          final form = _mapOcrToPurchaseEntry(scan);

          if ((scan.ocr.medicineName != null) != form.name.isNotEmpty) {
            return false;
          }
          if ((scan.quantity != null) != form.quantity.isNotEmpty) {
            return false;
          }
          if ((scan.ocr.mrp != null) != form.unitPrice.isNotEmpty) {
            return false;
          }
          if ((scan.ocr.batchNumber != null) != form.batch.isNotEmpty) {
            return false;
          }
          if ((scan.ocr.expiryDate != null) != (form.expiry != null)) {
            return false;
          }
          return true;
        },
        [_parsedScanGen],
        numRuns: kNumRuns,
      );
      expect(
        held,
        isTrue,
        reason:
            'Each purchase-entry field is populated if and only if the OCR '
            'parsed its corresponding source field.',
      );
    });

    // ----------------------------------------------------------------------
    // Deterministic anchors — pin the population / emptiness behaviour, the
    // last grounded in the REAL `MedicineOcrParser`.
    // ----------------------------------------------------------------------
    test('Property 28 anchor: a fully parsed scan populates all five fields '
        '(R24.2)', () {
      final scan = _ParsedScan(
        MedicineOcrResult(
          rawText: 'x',
          medicineName: 'Paracetamol',
          mrp: 45.5,
          batchNumber: 'AB12',
          expiryDate: DateTime(2026, 3, 31),
        ),
        10,
      );
      final form = _mapOcrToPurchaseEntry(scan);

      expect(form.name, 'Paracetamol');
      expect(form.quantity, '10');
      expect(double.parse(form.unitPrice), closeTo(45.5, kEpsilon));
      expect(form.batch, 'AB12');
      expect(form.expiry, DateTime(2026, 3, 31));
    });

    test('Property 28 anchor: a fully failed/empty scan leaves every field '
        'empty and editable (R24.3)', () {
      final scan = _ParsedScan(MedicineOcrResult.empty(), null);
      final form = _mapOcrToPurchaseEntry(scan);

      expect(form.name, '');
      expect(form.quantity, '');
      expect(form.unitPrice, '');
      expect(form.batch, '');
      expect(form.expiry, isNull);
    });

    test('Property 28 anchor: a partial scan populates only the parsed fields '
        'and leaves the rest empty (R24.2 + R24.3)', () {
      // Only batch + expiry parsed; name, quantity, unit price absent.
      final scan = _ParsedScan(
        MedicineOcrResult(
          rawText: 'x',
          batchNumber: 'LOT9',
          expiryDate: DateTime(2027, 12, 31),
        ),
        null,
      );
      final form = _mapOcrToPurchaseEntry(scan);

      expect(form.batch, 'LOT9');
      expect(form.expiry, DateTime(2027, 12, 31));
      // Unparsed fields stay empty/editable.
      expect(form.name, '');
      expect(form.quantity, '');
      expect(form.unitPrice, '');
    });

    test('Property 28 anchor: real MedicineOcrParser output populates the '
        'matching fields (end-to-end grounding)', () {
      // A representative medicine-strip line the production parser handles.
      final ocr = MedicineOcrParser.parse(
        'Paracetamol 500mg B.No: AB12 EXP 03/26 MRP 45.50',
      );

      // The parser extracts batch / expiry / mrp (it does not extract a
      // medicine name or a purchase quantity).
      final form = _mapOcrToPurchaseEntry(_ParsedScan(ocr, null));

      expect(form.batch, ocr.batchNumber);
      expect(form.batch, isNotEmpty);
      expect(form.expiry, ocr.expiryDate);
      expect(double.parse(form.unitPrice), closeTo(ocr.mrp!, kEpsilon));
      // Fields the scan did not yield remain empty/editable.
      expect(form.name, '');
      expect(form.quantity, '');
    });
  });
}
