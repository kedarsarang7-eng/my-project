import 'package:uuid/uuid.dart';

/// Shared helper that generates Record IDs (RIDs) for all new entities across
/// business verticals (Jewellery, Mandi, etc.).
///
/// Format: `{tenantId}-{timestamp_ms}-{uuid_v4_short}`
///
/// - **tenantId**: The owning tenant (userId / businessId) from SessionManager.
/// - **timestamp_ms**: Milliseconds since epoch at generation time.
/// - **uuid_v4_short**: First 8 characters of a UUID v4 (without dashes),
///   providing sufficient uniqueness when combined with tenant + timestamp.
///
/// This pattern ensures globally unique, sortable, tenant-scoped identifiers
/// across all entities on touched paths.
class RidGenerator {
  static const _uuid = Uuid();

  /// Generate a new RID for the given [tenantId].
  ///
  /// Optionally accepts [now] for deterministic testing; defaults to
  /// `DateTime.now()`.
  static String next(String tenantId, {DateTime? now}) {
    final timestamp = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final uuidShort = _uuid.v4().replaceAll('-', '').substring(0, 8);
    return '$tenantId-$timestamp-$uuidShort';
  }

  /// Alias for [next] — kept for backward compatibility with existing callers.
  static String generate(String tenantId, {DateTime? now}) =>
      next(tenantId, now: now);
}
