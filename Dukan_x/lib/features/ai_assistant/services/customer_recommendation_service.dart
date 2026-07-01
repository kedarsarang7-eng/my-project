import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/repository/customers_repository.dart';

/// AI Customer Recommendation Service
///
/// Implements a behavior-based ranking system to suggest relevant customers
/// during bill creation.
///
/// Scoring Model (Heuristic):
/// - Recency (40%): How recently did they visit?
/// - Frequency (30%): How often do they visit?
/// - Time Affinity (20%): Do they visit at this time of day?
/// - Monetary (10%): High value customers boosted slightly.
class CustomerRecommendationService {
  final AppDatabase _db;
  final CustomersRepository _customersRepo;

  CustomerRecommendationService(this._db, this._customersRepo);

  /// Get ranked list of customers based on behavioral score
  Future<List<Customer>> getRecommendedCustomers({
    required String userId,
    String? query,
    int limit = 10,
  }) async {
    // If searching, just use standard search with slight boost
    if (query != null && query.isNotEmpty) {
      return _searchWithBoost(userId, query);
    }

    try {
      final now = DateTime.now();
      final timeSlot = _getTimeSlot(now);

      // Fetch all behaviors for user
      // Note: In a larger app, we would paginate or limit this query
      final behaviors = await (_db.select(
        _db.customerBehaviors,
      )..where((t) => t.userId.equals(userId))).get();

      // Score each customer
      final scoredCustomers = <String, double>{};
      for (final b in behaviors) {
        final score = _calculateScore(b, now, timeSlot);
        scoredCustomers[b.customerId] = score;
      }

      // Sort by score descending
      final sortedIds = scoredCustomers.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final topIds = sortedIds.take(limit).map((e) => e.key).toList();

      if (topIds.isEmpty) return [];

      // Fetch actual customer details
      final entities = await (_db.select(
        _db.customers,
      )..where((t) => t.id.isIn(topIds))).get();

      // Convert to Domain Object
      final customers = entities.map(_entityToCustomer).toList();

      // Sort result to match the scored order (db fetch might scramble order)
      customers.sort((a, b) {
        final scoreA = scoredCustomers[a.id] ?? 0;
        final scoreB = scoredCustomers[b.id] ?? 0;
        return scoreB.compareTo(scoreA);
      });

      return customers;
    } catch (e) {
      // Fallback to simple recently updated
      return _getRecentCustomers(userId, limit);
    }
  }

  /// Update customer behavior stats after a bill is created
  Future<void> trackVisit({
    required String userId,
    required String customerId,
    required double billAmount,
  }) async {
    try {
      final now = DateTime.now();
      final timeSlot = _getTimeSlot(now);

      // Check if behavior record exists
      final existing = await (_db.select(
        _db.customerBehaviors,
      )..where((t) => t.customerId.equals(customerId))).getSingleOrNull();

      if (existing == null) {
        // Create new record
        await _db
            .into(_db.customerBehaviors)
            .insert(
              CustomerBehaviorsCompanion.insert(
                customerId: customerId,
                userId: userId,
                lastVisit: now,
                visitCount: const Value(1),
                overallPeriodDays: const Value(1),
                morningVisits: Value(timeSlot == 'morning' ? 1 : 0),
                afternoonVisits: Value(timeSlot == 'afternoon' ? 1 : 0),
                eveningVisits: Value(timeSlot == 'evening' ? 1 : 0),
                totalSpend: Value(billAmount),
                avgBillAmount: Value(billAmount),
                scoreUpdatedAt: now,
              ),
            );
      } else {
        // Update existing
        final newCount = existing.visitCount + 1;
        final newTotal = existing.totalSpend + billAmount;

        await (_db.update(
          _db.customerBehaviors,
        )..where((t) => t.customerId.equals(customerId))).write(
          CustomerBehaviorsCompanion(
            lastVisit: Value(now),
            visitCount: Value(newCount),
            morningVisits: Value(
              existing.morningVisits + (timeSlot == 'morning' ? 1 : 0),
            ),
            afternoonVisits: Value(
              existing.afternoonVisits + (timeSlot == 'afternoon' ? 1 : 0),
            ),
            eveningVisits: Value(
              existing.eveningVisits + (timeSlot == 'evening' ? 1 : 0),
            ),
            totalSpend: Value(newTotal),
            avgBillAmount: Value(newTotal / newCount),
            scoreUpdatedAt: Value(now),
          ),
        );
      }
    } catch (e) {
      // Log error but don't block flow - use debugPrint for production safety
      debugPrint('Error tracking visit: $e');
    }
  }

  // --- Helper Logic ---

  double _calculateScore(
    CustomerBehaviorEntity b,
    DateTime now,
    String currentTimeSlot,
  ) {
    // 1. Recency Score (0-1)
    // Decays rapidly over 30 days
    final daysSince = now.difference(b.lastVisit).inDays;
    final recencyScore = 1.0 / (daysSince + 1);

    // 2. Frequency Score (0-1)
    // Logarithmic scale to dampen effect of very high frequency
    // Assumes 10 visits is "high" frequency
    final frequencyScore = (b.visitCount > 20) ? 1.0 : (b.visitCount / 20.0);

    // 3. Time Affinity Score (0-1)
    // Ratio of visits in current time slot
    double timeScore = 0.0;
    final totalTimed = b.morningVisits + b.afternoonVisits + b.eveningVisits;
    if (totalTimed > 0) {
      if (currentTimeSlot == 'morning') {
        timeScore = b.morningVisits / totalTimed;
      } else if (currentTimeSlot == 'afternoon') {
        timeScore = b.afternoonVisits / totalTimed;
      } else {
        timeScore = b.eveningVisits / totalTimed;
      }
    }

    // 4. Monetary Score (0-1)
    // Normalized against a 'high spender' threshold (e.g. 5000 avg)
    final monetaryScore = (b.avgBillAmount > 5000)
        ? 1.0
        : (b.avgBillAmount / 5000.0);

    // Weighted Sum
    // Recency (40%) + Frequency (30%) + Time (20%) + Monetary (10%)
    return (recencyScore * 0.4) +
        (frequencyScore * 0.3) +
        (timeScore * 0.2) +
        (monetaryScore * 0.1);
  }

  String _getTimeSlot(DateTime time) {
    final hour = time.hour;
    if (hour >= 5 && hour < 12) return 'morning';
    if (hour >= 12 && hour < 17) return 'afternoon';
    return 'evening';
  }

  Future<List<Customer>> _searchWithBoost(String userId, String query) async {
    // Standard search but could be boosted by score in future
    final result = await _customersRepo.search(query, userId: userId);
    return result.data ?? [];
  }

  Future<List<Customer>> _getRecentCustomers(String userId, int limit) async {
    final entities =
        await (_db.select(_db.customers)
              ..where((t) => t.userId.equals(userId))
              ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
              ..limit(limit))
            .get();
    return entities.map(_entityToCustomer).toList();
  }

  Customer _entityToCustomer(CustomerEntity e) => Customer(
    id: e.id,
    odId: e.userId,
    name: e.name,
    phone: e.phone,
    email: e.email,
    address: e.address,
    gstin: e.gstin,
    totalBilled: e.totalBilled,
    totalPaid: e.totalPaid,
    totalDues: e.totalDues,
    isActive: e.isActive,
    isSynced: e.isSynced,
    createdAt: e.createdAt,
    updatedAt: e.updatedAt,
    deletedAt: e.deletedAt,
  );
}
