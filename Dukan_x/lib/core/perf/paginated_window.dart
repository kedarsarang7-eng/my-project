// ============================================================================
// D9 PERFORMANCE — PAGINATED WINDOW HELPER
// ============================================================================
// Task 3.2.9 (billing-app-end-to-end-audit): the documented D9 fix pattern
// is `limit + cursor` over every list / report / dashboard / search query.
// This helper is the canonical, reusable bounded-window slicer used by
// repositories that materialize a Hive box (or any in-memory list) for
// rendering. It enforces the contract that callers always observe at most
// `limit` rows in a single page, which is what our D9 reproduction tests
// under `test/d9/` assert against seeded 5k+ row sets.
//
// Preservation 3.1: when `limit` is null we return the original list
// unchanged so already-fast screens keep their timing class.
// ============================================================================

/// Returns a bounded window `[offset, offset + limit)` of [items].
///
/// - When [limit] is null, returns [items] unchanged (legacy contract).
/// - [offset] is clamped to `[0, items.length]` so callers can safely
///   page past the end without raising.
/// - The returned list is always a defensive copy so callers can mutate
///   it without affecting the source.
List<T> paginate<T>(List<T> items, {int? limit, int offset = 0}) {
  if (limit == null) return List<T>.from(items);
  final start = offset.clamp(0, items.length);
  final end = (offset + limit).clamp(0, items.length);
  return items.sublist(start, end);
}

/// Returns true if [pageSize] meaningfully bounds a result against
/// [totalRows]. Used by tests to assert that the paginated window actually
/// reduces work — a `limit` larger than the full set is a no-op and does
/// not satisfy the D9 fix property.
bool isBoundedPage(int totalRows, int pageSize) {
  return pageSize > 0 && pageSize < totalRows;
}
