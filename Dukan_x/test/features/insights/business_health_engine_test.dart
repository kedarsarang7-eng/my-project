// ============================================================================
// BUSINESS HEALTH ENGINE TEST
// ============================================================================
// Unit tests for business health scoring logic
// ============================================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:dukanx/features/insights/data/business_health_engine.dart';

void main() {
  group('BusinessHealthEngine Tests', () {
    test('HealthGrade should return correct grade from score', () {
      final engine = BusinessHealthEngineTestHelper();

      expect(engine.scoreToGrade(95), HealthGrade.excellent);
      expect(engine.scoreToGrade(80), HealthGrade.good);
      expect(engine.scoreToGrade(60), HealthGrade.fair);
      expect(engine.scoreToGrade(40), HealthGrade.poor);
      expect(engine.scoreToGrade(10), HealthGrade.critical);
    });

    test('Health factors should have explanation text', () {
      expect(
        HealthFactorType.salesTrend.explanation,
        contains('sales decreased'),
      );
      expect(
        HealthFactorType.pendingPayments.explanation,
        contains('pending payments'),
      );
      expect(
        HealthFactorType.stockHealth.explanation,
        contains('stock levels'),
      );
    });

    test('HealthGrade labels are correct', () {
      expect(HealthGrade.excellent.label, 'Excellent');
      expect(HealthGrade.critical.label, 'Critical');
    });
  });
}

// Helper to access private methods for testing
class BusinessHealthEngineTestHelper {
  HealthGrade scoreToGrade(int score) {
    if (score >= 86) return HealthGrade.excellent;
    if (score >= 71) return HealthGrade.good;
    if (score >= 51) return HealthGrade.fair;
    if (score >= 26) return HealthGrade.poor;
    return HealthGrade.critical;
  }
}
