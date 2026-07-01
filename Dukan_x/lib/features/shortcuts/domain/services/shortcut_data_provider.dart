import 'package:rxdart/rxdart.dart';
import '../../../../core/database/app_database.dart';

class ShortcutBadgeData {
  final int? count;
  final double? amount;
  final bool isWarning;

  const ShortcutBadgeData({this.count, this.amount, this.isWarning = false});

  bool get hasData =>
      (count != null && count! > 0) || (amount != null && amount! > 0);
}

class ShortcutDataProvider {
  final AppDatabase _db;

  ShortcutDataProvider({AppDatabase? db}) : _db = db ?? AppDatabase.instance;

  /// Stream of badge data for all shortcuts
  Stream<Map<String, ShortcutBadgeData>> watchBadgeData(String userId) {
    return Rx.combineLatest3(
      _watchLowStockCount(userId),
      _watchTodaySales(userId),
      _watchFailedSyncCount(),
      (int lowStock, double todaySales, int failedSync) {
        return {
          'LOW_STOCK': ShortcutBadgeData(count: lowStock, isWarning: true),
          'TODAY_SALES': ShortcutBadgeData(amount: todaySales),
          'SYNC_STATUS': ShortcutBadgeData(count: failedSync, isWarning: true),
        };
      },
    );
  }

  Stream<int> _watchLowStockCount(String userId) {
    // Watch all products and filter for low stock
    return _db.watchAllProducts(userId).map((products) {
      return products
          .where((p) => p.stockQuantity <= p.lowStockThreshold && p.isActive)
          .length;
    });
  }

  Stream<double> _watchTodaySales(String userId) {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    return _db.watchAllBills(userId).map((bills) {
      return bills
          .where(
            (b) =>
                b.billDate.isAfter(startOfDay) &&
                b.status != 'CANCELLED' &&
                b.status != 'DRAFT',
          )
          .fold(0.0, (sum, b) => sum + b.grandTotal);
    });
  }

  Stream<int> _watchFailedSyncCount() {
    // Watch dead letter queue count
    return Stream.fromFuture(_db.getDeadLetterCount());
    // Note: getDeadLetterCount is a Future in current DB, ideally we'd want a watcher
    // For now, we'll pool it or just fetch once.
    // Optimization: In real implementation, we might want to poll this periodically
    // or add a watcher to DeadLetterQueue table.
  }
}
