import 'package:dukanx/features/credit_network/logic/credit_score_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CreditScoreCalculator Tests', () {
    test('Initial score should be 100', () {
      final score = CreditScoreCalculator.calculate(
        totalDefaults: 0,
        maxOverdueDays: 0,
        onTimePaymentsCount: 0,
      );
      expect(score, 100.0);
    });

    test('Defaulter should get massive penalty', () {
      final score = CreditScoreCalculator.calculate(
        totalDefaults: 1, // Marked as defaulter once
        maxOverdueDays: 0,
        onTimePaymentsCount: 0,
      );
      // 100 - 50 = 50
      expect(score, 50.0);
    });

    test('Overdue days should reduce score', () {
      // 35 days overdue = ceil(35/30) = 2 blocks of 30 days penalty?
      // Logic says ceil. 35/30 = 1.16 -> ceil = 2.
      // Penalty per block = 10. So 2 * 10 = 20.
      // Score = 100 - 20 = 80.

      final score = CreditScoreCalculator.calculate(
        totalDefaults: 0,
        maxOverdueDays: 35,
        onTimePaymentsCount: 0,
      );
      expect(score, 80.0);
    });

    test('Good behavior should increase score but cap at 100', () {
      // Base score 100 + 5 bonus = 105 -> Clamped to 100
      final score = CreditScoreCalculator.calculate(
        totalDefaults: 0,
        maxOverdueDays: 0,
        onTimePaymentsCount: 1,
      );
      expect(score, 100.0);
    });

    test('Mixed signals: Late but paid often', () {
      // Late: 60 days overdue -> ceil(2) * 10 = -20 penalty. Base = 80.
      // Good: 10 on-time payments -> 10 * 5 = +50 bonus.
      // Calc: 100 - 20 + 50 = 130 -> Clamped 100.

      // Let's try a scenario that doesn't cap.
      // Defaulted (-50) -> Base 50.
      // 2 On-time payments (+10) -> 60.

      final score = CreditScoreCalculator.calculate(
        totalDefaults: 1,
        maxOverdueDays: 0,
        onTimePaymentsCount: 2,
      );
      expect(score, 60.0);
    });

    test('Phone hashing should be consistent and normalized', () {
      const phone1 = "+91 98765 43210";
      const phone2 = "9876543210"; // Same number

      final hash1 = CreditScoreCalculator.hashPhone(phone1);
      final hash2 = CreditScoreCalculator.hashPhone(phone2);

      expect(hash1, hash2);
      expect(hash1.length, 64); // SHA-256 hex length
    });
  });
}
