import 'package:dukanx/core/compat/firestore_compat.dart';
import '../../../../core/error/error_handler.dart';
import '../../../../services/local_storage_service.dart';
import '../../models/vendor_item_snapshot.dart';

/// Repository for vendor item snapshots (customer read cache).
/// Customers ONLY read from this - never from vendor_items directly.
class VendorItemSnapshotRepository {
  final FirebaseFirestore _firestore;
  final LocalStorageService _localStorage;

  static const String _collectionName = 'vendor_item_snapshots';

  VendorItemSnapshotRepository({
    required FirebaseFirestore firestore,
    required LocalStorageService localStorage,
  }) : _firestore = firestore,
       _localStorage = localStorage;

  /// Get snapshot for a vendor (cache-first strategy)
  Future<VendorItemSnapshot?> getSnapshot(String vendorId) async {
    // 1. Try local cache first
    final cached = await _getLocalSnapshot(vendorId);
    if (cached != null) {
      // Check if cache is still fresh (< 5 minutes old)
      final age = DateTime.now().difference(cached.snapshotUpdatedAt);
      if (age.inMinutes < 5) {
        return cached;
      }
    }

    // 2. Fetch from Firestore
    try {
      final doc = await _firestore
          .collection(_collectionName)
          .doc(vendorId)
          .get();

      if (doc.exists && doc.data() != null) {
        final snapshot = VendorItemSnapshot.fromMap(vendorId, doc.data()!);
        // Cache locally
        await _saveLocalSnapshot(snapshot);
        return snapshot;
      }
    } catch (e) {
      // On error, return cached if available
      if (cached != null) return cached;
      rethrow;
    }

    return cached; // Return stale cache if nothing else
  }

  /// Force refresh from Firestore
  Future<VendorItemSnapshot?> refreshSnapshot(String vendorId) async {
    try {
      final doc = await _firestore
          .collection(_collectionName)
          .doc(vendorId)
          .get();

      if (doc.exists && doc.data() != null) {
        final snapshot = VendorItemSnapshot.fromMap(vendorId, doc.data()!);
        await _saveLocalSnapshot(snapshot);
        return snapshot;
      }
    } catch (e) {
      ErrorHandler.handle(e, userMessage: 'Failed to refresh snapshot');
    }
    return null;
  }

  /// Watch snapshot changes (real-time updates)
  Stream<VendorItemSnapshot?> watchSnapshot(String vendorId) {
    return _firestore.collection(_collectionName).doc(vendorId).snapshots().map(
      (doc) {
        if (doc.exists && doc.data() != null) {
          final snapshot = VendorItemSnapshot.fromMap(vendorId, doc.data()!);
          // Update local cache asynchronously
          _saveLocalSnapshot(snapshot);
          return snapshot;
        }
        return null;
      },
    );
  }

  /// Update snapshot (called by vendor-side after stock changes)
  Future<void> updateSnapshot(VendorItemSnapshot snapshot) async {
    await _firestore
        .collection(_collectionName)
        .doc(snapshot.vendorId)
        .set(snapshot.toMap());
    await _saveLocalSnapshot(snapshot);
  }

  /// Update single item in snapshot (efficient partial update)
  Future<void> updateSnapshotItem(
    String vendorId,
    SnapshotItem updatedItem,
  ) async {
    final current = await getSnapshot(vendorId);
    if (current == null) return;

    final updatedItems = current.items.map((item) {
      if (item.itemId == updatedItem.itemId) {
        return updatedItem;
      }
      return item;
    }).toList();

    final updatedSnapshot = current.copyWith(
      items: updatedItems,
      snapshotUpdatedAt: DateTime.now(),
    );

    await updateSnapshot(updatedSnapshot);
  }

  // ============================================
  // LOCAL CACHE OPERATIONS
  // ============================================

  Future<VendorItemSnapshot?> _getLocalSnapshot(String vendorId) async {
    try {
      final data = _localStorage.getRequestDraft('snapshot_$vendorId');
      if (data != null) {
        return VendorItemSnapshot.fromMap(vendorId, data);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _saveLocalSnapshot(VendorItemSnapshot snapshot) async {
    try {
      await _localStorage.saveRequestDraft(
        'snapshot_${snapshot.vendorId}',
        snapshot.toMap(),
      );
    } catch (_) {}
  }
}
