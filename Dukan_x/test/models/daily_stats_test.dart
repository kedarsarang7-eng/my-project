// ============================================================================
// MODELS TEST
// ============================================================================
// Comprehensive tests for application models
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/models/daily_stats.dart';

void main() {
  group('DailyStats Model Tests', () {
    test('should create DailyStats with required fields', () {
      final stats = DailyStats(
        todaySales: 5000.0,
        todaySpend: 2000.0,
        totalPending: 1500.0,
        lowStockCount: 5,
        paidThisMonth: 8000.0,
        overdueAmount: 500.0,
      );

      expect(stats.todaySales, 5000.0);
      expect(stats.todaySpend, 2000.0);
      expect(stats.totalPending, 1500.0);
      expect(stats.lowStockCount, 5);
      expect(stats.paidThisMonth, 8000.0);
      expect(stats.overdueAmount, 500.0);
    });

    test('empty factory should return zero values', () {
      final stats = DailyStats.empty();

      expect(stats.todaySales, 0);
      expect(stats.todaySpend, 0);
      expect(stats.totalPending, 0);
      expect(stats.lowStockCount, 0);
      expect(stats.paidThisMonth, 0);
      expect(stats.overdueAmount, 0);
    });

    test('should handle large values', () {
      final stats = DailyStats(
        todaySales: 999999999.99,
        todaySpend: 888888888.88,
        totalPending: 777777777.77,
        lowStockCount: 1000000,
        paidThisMonth: 666666666.66,
        overdueAmount: 555555555.55,
      );

      expect(stats.todaySales, 999999999.99);
      expect(stats.todaySpend, 888888888.88);
      expect(stats.totalPending, 777777777.77);
      expect(stats.lowStockCount, 1000000);
    });

    test('should handle decimal precision', () {
      final stats = DailyStats(
        todaySales: 123.456789,
        todaySpend: 456.789012,
        totalPending: 789.012345,
        lowStockCount: 0,
        paidThisMonth: 111.222333,
        overdueAmount: 444.555666,
      );

      expect(stats.todaySales, 123.456789);
      expect(stats.todaySpend, 456.789012);
      expect(stats.totalPending, 789.012345);
    });

    test('should handle negative values', () {
      // Edge case - negative values might indicate refunds/credits
      final stats = DailyStats(
        todaySales: -100.0,
        todaySpend: -50.0,
        totalPending: -25.0,
        lowStockCount: 0,
        paidThisMonth: -10.0,
        overdueAmount: -5.0,
      );

      expect(stats.todaySales, -100.0);
      expect(stats.todaySpend, -50.0);
      expect(stats.totalPending, -25.0);
    });

    test('should be const constructible', () {
      const stats = DailyStats(
        todaySales: 100,
        todaySpend: 50,
        totalPending: 25,
        lowStockCount: 3,
        paidThisMonth: 200,
        overdueAmount: 10,
      );

      expect(stats.todaySales, 100);
    });
  });

  group('VendorStats Model Tests', () {
    test('should create VendorStats with required fields', () {
      final stats = VendorStats(
        totalInvoiceValue: 50000.0,
        paidAmount: 30000.0,
        unpaidAmount: 20000.0,
        todayPurchase: 5000.0,
        activeOrders: 10,
      );

      expect(stats.totalInvoiceValue, 50000.0);
      expect(stats.paidAmount, 30000.0);
      expect(stats.unpaidAmount, 20000.0);
      expect(stats.todayPurchase, 5000.0);
      expect(stats.activeOrders, 10);
    });

    test('empty factory should return zero values', () {
      final stats = VendorStats.empty();

      expect(stats.totalInvoiceValue, 0);
      expect(stats.paidAmount, 0);
      expect(stats.unpaidAmount, 0);
      expect(stats.todayPurchase, 0);
      expect(stats.activeOrders, 0);
    });

    test('should handle large values', () {
      final stats = VendorStats(
        totalInvoiceValue: 1000000000.0,
        paidAmount: 500000000.0,
        unpaidAmount: 500000000.0,
        todayPurchase: 10000000.0,
        activeOrders: 500,
      );

      expect(stats.totalInvoiceValue, 1000000000.0);
      expect(stats.paidAmount, 500000000.0);
      expect(stats.unpaidAmount, 500000000.0);
      expect(stats.todayPurchase, 10000000.0);
      expect(stats.activeOrders, 500);
    });

    test(
      'paidAmount + unpaidAmount should typically equal totalInvoiceValue',
      () {
        final stats = VendorStats(
          totalInvoiceValue: 100000.0,
          paidAmount: 60000.0,
          unpaidAmount: 40000.0,
          todayPurchase: 5000.0,
          activeOrders: 5,
        );

        expect(stats.paidAmount + stats.unpaidAmount, stats.totalInvoiceValue);
      },
    );

    test('should handle zero active orders', () {
      final stats = VendorStats(
        totalInvoiceValue: 10000.0,
        paidAmount: 10000.0,
        unpaidAmount: 0,
        todayPurchase: 0,
        activeOrders: 0,
      );

      expect(stats.activeOrders, 0);
      expect(stats.unpaidAmount, 0);
    });

    test('should be const constructible', () {
      const stats = VendorStats(
        totalInvoiceValue: 1000,
        paidAmount: 500,
        unpaidAmount: 500,
        todayPurchase: 100,
        activeOrders: 2,
      );

      expect(stats.totalInvoiceValue, 1000);
    });
  });

  group('Stats Comparison Tests', () {
    test('empty DailyStats should equal another empty DailyStats values', () {
      final stats1 = DailyStats.empty();
      final stats2 = DailyStats.empty();

      expect(stats1.todaySales, stats2.todaySales);
      expect(stats1.todaySpend, stats2.todaySpend);
      expect(stats1.totalPending, stats2.totalPending);
      expect(stats1.lowStockCount, stats2.lowStockCount);
      expect(stats1.paidThisMonth, stats2.paidThisMonth);
      expect(stats1.overdueAmount, stats2.overdueAmount);
    });

    test('empty VendorStats should equal another empty VendorStats values', () {
      final stats1 = VendorStats.empty();
      final stats2 = VendorStats.empty();

      expect(stats1.totalInvoiceValue, stats2.totalInvoiceValue);
      expect(stats1.paidAmount, stats2.paidAmount);
      expect(stats1.unpaidAmount, stats2.unpaidAmount);
      expect(stats1.todayPurchase, stats2.todayPurchase);
      expect(stats1.activeOrders, stats2.activeOrders);
    });
  });
}
