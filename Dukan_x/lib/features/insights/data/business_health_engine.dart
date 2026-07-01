// ============================================================================
// BUSINESS HEALTH ENGINE
// ============================================================================
// Calculates business health score (0-100) from offline Drift data
//
// Factors:
// - Sales Trend (30%)
// - Pending Payments (25%)
// - Stock Health (20%)
// - Cash Flow (15%)
// - Sync Health (10%)
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'dart:math';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';

/// Health Score Result
class HealthScoreResult {
  final int score; // 0-100
  final HealthGrade grade;
  final List<HealthFactor> factors;
  final String summary;
  final List<String> recommendations;
  final DateTime calculatedAt;

  const HealthScoreResult({
    required this.score,
    required this.grade,
    required this.factors,
    required this.summary,
    required this.recommendations,
    required this.calculatedAt,
  });

  /// Check if score dropped since last check
  bool isScoreDropped(HealthScoreResult? previous) {
    return previous != null && score < previous.score;
  }

  /// Get change explanation
  String? getChangeExplanation(HealthScoreResult? previous) {
    if (previous == null) return null;
    if (score == previous.score) return null;

    // Find biggest contributor to change
    for (final factor in factors) {
      final prevFactor = previous.factors.firstWhere(
        (f) => f.type == factor.type,
        orElse: () => factor,
      );
      if (factor.score < prevFactor.score - 10) {
        return 'Your score dropped because ${factor.type.explanation}.';
      }
    }

    if (score < previous.score) {
      return 'Your score dropped by ${previous.score - score} points.';
    } else {
      return 'Your score improved by ${score - previous.score} points!';
    }
  }
}

/// Health Grade Enum
enum HealthGrade {
  critical, // 0-25
  poor, // 26-50
  fair, // 51-70
  good, // 71-85
  excellent, // 86-100
}

extension HealthGradeExtension on HealthGrade {
  String get label {
    switch (this) {
      case HealthGrade.critical:
        return 'Critical';
      case HealthGrade.poor:
        return 'Poor';
      case HealthGrade.fair:
        return 'Fair';
      case HealthGrade.good:
        return 'Good';
      case HealthGrade.excellent:
        return 'Excellent';
    }
  }

  int get colorValue {
    switch (this) {
      case HealthGrade.critical:
        return 0xFFDC2626; // Red
      case HealthGrade.poor:
        return 0xFFEF4444; // Light Red
      case HealthGrade.fair:
        return 0xFFF59E0B; // Yellow/Orange
      case HealthGrade.good:
        return 0xFF10B981; // Green
      case HealthGrade.excellent:
        return 0xFF059669; // Dark Green
    }
  }
}

/// Health Factor Types
enum HealthFactorType {
  salesTrend,
  pendingPayments,
  stockHealth,
  cashFlow,
  syncHealth,
}

extension HealthFactorTypeExtension on HealthFactorType {
  String get label {
    switch (this) {
      case HealthFactorType.salesTrend:
        return 'Sales Trend';
      case HealthFactorType.pendingPayments:
        return 'Pending Payments';
      case HealthFactorType.stockHealth:
        return 'Stock Health';
      case HealthFactorType.cashFlow:
        return 'Cash Flow';
      case HealthFactorType.syncHealth:
        return 'Sync Status';
    }
  }

  String get explanation {
    switch (this) {
      case HealthFactorType.salesTrend:
        return 'sales decreased recently';
      case HealthFactorType.pendingPayments:
        return 'pending payments increased';
      case HealthFactorType.stockHealth:
        return 'stock levels are low';
      case HealthFactorType.cashFlow:
        return 'expenses exceeded income';
      case HealthFactorType.syncHealth:
        return 'sync is pending';
    }
  }

  double get weight {
    switch (this) {
      case HealthFactorType.salesTrend:
        return 0.30;
      case HealthFactorType.pendingPayments:
        return 0.25;
      case HealthFactorType.stockHealth:
        return 0.20;
      case HealthFactorType.cashFlow:
        return 0.15;
      case HealthFactorType.syncHealth:
        return 0.10;
    }
  }
}

/// Individual Health Factor
class HealthFactor {
  final HealthFactorType type;
  final int score; // 0-100 for this factor
  final String status;
  final String detail;

  const HealthFactor({
    required this.type,
    required this.score,
    required this.status,
    required this.detail,
  });
}

/// Business Health Engine - Singleton
class BusinessHealthEngine {
  static BusinessHealthEngine? _instance;
  static BusinessHealthEngine get instance =>
      _instance ??= BusinessHealthEngine._();

  BusinessHealthEngine._();

  final AppDatabase _database = AppDatabase.instance;

  /// Calculate health score for user
  Future<HealthScoreResult> calculateHealthScore(String userId) async {
    final now = DateTime.now();
    final factors = <HealthFactor>[];

    // 1. Calculate Sales Trend (30%)
    final salesFactor = await _calculateSalesTrend(userId);
    factors.add(salesFactor);

    // 2. Calculate Pending Payments (25%)
    final pendingFactor = await _calculatePendingPayments(userId);
    factors.add(pendingFactor);

    // 3. Calculate Stock Health (20%)
    final stockFactor = await _calculateStockHealth(userId);
    factors.add(stockFactor);

    // 4. Calculate Cash Flow (15%)
    final cashFlowFactor = await _calculateCashFlow(userId);
    factors.add(cashFlowFactor);

    // 5. Calculate Sync Health (10%)
    final syncFactor = await _calculateSyncHealth();
    factors.add(syncFactor);

    // Calculate weighted total
    double weightedTotal = 0;
    for (final factor in factors) {
      weightedTotal += factor.score * factor.type.weight;
    }
    final totalScore = weightedTotal.round().clamp(0, 100);

    // Determine grade
    final grade = _scoreToGrade(totalScore);

    // Generate summary and recommendations
    final summary = _generateSummary(totalScore, factors);
    final recommendations = _generateRecommendations(factors);

    return HealthScoreResult(
      score: totalScore,
      grade: grade,
      factors: factors,
      summary: summary,
      recommendations: recommendations,
      calculatedAt: now,
    );
  }

  /// Calculate Sales Trend Factor
  Future<HealthFactor> _calculateSalesTrend(String userId) async {
    try {
      final now = DateTime.now();
      final last7Days = now.subtract(const Duration(days: 7));
      final last30Days = now.subtract(const Duration(days: 30));

      final b = _database.bills;

      // Get sales from last 7 days
      final recentQuery =
          await (_database.selectOnly(b)
                ..addColumns([b.grandTotal.sum()])
                ..where(
                  b.userId.equals(userId) &
                      b.billDate.isBiggerOrEqualValue(last7Days),
                ))
              .getSingleOrNull();
      final recentSales =
          (recentQuery?.read(b.grandTotal.sum()) as double?) ?? 0.0;

      // Get sales from previous 23 days (7-30 days ago)
      final olderQuery =
          await (_database.selectOnly(b)
                ..addColumns([b.grandTotal.sum()])
                ..where(
                  b.userId.equals(userId) &
                      b.billDate.isBiggerOrEqualValue(last30Days) &
                      b.billDate.isSmallerThanValue(last7Days),
                ))
              .getSingleOrNull();
      final olderSales =
          (olderQuery?.read(b.grandTotal.sum()) as double?) ?? 0.0;

      // Calculate trend (normalize older sales to 7-day equivalent)
      final olderNormalized = olderSales * (7 / 23);
      double growthRate = 0;
      if (olderNormalized > 0) {
        growthRate = ((recentSales - olderNormalized) / olderNormalized) * 100;
      }

      // Score: -50% = 0, 0% = 50, +20% = 100
      int score;
      if (growthRate >= 20) {
        score = 100;
      } else if (growthRate >= 0) {
        score = 50 + ((growthRate / 20) * 50).round();
      } else if (growthRate >= -50) {
        score = max(0, 50 + (growthRate).round());
      } else {
        score = 0;
      }

      String status;
      if (growthRate > 10) {
        status = 'Growing';
      } else if (growthRate > -10) {
        status = 'Stable';
      } else {
        status = 'Declining';
      }

      return HealthFactor(
        type: HealthFactorType.salesTrend,
        score: score,
        status: status,
        detail:
            '${growthRate >= 0 ? '+' : ''}${growthRate.toStringAsFixed(1)}% vs last month',
      );
    } catch (e) {
      return const HealthFactor(
        type: HealthFactorType.salesTrend,
        score: 50,
        status: 'Unknown',
        detail: 'Unable to calculate trend',
      );
    }
  }

  /// Calculate Pending Payments Factor
  Future<HealthFactor> _calculatePendingPayments(String userId) async {
    try {
      final c = _database.customers;
      final b = _database.bills;

      // Get total pending dues
      final pendingQuery =
          await (_database.selectOnly(c)
                ..addColumns([c.totalDues.sum()])
                ..where(c.userId.equals(userId)))
              .getSingleOrNull();
      final totalPending =
          (pendingQuery?.read(c.totalDues.sum()) as double?) ?? 0.0;

      // Get total sales (last 30 days for ratio)
      final now = DateTime.now();
      final last30Days = now.subtract(const Duration(days: 30));
      final salesQuery =
          await (_database.selectOnly(b)
                ..addColumns([b.grandTotal.sum()])
                ..where(
                  b.userId.equals(userId) &
                      b.billDate.isBiggerOrEqualValue(last30Days),
                ))
              .getSingleOrNull();
      final totalSales =
          (salesQuery?.read(b.grandTotal.sum()) as double?) ?? 1.0;

      // Calculate pending ratio
      final pendingRatio = totalSales > 0
          ? (totalPending / totalSales) * 100
          : 0.0;

      // Score: >50% = 0, 10% = 80, <10% = 100
      int score;
      if (pendingRatio < 10) {
        score = 100;
      } else if (pendingRatio < 30) {
        score = 100 - ((pendingRatio - 10) * 2).round();
      } else if (pendingRatio < 50) {
        score = 60 - ((pendingRatio - 30) * 2).round();
      } else {
        score = max(0, 20 - (pendingRatio - 50).round());
      }

      String status;
      if (pendingRatio < 15) {
        status = 'Healthy';
      } else if (pendingRatio < 35) {
        status = 'Moderate';
      } else {
        status = 'High';
      }

      return HealthFactor(
        type: HealthFactorType.pendingPayments,
        score: score,
        status: status,
        detail:
            '₹${_formatAmount(totalPending)} pending (${pendingRatio.toStringAsFixed(0)}% of sales)',
      );
    } catch (e) {
      return const HealthFactor(
        type: HealthFactorType.pendingPayments,
        score: 50,
        status: 'Unknown',
        detail: 'Unable to calculate',
      );
    }
  }

  /// Calculate Stock Health Factor
  Future<HealthFactor> _calculateStockHealth(String userId) async {
    try {
      final p = _database.products;

      // Get total products
      final totalQuery =
          await (_database.selectOnly(p)
                ..addColumns([p.id.count()])
                ..where(p.userId.equals(userId)))
              .getSingleOrNull();
      final totalProducts =
          (totalQuery?.read(p.id.count()) as int?) ?? 0;

      if (totalProducts == 0) {
        return const HealthFactor(
          type: HealthFactorType.stockHealth,
          score: 100,
          status: 'N/A',
          detail: 'No products tracked',
        );
      }

      // Get low stock count (stockQuantity <= lowStockThreshold)
      final lowStockQuery =
          await (_database.selectOnly(p)
                ..addColumns([p.id.count()])
                ..where(
                  p.userId.equals(userId) &
                      p.stockQuantity.isSmallerOrEqual(
                        p.lowStockThreshold,
                      ),
                ))
              .getSingleOrNull();
      final lowStockCount =
          (lowStockQuery?.read(p.id.count()) as int?) ?? 0;

      // Get out of stock count
      final outOfStockQuery =
          await (_database.selectOnly(p)
                ..addColumns([p.id.count()])
                ..where(
                  p.userId.equals(userId) &
                      p.stockQuantity.equals(0),
                ))
              .getSingleOrNull();
      final outOfStockCount =
          (outOfStockQuery?.read(p.id.count()) as int?) ?? 0;

      // Calculate ratios
      final lowStockRatio = (lowStockCount / totalProducts) * 100;
      final outOfStockRatio = (outOfStockCount / totalProducts) * 100;

      // Score: penalize both low and out of stock
      int score = 100;
      score -= (outOfStockRatio * 2).round(); // -2 points per % out of stock
      score -= lowStockRatio.round(); // -1 point per % low stock
      score = score.clamp(0, 100);

      String status;
      if (outOfStockCount == 0 && lowStockCount == 0) {
        status = 'Healthy';
      } else if (outOfStockRatio < 5) {
        status = 'Low Stock';
      } else {
        status = 'Critical';
      }

      return HealthFactor(
        type: HealthFactorType.stockHealth,
        score: score,
        status: status,
        detail: '$lowStockCount low, $outOfStockCount out of stock',
      );
    } catch (e) {
      return const HealthFactor(
        type: HealthFactorType.stockHealth,
        score: 50,
        status: 'Unknown',
        detail: 'Unable to calculate',
      );
    }
  }

  /// Calculate Cash Flow Factor
  Future<HealthFactor> _calculateCashFlow(String userId) async {
    try {
      final now = DateTime.now();
      final last30Days = now.subtract(const Duration(days: 30));
      final b = _database.bills;
      final po = _database.purchaseOrders;

      // Get income (sales)
      final incomeQuery =
          await (_database.selectOnly(b)
                ..addColumns([b.grandTotal.sum()])
                ..where(
                  b.userId.equals(userId) &
                      b.billDate.isBiggerOrEqualValue(last30Days),
                ))
              .getSingleOrNull();
      final income = (incomeQuery?.read(b.grandTotal.sum()) as double?) ?? 0.0;

      // Get expenses (purchases)
      final expenseQuery =
          await (_database.selectOnly(po)
                ..addColumns([po.totalAmount.sum()])
                ..where(
                  po.userId.equals(userId) &
                      po.purchaseDate
                          .isBiggerOrEqualValue(last30Days),
                ))
              .getSingleOrNull();
      final expense =
          (expenseQuery?.read(po.totalAmount.sum()) as double?) ?? 0.0;

      // Calculate ratio
      double ratio = income > 0 ? income / max(expense, 1.0) : 1.0;

      // Score: ratio < 1 = bad, ratio 2+ = excellent
      int score;
      if (ratio >= 2) {
        score = 100;
      } else if (ratio >= 1.5) {
        score = 80 + ((ratio - 1.5) * 40).round();
      } else if (ratio >= 1) {
        score = 50 + ((ratio - 1) * 60).round();
      } else {
        score = max(0, (ratio * 50).round());
      }

      String status;
      if (ratio >= 1.5) {
        status = 'Profitable';
      } else if (ratio >= 1) {
        status = 'Break-even';
      } else {
        status = 'Negative';
      }

      return HealthFactor(
        type: HealthFactorType.cashFlow,
        score: score,
        status: status,
        detail:
            'Income: ₹${_formatAmount(income)}, Expense: ₹${_formatAmount(expense)}',
      );
    } catch (e) {
      return const HealthFactor(
        type: HealthFactorType.cashFlow,
        score: 50,
        status: 'Unknown',
        detail: 'Unable to calculate',
      );
    }
  }

  /// Calculate Sync Health Factor
  Future<HealthFactor> _calculateSyncHealth() async {
    try {
      final pending = await _database.getPendingSyncEntries();
      final pendingCount = pending.length;

      // Score: 0 pending = 100, 50+ = 0
      int score;
      if (pendingCount == 0) {
        score = 100;
      } else if (pendingCount < 10) {
        score = 90 - (pendingCount * 2);
      } else if (pendingCount < 50) {
        score = 70 - ((pendingCount - 10));
      } else {
        score = 20;
      }

      String status;
      if (pendingCount == 0) {
        status = 'Synced';
      } else if (pendingCount < 10) {
        status = 'Syncing';
      } else {
        status = 'Backlog';
      }

      return HealthFactor(
        type: HealthFactorType.syncHealth,
        score: score,
        status: status,
        detail: '$pendingCount items pending sync',
      );
    } catch (e) {
      return const HealthFactor(
        type: HealthFactorType.syncHealth,
        score: 80,
        status: 'Unknown',
        detail: 'Unable to check',
      );
    }
  }

  /// Convert score to grade
  HealthGrade _scoreToGrade(int score) {
    if (score >= 86) return HealthGrade.excellent;
    if (score >= 71) return HealthGrade.good;
    if (score >= 51) return HealthGrade.fair;
    if (score >= 26) return HealthGrade.poor;
    return HealthGrade.critical;
  }

  /// Generate summary text
  String _generateSummary(int score, List<HealthFactor> factors) {
    final weakest = factors.reduce((a, b) => a.score < b.score ? a : b);
    final strongest = factors.reduce((a, b) => a.score > b.score ? a : b);

    if (score >= 80) {
      return 'Your business is performing well! ${strongest.type.label} is your strongest area.';
    } else if (score >= 60) {
      return 'Business is doing okay. Focus on improving ${weakest.type.label}.';
    } else if (score >= 40) {
      return 'Attention needed. ${weakest.type.label} needs immediate action.';
    } else {
      return 'Critical state. Multiple areas need urgent attention.';
    }
  }

  /// Generate recommendations
  List<String> _generateRecommendations(List<HealthFactor> factors) {
    final recommendations = <String>[];

    for (final factor in factors.where((f) => f.score < 60)) {
      switch (factor.type) {
        case HealthFactorType.salesTrend:
          recommendations.add(
            '💡 Run promotions or reach out to inactive customers',
          );
          break;
        case HealthFactorType.pendingPayments:
          recommendations.add('💰 Send payment reminders to overdue customers');
          break;
        case HealthFactorType.stockHealth:
          recommendations.add('📦 Reorder low-stock items before they run out');
          break;
        case HealthFactorType.cashFlow:
          recommendations.add(
            '📊 Review expenses and collect pending payments',
          );
          break;
        case HealthFactorType.syncHealth:
          recommendations.add('☁️ Connect to WiFi to sync pending changes');
          break;
      }
    }

    if (recommendations.isEmpty) {
      recommendations.add('✨ Keep up the great work!');
    }

    return recommendations;
  }

  /// Format amount for display
  String _formatAmount(double amount) {
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(0);
  }
}

// ============================================================================
// RIVERPOD PROVIDERS
// ============================================================================

/// Provider for BusinessHealthEngine
final businessHealthEngineProvider = Provider<BusinessHealthEngine>((ref) {
  return BusinessHealthEngine.instance;
});

/// Provider for health score (auto-updates)
final healthScoreProvider = FutureProvider.family<HealthScoreResult, String>((
  ref,
  userId,
) async {
  final engine = ref.watch(businessHealthEngineProvider);
  return engine.calculateHealthScore(userId);
});

/// Provider for health score stream (periodic refresh)
final healthScoreStreamProvider =
    StreamProvider.family<HealthScoreResult, String>((ref, userId) async* {
      final engine = ref.watch(businessHealthEngineProvider);

      // Emit immediately
      yield await engine.calculateHealthScore(userId);

      // Then every 5 minutes
      await for (final _ in Stream.periodic(const Duration(minutes: 5))) {
        yield await engine.calculateHealthScore(userId);
      }
    });
