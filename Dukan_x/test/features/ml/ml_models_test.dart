import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/features/ml/ml_models/scanned_item.dart';
import 'package:dukanx/features/ml/ml_models/ocr_result.dart';

void main() {
  group('ScannedItem', () {
    test('should create ScannedItem with correct values', () {
      const item = ScannedItem(
        name: 'Test Item',
        quantity: 2.0,
        price: 50.0,
        amount: 100.0,
        unit: 'kg',
        confidence: 0.85,
      );

      expect(item.name, 'Test Item');
      expect(item.quantity, 2.0);
      expect(item.price, 50.0);
      expect(item.amount, 100.0);
      expect(item.unit, 'kg');
      expect(item.confidence, 0.85);
    });

    test('should identify item needing review when confidence < 0.7', () {
      const lowConfidenceItem = ScannedItem(
        name: 'Unclear Item',
        confidence: 0.5,
      );
      const highConfidenceItem = ScannedItem(
        name: 'Clear Item',
        confidence: 0.9,
      );

      expect(lowConfidenceItem.needsReview, true);
      expect(highConfidenceItem.needsReview, false);
    });

    test('should return correct confidence level string', () {
      const highConfidence = ScannedItem(name: 'A', confidence: 0.95);
      const mediumConfidence = ScannedItem(name: 'B', confidence: 0.75);
      const lowConfidence = ScannedItem(name: 'C', confidence: 0.5);

      expect(highConfidence.confidenceLevel, 'High');
      expect(mediumConfidence.confidenceLevel, 'Medium');
      expect(lowConfidence.confidenceLevel, 'Low');
    });

    test('should serialize to JSON correctly', () {
      const item = ScannedItem(
        name: 'Rice',
        quantity: 5.0,
        price: 60.0,
        amount: 300.0,
        confidence: 0.88,
      );

      final json = item.toJson();

      expect(json['name'], 'Rice');
      expect(json['qty'], 5.0);
      expect(json['price'], 60.0);
      expect(json['amount'], 300.0);
      expect(json['confidence'], 0.88);
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'name': 'Sugar',
        'qty': 2,
        'price': 45,
        'amount': 90,
        'confidence': 0.9,
      };

      final item = ScannedItem.fromJson(json);

      expect(item.name, 'Sugar');
      expect(item.quantity, 2.0);
      expect(item.price, 45.0);
      expect(item.amount, 90.0);
      expect(item.confidence, 0.9);
    });

    test('should handle copyWith correctly', () {
      const original = ScannedItem(
        name: 'Original',
        quantity: 1.0,
        price: 100.0,
        confidence: 0.7,
      );

      final modified = original.copyWith(name: 'Modified', quantity: 3.0);

      expect(modified.name, 'Modified');
      expect(modified.quantity, 3.0);
      expect(modified.price, 100.0); // Unchanged
      expect(modified.confidence, 0.7); // Unchanged
    });
  });

  group('OcrResult', () {
    test('should create empty OcrResult', () {
      final empty = OcrResult.empty();

      expect(empty.rawText, '');
      expect(empty.items, isEmpty);
      expect(empty.needsReview, true);
    });

    test('should calculate requiresUserReview correctly', () {
      const resultWithLowConfidence = OcrResult(
        rawText: 'Test',
        items: [
          ScannedItem(name: 'Item 1', confidence: 0.9),
          ScannedItem(name: 'Item 2', confidence: 0.5), // Low confidence
        ],
      );

      const resultWithHighConfidence = OcrResult(
        rawText: 'Test',
        items: [
          ScannedItem(name: 'Item 1', confidence: 0.9),
          ScannedItem(name: 'Item 2', confidence: 0.8),
        ],
      );

      expect(resultWithLowConfidence.requiresUserReview, true);
      expect(resultWithHighConfidence.requiresUserReview, false);
    });

    test('should return low confidence items', () {
      const result = OcrResult(
        rawText: 'Test Bill',
        items: [
          ScannedItem(name: 'Clear Item', confidence: 0.9),
          ScannedItem(name: 'Unclear Item 1', confidence: 0.5),
          ScannedItem(name: 'Unclear Item 2', confidence: 0.6),
        ],
      );

      final lowConfidenceItems = result.lowConfidenceItems;

      expect(lowConfidenceItems.length, 2);
      expect(lowConfidenceItems[0].name, 'Unclear Item 1');
      expect(lowConfidenceItems[1].name, 'Unclear Item 2');
    });

    test('should handle copyWith correctly', () {
      const original = OcrResult(
        rawText: 'Original',
        items: [],
        detectedLanguage: 'en',
        totalAmount: 100.0,
      );

      final modified = original.copyWith(
        detectedLanguage: 'hi',
        totalAmount: 200.0,
      );

      expect(modified.rawText, 'Original'); // Unchanged
      expect(modified.detectedLanguage, 'hi');
      expect(modified.totalAmount, 200.0);
    });

    test('should include all fields in props for equality', () {
      const result1 = OcrResult(
        rawText: 'Test',
        items: [],
        totalAmount: 100.0,
        detectedLanguage: 'en',
      );

      const result2 = OcrResult(
        rawText: 'Test',
        items: [],
        totalAmount: 100.0,
        detectedLanguage: 'en',
      );

      const result3 = OcrResult(
        rawText: 'Different',
        items: [],
        totalAmount: 100.0,
        detectedLanguage: 'en',
      );

      expect(result1, equals(result2));
      expect(result1, isNot(equals(result3)));
    });
  });
}
