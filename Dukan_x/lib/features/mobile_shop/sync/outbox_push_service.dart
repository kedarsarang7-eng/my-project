/// MobileShop Outbox Push Service (Dart)
///
/// Pushes queued offline mutations to the canonical backend in dependency
/// (topological) order. Reuses Operation_Id and Mutation_Fingerprint on
/// every retry — never regenerates identities. Creates durable conflicts
/// for mismatches and version collisions.
///
/// Requirements: 7.2–7.6, 7.13–7.14
library;

import 'dart:convert';

import '../api/api_result.dart';
import '../api/mobile_shop_api.dart';
import '../auth/tenant_context.dart';
import '../config/model_version_config.dart';
import '../database/mobile_shop_database.dart';
import '../models/sync_models.dart';
import '../repository/mobile_shop_local_repository.dart';
import 'sync_types.dart';

/// Service responsible for pushing queued outbox mutations to the server.
///
/// Key behaviors:
/// - Topologically sorts mutations by their dependency graph
/// - Reuses operationId and fingerprint on retry (never regenerates)
/// - On success: marks as sent
/// - On conflict: creates a durable [MobileConflictEntity]
/// - On network error: leaves as queued for next cycle
class OutboxPushService {
  final MobileShopLocalRepository _repository;
  final MobileShopApi _api;

  /// Maximum mutations to process per push cycle.
  static const int _defaultBatchSize = 50;

  OutboxPushService({
    required MobileShopLocalRepository repository,
    required MobileShopApi api,
  }) : _repository = repository,
       _api = api;

  /// Push all queued mutations in dependency order.
  ///
  /// Returns the count of successfully pushed mutations and conflicts created.
  Future<({int pushedCount, int conflictsCreated})> pushAll(
    TenantContext context, {
    int batchSize = _defaultBatchSize,
  }) async {
    final mutations = await _repository.getNextMutations(context, batchSize);
    if (mutations.isEmpty) {
      return (pushedCount: 0, conflictsCreated: 0);
    }

    // Topologically sort mutations by dependencies
    final sorted = _topologicalSort(mutations);

    int pushedCount = 0;
    int conflictsCreated = 0;

    for (final mutation in sorted) {
      final outcome = await _pushSingleMutation(context, mutation);
      switch (outcome) {
        case PushOutcome.committed:
        case PushOutcome.acceptedPending:
        case PushOutcome.alreadyApplied:
          pushedCount++;
        case PushOutcome.conflict:
        case PushOutcome.rejected:
          conflictsCreated++;
        case PushOutcome.networkError:
          // Stop pushing on network error — remaining stay queued
          return (pushedCount: pushedCount, conflictsCreated: conflictsCreated);
      }
    }

    return (pushedCount: pushedCount, conflictsCreated: conflictsCreated);
  }

  /// Push a single mutation to the server via the batch push API.
  ///
  /// CRITICAL: Operation_Id and Mutation_Fingerprint are reused from the
  /// original queued mutation — never regenerated on retry (Req 7.5).
  Future<PushOutcome> _pushSingleMutation(
    TenantContext context,
    MobileOutboxMutationEntity mutation,
  ) async {
    // Build the push mutation DTO — reusing original identities
    final pushMutation = PushMutation(
      operationId: mutation.operationId,
      mutationFingerprint: mutation.mutationFingerprint,
      dataModelVersion: mutation.dataModelVersion,
      entityType: mutation.entityType,
      payload: mutation.payload,
      expectedVersions: _parseVersions(mutation.baseVersions),
      dependsOn: _parseDependencies(mutation.dependencies),
      queuedAt: mutation.createdAt.toIso8601String(),
    );

    final batch = PushBatchRequest(
      tenantId: context.tenantId,
      dataModelVersion: kModelVersionConfig.currentVersion,
      mutations: [pushMutation],
    );

    final result = await _api.push(batch);

    switch (result) {
      case ApiSuccess<PushBatchResponse>(:final data):
        return _handlePushSuccess(context, mutation, data);
      case ApiError<PushBatchResponse>():
        // Server rejected the request — mark as failed
        await _repository.markMutationFailed(
          context,
          mutation.operationId,
          'Server rejected: ${result.outcome.code}',
        );
        return PushOutcome.rejected;
      case ApiNetworkError<PushBatchResponse>():
        // Network error — leave as queued for next cycle (Req 7.14)
        return PushOutcome.networkError;
    }
  }

  /// Handle a successful push batch response for a single mutation.
  Future<PushOutcome> _handlePushSuccess(
    TenantContext context,
    MobileOutboxMutationEntity mutation,
    PushBatchResponse response,
  ) async {
    if (response.results.isEmpty) {
      return PushOutcome.networkError;
    }

    final mutationResult = response.results.first;

    switch (mutationResult.status) {
      case PushMutationResultStatus.committed:
      case PushMutationResultStatus.acceptedPending:
        // Mark as sent in the outbox
        await _repository.markMutationSent(context, mutation.operationId);
        return mutationResult.status == PushMutationResultStatus.committed
            ? PushOutcome.committed
            : PushOutcome.acceptedPending;

      case PushMutationResultStatus.alreadyApplied:
        // Idempotent replay — already on server, mark sent locally
        await _repository.markMutationSent(context, mutation.operationId);
        return PushOutcome.alreadyApplied;

      case PushMutationResultStatus.conflict:
        // Create a durable conflict record (Req 7.6–7.8)
        await _createConflict(
          context,
          mutation,
          'VERSION_MISMATCH',
          mutationResult,
        );
        await _repository.markMutationFailed(
          context,
          mutation.operationId,
          'Conflict: ${mutationResult.errorCode ?? "version_mismatch"}',
        );
        return PushOutcome.conflict;

      case PushMutationResultStatus.rejected:
        // Rejected permanently — create conflict for visibility
        await _createConflict(
          context,
          mutation,
          mutationResult.errorCode ?? 'REJECTED',
          mutationResult,
        );
        await _repository.markMutationFailed(
          context,
          mutation.operationId,
          'Rejected: ${mutationResult.errorMessage ?? mutationResult.errorCode ?? "unknown"}',
        );
        return PushOutcome.rejected;
    }
  }

  /// Create a durable conflict entity from a failed push.
  ///
  /// Conflicts retain local version, server version, reason, and resolution
  /// state without discarding either version (Req 7.8).
  Future<void> _createConflict(
    TenantContext context,
    MobileOutboxMutationEntity mutation,
    String reason,
    PushMutationResult serverResult,
  ) async {
    final expectedVersions = _parseVersions(mutation.baseVersions);
    final serverVersion =
        serverResult.confirmation?.entityVersions.values.fold<int>(
          0,
          (a, b) => a > b ? a : b,
        ) ??
        0;
    final localVersion = expectedVersions.values.fold<int>(
      0,
      (a, b) => a > b ? a : b,
    );

    // Extract entityId from the payload if available
    final payloadMap = _tryParseJson(mutation.payload);
    final entityId =
        payloadMap?['entityId'] as String? ??
        payloadMap?['id'] as String? ??
        mutation.operationId;

    final now = DateTime.now();
    final conflict = MobileConflictEntity(
      id: 'conflict_${mutation.operationId}_${now.millisecondsSinceEpoch}',
      tenantId: context.tenantId,
      operationId: mutation.operationId,
      entityType: mutation.entityType,
      entityId: entityId,
      localVersion: localVersion,
      serverVersion: serverVersion,
      reason: reason,
      resolutionStatus: ConflictResolutionStatus.unresolved,
      resolutionEvidence: null,
      dataModelVersion: mutation.dataModelVersion,
      createdAt: now,
      resolvedAt: null,
      updatedAt: now,
    );

    await _repository.insertConflict(context, conflict);
  }

  /// Topologically sort mutations by their dependency graph.
  ///
  /// If mutation A lists B in its dependencies, B is pushed first (Req 7.4).
  /// Mutations without dependencies maintain their createdAt order.
  List<MobileOutboxMutationEntity> _topologicalSort(
    List<MobileOutboxMutationEntity> mutations,
  ) {
    if (mutations.length <= 1) return mutations;

    // Build adjacency: operationId → mutation
    final byId = <String, MobileOutboxMutationEntity>{};
    for (final m in mutations) {
      byId[m.operationId] = m;
    }

    // Kahn's algorithm for topological sort
    final inDegree = <String, int>{};
    final graph = <String, List<String>>{};

    for (final m in mutations) {
      inDegree.putIfAbsent(m.operationId, () => 0);
      graph.putIfAbsent(m.operationId, () => []);

      final deps = _parseDependencies(m.dependencies);
      if (deps != null) {
        for (final dep in deps) {
          if (byId.containsKey(dep)) {
            graph.putIfAbsent(dep, () => []);
            graph[dep]!.add(m.operationId);
            inDegree[m.operationId] = (inDegree[m.operationId] ?? 0) + 1;
          }
        }
      }
    }

    // Process nodes with in-degree 0, maintaining createdAt order for ties
    final queue = <String>[];
    for (final m in mutations) {
      if ((inDegree[m.operationId] ?? 0) == 0) {
        queue.add(m.operationId);
      }
    }

    // Sort initial queue by createdAt for deterministic ordering
    queue.sort((a, b) => byId[a]!.createdAt.compareTo(byId[b]!.createdAt));

    final sorted = <MobileOutboxMutationEntity>[];
    final visited = <String>{};

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      if (visited.contains(current)) continue;
      visited.add(current);

      if (byId.containsKey(current)) {
        sorted.add(byId[current]!);
      }

      final neighbors = graph[current] ?? [];
      final readyNeighbors = <String>[];
      for (final neighbor in neighbors) {
        inDegree[neighbor] = (inDegree[neighbor] ?? 1) - 1;
        if (inDegree[neighbor] == 0 && !visited.contains(neighbor)) {
          readyNeighbors.add(neighbor);
        }
      }
      // Sort newly ready nodes by createdAt
      readyNeighbors.sort(
        (a, b) => byId[a]!.createdAt.compareTo(byId[b]!.createdAt),
      );
      queue.addAll(readyNeighbors);
    }

    // Add any remaining mutations not in the dependency graph (cycle protection)
    for (final m in mutations) {
      if (!visited.contains(m.operationId)) {
        sorted.add(m);
      }
    }

    return sorted;
  }

  /// Parse base versions from stored JSON string.
  Map<String, int> _parseVersions(String? json) {
    if (json == null || json.isEmpty) return {};
    try {
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v as int));
    } on Object {
      return {};
    }
  }

  /// Parse dependency operation IDs from stored JSON array.
  List<String>? _parseDependencies(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      final decoded = jsonDecode(json) as List<dynamic>;
      return decoded.cast<String>();
    } on Object {
      return null;
    }
  }

  /// Try to parse a JSON payload into a map.
  Map<String, dynamic>? _tryParseJson(String payload) {
    try {
      return jsonDecode(payload) as Map<String, dynamic>;
    } on Object {
      return null;
    }
  }
}
