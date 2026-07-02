import 'package:uuid/uuid.dart';

/// Generates tenant-scoped, time-ordered identifiers for wholesale entities.
///
/// RID format: `{tenantId}-{timestamp_ms}-{uuid_v4_short}`
///
/// - `tenantId`: the active tenant's identifier (must be non-empty)
/// - `timestamp_ms`: Unix epoch milliseconds at generation time
/// - `uuid_v4_short`: first 8 characters of a UUID v4 (collision-resistant suffix)
///
/// This pattern ensures IDs are globally unique, tenant-attributed, and
/// roughly time-ordered for efficient range queries.
abstract class RidGenerator {
  /// Generates a new RID for the given [tenantId].
  ///
  /// Throws [ArgumentError] if [tenantId] is empty.
  String generate(String tenantId);
}

/// Default concrete implementation of [RidGenerator].
///
/// Uses [Uuid] for the v4 suffix and [DateTime.now().millisecondsSinceEpoch]
/// for the timestamp component. Both can be overridden via constructor
/// injection for deterministic testing.
class DefaultRidGenerator implements RidGenerator {
  final Uuid _uuid;
  final int Function() _clock;

  /// Creates a [DefaultRidGenerator].
  ///
  /// [uuid] defaults to a standard [Uuid] instance.
  /// [clock] defaults to [DateTime.now().millisecondsSinceEpoch]; inject a
  /// fixed function for deterministic tests.
  DefaultRidGenerator({Uuid? uuid, int Function()? clock})
    : _uuid = uuid ?? const Uuid(),
      _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch);

  @override
  String generate(String tenantId) {
    if (tenantId.isEmpty) {
      throw ArgumentError.value(
        tenantId,
        'tenantId',
        'tenantId must be non-empty to generate a valid RID',
      );
    }

    final timestampMs = _clock();
    // First 8 characters of a v4 UUID (without hyphens) as a compact suffix.
    final uuidFull = _uuid.v4();
    final uuidShort = uuidFull.replaceAll('-', '').substring(0, 8);

    return '$tenantId-$timestampMs-$uuidShort';
  }
}
