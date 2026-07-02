import 'package:dukanx/features/invoice/universal/gst/invoice_gst_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

/// A GST case with hand-calculated expected values.
class GstCase {
  final String name;
  final List<InvoiceLineInput> lines;
  final bool interState;
  final double eTaxable, eCgst, eSgst, eIgst, eCess;
  const GstCase(
    this.name,
    this.lines,
    this.interState,
    this.eTaxable,
    this.eCgst,
    this.eSgst,
    this.eIgst,
    this.eCess,
  );

  double get eTotalTax => eCgst + eSgst + eIgst + eCess;
  double get eGrand => eTaxable + eTotalTax;
}

void main() {
  // ── 5 hand-calculated GST/CGST/SGST/IGST/CESS cases ──
  final cases = <GstCase>[
    // 1) Intra-state 18% -> CGST 9% + SGST 9%, no cess.
    //    taxable 1000 -> CGST 90, SGST 90, IGST 0, CESS 0
    const GstCase(
      'Intra 18% (1x1000)',
      [InvoiceLineInput(quantity: 1, unitPrice: 1000, gstRate: 18)],
      false,
      1000,
      90,
      90,
      0,
      0,
    ),
    // 2) Inter-state 12% -> IGST 12%, no cess.
    //    taxable 1000 -> IGST 120
    const GstCase(
      'Inter 12% (2x500)',
      [InvoiceLineInput(quantity: 2, unitPrice: 500, gstRate: 12)],
      true,
      1000,
      0,
      0,
      120,
      0,
    ),
    // 3) Intra-state 28% + CESS 12% (e.g. SUV).
    //    taxable 100000 -> CGST 14000, SGST 14000, CESS 12000
    const GstCase(
      'Intra 28%+Cess 12% (1x100000)',
      [
        InvoiceLineInput(
          quantity: 1,
          unitPrice: 100000,
          gstRate: 28,
          cessRate: 12,
        ),
      ],
      false,
      100000,
      14000,
      14000,
      0,
      12000,
    ),
    // 4) Intra-state 5% with a discount.
    //    4x250 = 1000, -100 discount -> taxable 900 -> CGST 22.5, SGST 22.5
    const GstCase(
      'Intra 5% w/discount (4x250 -100)',
      [
        InvoiceLineInput(
          quantity: 4,
          unitPrice: 250,
          discount: 100,
          gstRate: 5,
        ),
      ],
      false,
      900,
      22.5,
      22.5,
      0,
      0,
    ),
    // 5) Inter-state multi-line with cess (tobacco + standard).
    //    A: 10x100=1000 @28% cess5% -> IGST 280, CESS 50
    //    B: 5x200=1000 @18%         -> IGST 180
    //    totals: taxable 2000, IGST 460, CESS 50
    const GstCase(
      'Inter multi-line 28%+cess & 18%',
      [
        InvoiceLineInput(
          quantity: 10,
          unitPrice: 100,
          gstRate: 28,
          cessRate: 5,
        ),
        InvoiceLineInput(quantity: 5, unitPrice: 200, gstRate: 18),
      ],
      true,
      2000,
      0,
      0,
      460,
      50,
    ),
  ];

  test('GST/CGST/SGST/IGST/CESS — engine matches hand-calculated values', () {
    final b = StringBuffer();
    b.writeln('=== GST VERIFICATION (expected vs actual) ===');
    b.writeln('Case                              | Field | Expected | Actual');
    for (final c in cases) {
      final s = InvoiceGstCalculator.forInvoice(
        c.lines,
        isInterState: c.interState,
      );
      void row(String f, double e, double a) => b.writeln(
        '${c.name.padRight(33)} | ${f.padRight(5)} | ${e.toStringAsFixed(2).padLeft(8)} | ${a.toStringAsFixed(2).padLeft(8)}',
      );
      row('TAXBL', c.eTaxable, s.taxable);
      row('CGST', c.eCgst, s.cgst);
      row('SGST', c.eSgst, s.sgst);
      row('IGST', c.eIgst, s.igst);
      row('CESS', c.eCess, s.cess);
      row('TOTAL', c.eGrand, s.grandTotal);

      expect(s.taxable, closeTo(c.eTaxable, 1e-6), reason: '${c.name} taxable');
      expect(s.cgst, closeTo(c.eCgst, 1e-6), reason: '${c.name} CGST');
      expect(s.sgst, closeTo(c.eSgst, 1e-6), reason: '${c.name} SGST');
      expect(s.igst, closeTo(c.eIgst, 1e-6), reason: '${c.name} IGST');
      expect(s.cess, closeTo(c.eCess, 1e-6), reason: '${c.name} CESS');
      expect(
        s.totalTax,
        closeTo(c.eTotalTax, 1e-6),
        reason: '${c.name} totalTax',
      );
      expect(s.grandTotal, closeTo(c.eGrand, 1e-6), reason: '${c.name} grand');
    }
    // ignore: avoid_print
    print(b.toString());
  });

  test('intra-state never emits IGST; inter-state never emits CGST/SGST', () {
    final intra = InvoiceGstCalculator.forLine(
      quantity: 1,
      unitPrice: 100,
      gstRate: 18,
      isInterState: false,
    );
    expect(intra.igst, 0);
    expect(intra.cgst + intra.sgst, closeTo(18, 1e-9));

    final inter = InvoiceGstCalculator.forLine(
      quantity: 1,
      unitPrice: 100,
      gstRate: 18,
      isInterState: true,
    );
    expect(inter.cgst, 0);
    expect(inter.sgst, 0);
    expect(inter.igst, closeTo(18, 1e-9));
  });
}
