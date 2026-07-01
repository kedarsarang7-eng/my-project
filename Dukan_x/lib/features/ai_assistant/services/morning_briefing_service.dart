import 'package:flutter/material.dart';
import '../../../../core/repository/reports_repository.dart';

class MorningBriefingService {
  final ReportsRepository _reportsRepo;

  MorningBriefingService(this._reportsRepo);

  /// Generates a smart briefing message for the dashboard
  Future<String> getBriefing(String userId) async {
    try {
      // 1. Get Time-based Greeting
      final hour = DateTime.now().hour;
      String greeting = "Good Morning";
      if (hour >= 12 && hour < 17) greeting = "Good Afternoon";
      if (hour >= 17) greeting = "Good Evening";

      // 2. Get Today's Stats
      final todayStats = await _reportsRepo.watchDailyStats(userId).first;
      final todaySales = todayStats.todaySales;

      // 3. Get Yesterday's Sales for comparison
      // We ask for 7 days to be safe, but we look for yesterday
      final trendResult = await _reportsRepo.getSalesTrend(
        userId: userId,
        days: 7,
      );

      double yesterdaySales = 0;
      if (trendResult.success && trendResult.data != null) {
        final now = DateTime.now();
        final yesterday = now.subtract(const Duration(days: 1));
        final yesterdayKey =
            "${yesterday.year}-${yesterday.month}-${yesterday.day}";

        final yesterdayEntry = trendResult.data!.firstWhere(
          (e) => e['date'] == yesterdayKey,
          orElse: () => {'value': 0.0},
        );
        yesterdaySales = (yesterdayEntry['value'] as num).toDouble();
      }

      // 4. Generate Insight Logic
      String insight = "";

      if (todaySales == 0) {
        if (yesterdaySales > 0) {
          insight =
              "Yesterday you sold ₹${yesterdaySales.toStringAsFixed(0)}. Ready to beat it today?";
        } else {
          insight = "Ready to record your first sale of the day?";
        }
      } else {
        if (yesterdaySales > 0) {
          if (todaySales > yesterdaySales) {
            final diff = ((todaySales - yesterdaySales) / yesterdaySales * 100)
                .toStringAsFixed(0);
            insight =
                "Great job! You're $diff% ahead of yesterday (₹${yesterdaySales.toStringAsFixed(0)}).";
          } else {
            final remaining = yesterdaySales - todaySales;
            insight =
                "You need ₹${remaining.toStringAsFixed(0)} to match yesterday's sales.";
          }
        } else {
          insight =
              "Off to a specific start! Today's sales: ₹${todaySales.toStringAsFixed(0)}.";
        }
      }

      return "$greeting! $insight";
    } catch (e) {
      debugPrint("Briefing Error: $e");
      return "Welcome back to your dashboard.";
    }
  }
}
