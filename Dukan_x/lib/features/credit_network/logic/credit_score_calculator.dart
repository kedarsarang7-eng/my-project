import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Calculates granular Trust Score (0-100)
class CreditScoreCalculator {
  static const double maxScore = 100.0;
  static const double minScore = 0.0;

  // Deductions
  static const double penaltyPer30DaysOverdue = 10.0;
  static const double penaltyDefaulterFlag = 50.0;

  // Bonuses
  static const double bonusOnTimePayment = 5.0;

  /// Calculate score based on behavioral signals
  static double calculate({
    required int totalDefaults,
    required double maxOverdueDays,
    required int onTimePaymentsCount,
  }) {
    double score = maxScore;

    // 1. Defaulter Penalty
    if (totalDefaults > 0) {
      score -= (totalDefaults * penaltyDefaulterFlag);
    }

    // 2. Late Payment Penalty (Aging)
    // -10 for every 30 days overdue
    if (maxOverdueDays > 0) {
      final penaltyFactor = (maxOverdueDays / 30).ceil();
      score -= (penaltyFactor * penaltyPer30DaysOverdue);
    }

    // 3. Good Behavior Bonus
    if (score < maxScore) {
      score += (onTimePaymentsCount * bonusOnTimePayment);
    }

    // Clamp
    return score.clamp(minScore, maxScore);
  }

  /// Secure Privacy-Preserving Hash for Phone Numbers
  /// Input: "+91 98765 43210" -> Normalized -> SHA-256
  static String hashPhone(String phone) {
    // 1. Normalize: Remove spaces, dashes, parentheses
    String normalized = phone.replaceAll(RegExp(r'[^0-9]'), '');

    // 2. Ensure country code (defaulting to 91 for now if missing - simplistic)
    if (normalized.length == 10) {
      normalized = '91$normalized';
    }

    // 3. Hash
    final bytes = utf8.encode(normalized);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
