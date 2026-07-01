/// Conflict data model
class SyncConflict {
  final String documentId;
  final String collection;
  final String userId;
  final Map<String, dynamic> localData;
  final Map<String, dynamic> serverData;
  final DateTime localModifiedAt;
  final DateTime serverModifiedAt;
  final int localVersion;
  final String? operationId;
  final int serverVersion;

  const SyncConflict({
    this.operationId,
    required this.documentId,
    required this.collection,
    this.userId = 'unknown',
    required this.localData,
    required this.serverData,
    required this.localModifiedAt,
    required this.serverModifiedAt,
    required this.localVersion,
    required this.serverVersion,
  });

  /// Get differing fields
  List<String> get differingFields {
    final fields = <String>{};
    for (final key in localData.keys) {
      if (!serverData.containsKey(key) ||
          localData[key].toString() != serverData[key].toString()) {
        if (!key.startsWith('_')) {
          // Skip metadata fields
          fields.add(key);
        }
      }
    }
    for (final key in serverData.keys) {
      if (!localData.containsKey(key) && !key.startsWith('_')) {
        fields.add(key);
      }
    }
    return fields.toList();
  }
}

/// Resolution choice
enum ConflictChoice { keepLocal, keepServer, merge }

/// Conflict Resolution Result from UI
class ConflictResolutionResult {
  final ConflictChoice choice;
  final Map<String, dynamic>? mergedData;

  ConflictResolutionResult(this.choice, [this.mergedData]);
}

/// Exception thrown when a sync conflict is detected
class SyncConflictException implements Exception {
  final SyncConflict conflict;
  SyncConflictException(this.conflict);

  @override
  String toString() => 'SyncConflictException: ${conflict.documentId}';
}
