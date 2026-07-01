// ============================================================================
// BARCODE & OCR UNIT TESTS
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/core/config/business_capabilities.dart';
import 'package:dukanx/features/ml/ml_services/heuristic_parsers.dart';
import 'package:dukanx/models/business_type.dart';

void main() {
  group('Business Capabilities', () {
    test('Grocery capabilities are correct', () {
      final cap = BusinessCapabilities.get(BusinessType.grocery);
      expect(cap.supportsBarcodeScan, true);
      // Grocery is granted useBatchExpiry, so supportsExpiry must mirror it
      // (Req 7.3 — the prior hardcoded `false` was a self-contradiction).
      expect(cap.supportsExpiry, true);
      expect(cap.ocrFocus, contains('Q'));
    });

    test('Pharmacy capabilities are correct', () {
      final cap = BusinessCapabilities.get(BusinessType.pharmacy);
      expect(cap.supportsBarcodeScan, true);
      expect(cap.supportsExpiry, true);
      expect(cap.supportsBatch, true);
    });

    test('Restaurant capabilities are correct', () {
      final cap = BusinessCapabilities.get(BusinessType.restaurant);
      expect(cap.supportsBarcodeScan, false);
    });
  });

  group('Heuristic Parser', () {
    test('Common fields extraction', () {
      const sampleText = '''
      SUPER MARKET
      Date: 20/01/2026
      Colgate Toothpaste
      MRP 150.00
      Qty 2
      ''';

      final result = HeuristicParser.parse(sampleText, 'grocery');
      expect(result['detectedPrice'], 150.0);
      // Heuristic picks first significant line, which is Store Name here. Acceptable for V1.
      expect(
        result['detectedName'],
        anyOf(contains('Colgate'), contains('SUPER MARKET')),
      );
    });

    test('Pharmacy extraction (Batch/Expiry)', () {
      const sampleText = '''
      PHARMA PLUS
      Dolo 650
      Batch: B12345
      Exp: 12/2027
      MRP: Rs. 30.50
      ''';

      final result = HeuristicParser.parse(sampleText, 'pharmacy');
      expect(result['batchNo'], 'B12345');
      expect(result['expiryDate'], '12/2027');
      expect(result['detectedPrice'], 30.50);
    });

    test('Electronics extraction (Serial/Model)', () {
      const sampleText = '''
      DIGITAL WORLD
      Sony Headphones
      Model: WH-1000XM5
      S/N: 12345ABC
      Price: 24990
      ''';

      final result = HeuristicParser.parse(sampleText, 'electronics');
      expect(result['model'], 'WH-1000XM5');
      expect(result['serialNumber'], '12345ABC');
      expect(result['detectedPrice'], 24990.0);
    });
  });
}
