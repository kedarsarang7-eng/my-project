/// A physical warehouse / godown location belonging to a tenant.
///
/// Design model (Phase 7):
/// ```
/// Warehouse / Godown (new)
///   id       : RID
///   tenantId : string
///   name     : string
///   createdAt: DateTime
/// ```
///
/// All warehouses are tenant-scoped. The [id] follows the RID pattern
/// `{tenantId}-{timestamp_ms}-{uuid_v4_short}`.
class Warehouse {
  /// RID-format identifier: `{tenantId}-{timestamp_ms}-{uuid_v4_short}`.
  final String id;

  /// The owning tenant — scopes all queries and writes.
  final String tenantId;

  /// Human-readable warehouse name (e.g. "Main Godown", "Cold Storage").
  /// Must not be empty.
  final String name;

  /// Timestamp when this warehouse record was created.
  final DateTime createdAt;

  const Warehouse({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.createdAt,
  });

  /// Creates a copy with the given fields replaced.
  Warehouse copyWith({
    String? id,
    String? tenantId,
    String? name,
    DateTime? createdAt,
  }) {
    return Warehouse(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Warehouse &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          tenantId == other.tenantId &&
          name == other.name;

  @override
  int get hashCode => Object.hash(id, tenantId, name);

  @override
  String toString() =>
      'Warehouse(id: $id, tenant: $tenantId, name: $name, '
      'createdAt: $createdAt)';
}
