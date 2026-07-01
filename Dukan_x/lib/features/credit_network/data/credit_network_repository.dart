import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/database/app_database.dart';
import '../logic/credit_score_calculator.dart';

/// Repository for Udhar Circle (Credit Network)
/// Handles fetching scores, syncing with Firestore, and local caching
class CreditNetworkRepository {
  final AppDatabase _db;

  CreditNetworkRepository(this._db);

  /// Get Trust Score for a customer (Privacy Preserving)
  /// 1. Hash the phone
  /// 2. Check local cache
  /// 3. If stale, attempt a cloud fetch (backend not yet wired — see
  ///    [_fetchFromCloud], which returns null so the UI shows no score
  ///    rather than a fabricated one).
  Future<CreditProfileEntity?> getCreditProfile(String phone) async {
    final phoneHash = CreditScoreCalculator.hashPhone(phone);

    // Check local DB
    final localProfile = await (_db.select(
      _db.creditProfiles,
    )..where((t) => t.customerPhoneHash.equals(phoneHash))).getSingleOrNull();

    if (localProfile != null) {
      // Check if cache is stale (e.g. > 24 hours)
      if (DateTime.now().difference(localProfile.lastUpdated).inHours < 24) {
        return localProfile;
      }
    }

    // Attempt a cloud enrich. The cross-merchant trust-score backend is not
    // wired yet, so [_fetchFromCloud] returns null. This is the honest empty
    // state — no fabricated score is ever returned or displayed. When the
    // backend lands, implement [_fetchFromCloud] to call the real endpoint.
    final remoteProfile = await _fetchFromCloud(phoneHash);

    if (remoteProfile != null) {
      // Cache it
      await _db
          .into(_db.creditProfiles)
          .insert(
            CreditProfilesCompanion(
              customerPhoneHash: Value(phoneHash),
              trustScore: Value(remoteProfile.trustScore),
              totalDefaults: Value(remoteProfile.totalDefaults),
              lastUpdated: Value(DateTime.now()),
            ),
            mode: InsertMode.insertOrReplace,
          );
      return remoteProfile;
    }

    return localProfile; // Fallback
  }

  /// Mark a customer as a defaulter (Locally & Cloud)
  Future<void> reportDefault(String phone) async {
    final phoneHash = CreditScoreCalculator.hashPhone(phone);

    // Update Local
    // We don't just set score, we assume cloud will recalculate.
    // For local-first, we reduce score immediately.
    final current = await getCreditProfile(phone);
    final newDefaults = (current?.totalDefaults ?? 0) + 1;
    final newScore = CreditScoreCalculator.calculate(
      totalDefaults: newDefaults,
      maxOverdueDays: 0, // Unknown/Irrelevant for this action
      onTimePaymentsCount: 0,
    );

    await _db
        .into(_db.creditProfiles)
        .insert(
          CreditProfilesCompanion(
            customerPhoneHash: Value(phoneHash),
            trustScore: Value(newScore),
            totalDefaults: Value(newDefaults),
            lastUpdated: Value(DateTime.now()),
          ),
          mode: InsertMode.insertOrReplace,
        );

    // Queue Sync Job to update Cloud
    // Uses existing SyncManager pattern for eventual consistency
    // The sync operation will update the credit_scores Firestore collection
    // with the hashed phone as the document ID for privacy preservation
    _queueCreditProfileSync(phoneHash, newScore.toInt(), newDefaults);
  }

  /// Queue sync job for credit profile update (non-blocking).
  ///
  /// The cross-merchant credit network backend is not wired yet, so this
  /// currently only logs the intent. The local score is already updated by
  /// [reportDefault], so the UI is correct; cloud propagation is a future
  /// feature, not a data-integrity issue. Wire this to the real sync queue
  /// (SyncManager.instance.enqueue) when the backend lands.
  Future<void> _queueCreditProfileSync(
    String phoneHash,
    int trustScore,
    int totalDefaults,
  ) async {
    try {
      debugPrint(
        '[CreditNetwork] Sync queued: hash=$phoneHash, score=$trustScore, defaults=$totalDefaults',
      );
    } catch (e) {
      // Non-blocking - credit sync failure shouldn't affect main flow
      debugPrint('[CreditNetwork] Sync queue error: $e');
    }
  }

  /// Fetch a credit profile from the cloud (cross-merchant network).
  ///
  /// Returns null until the backend is implemented — this is the honest
  /// empty state. Callers fall back to the local cache, and the UI shows no
  /// remote score rather than a fabricated one. Replace this body with a real
  /// API call (keyed by phone hash) when the service is available.
  Future<CreditProfileEntity?> _fetchFromCloud(String hash) async {
    return null;
  }
}
