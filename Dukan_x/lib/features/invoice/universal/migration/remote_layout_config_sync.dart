import '../../../../core/api/api_client.dart';
import '../../../../models/business_type.dart';
import '../config/invoice_layout_config.dart';
import 'invoice_layout_migration.dart';

/// Fetch one business type's config JSON (null if absent). Returns the raw map.
typedef ConfigGet = Future<Map<String, dynamic>?> Function(String businessType);

/// Upsert one business type's config JSON. Returns true on success.
typedef ConfigPut =
    Future<bool> Function(String businessType, Map<String, dynamic> json);

/// Delete one business type's config. Returns true on success.
typedef ConfigDelete = Future<bool> Function(String businessType);

/// Syncs [LayoutConfigStore] contents to/from the backend, which persists them
/// in DynamoDB behind API Gateway. Offline-first: the migration computes configs
/// locally, then [pushAll] uploads them; [pullInto] hydrates a local store.
///
/// Kept decoupled via function typedefs so it is unit-testable without a live
/// backend. Use [RemoteLayoutConfigSync.fromApiClient] to wire the real routes.
class RemoteLayoutConfigSync {
  final ConfigGet _get;
  final ConfigPut _put;
  final ConfigDelete _delete;

  const RemoteLayoutConfigSync({
    required ConfigGet getJson,
    required ConfigPut putJson,
    required ConfigDelete deleteJson,
  }) : _get = getJson,
       _put = putJson,
       _delete = deleteJson;

  /// Wire to the real backend endpoints (API Gateway -> Lambda -> DynamoDB).
  factory RemoteLayoutConfigSync.fromApiClient(ApiClient api) {
    const base = '/api/v1/invoice-layout-config';
    return RemoteLayoutConfigSync(
      getJson: (bt) async {
        final r = await api.get('$base/$bt');
        return r.isSuccess ? r.data : null;
      },
      putJson: (bt, json) async {
        final r = await api.put('$base/$bt', body: json);
        return r.isSuccess;
      },
      deleteJson: (bt) async {
        final r = await api.delete('$base/$bt');
        return r.isSuccess;
      },
    );
  }

  /// Push every config in [store] to the backend. Returns the count uploaded.
  /// Throws [RemoteSyncException] on the first failed upload so a partial push
  /// is visible to the caller (who can retry / roll back).
  Future<int> pushAll(LayoutConfigStore store) async {
    var pushed = 0;
    for (final type in store.types) {
      final cfg = store.get(type)!;
      final ok = await _put(type.name, cfg.toJson());
      if (!ok) {
        throw RemoteSyncException('push failed for ${type.name}', pushed);
      }
      pushed++;
    }
    return pushed;
  }

  /// Pull configs for [types] from the backend into [store]. Returns the count
  /// hydrated (absent types are skipped).
  Future<int> pullInto(
    LayoutConfigStore store,
    List<BusinessType> types,
  ) async {
    var pulled = 0;
    for (final type in types) {
      final json = await _get(type.name);
      if (json == null) continue;
      store.put(type, InvoiceLayoutConfig.fromJson(json));
      pulled++;
    }
    return pulled;
  }

  /// Delete configs for [types] from the backend (used by production rollback).
  Future<int> deleteAll(List<BusinessType> types) async {
    var removed = 0;
    for (final type in types) {
      if (await _delete(type.name)) removed++;
    }
    return removed;
  }
}

/// Raised when a remote push fails partway through so callers can react.
class RemoteSyncException implements Exception {
  final String message;
  final int pushedBeforeFailure;
  const RemoteSyncException(this.message, this.pushedBeforeFailure);
  @override
  String toString() =>
      'RemoteSyncException: $message (pushed $pushedBeforeFailure before failure)';
}
