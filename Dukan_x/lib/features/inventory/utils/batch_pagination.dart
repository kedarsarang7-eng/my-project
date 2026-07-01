// ============================================================================
// PHARMACY VERTICAL REMEDIATION — Batch tracking pagination arithmetic
// Requirement 20.1: BatchTrackingScreen retrieves records in paginated
// segments of a fixed page size between 20 and 50 records per segment rather
// than loading all records in a single request.
// ============================================================================
//
// `BatchTrackingScreen` reveals a large batch catalog in fixed-size segments
// (a growing window) instead of one render pass. The segment arithmetic used
// by the screen is captured here as pure, side-effect-free functions so it can
// be verified independently of the widget tree (the screen wires its private
// `_pageSize`, `_visibleCount` and `_hasMore` logic to these helpers, keeping
// behaviour identical).
// ============================================================================

/// Fixed page size for batch-tracking segments.
///
/// MUST remain within the inclusive range [20, 50] per Requirement 20.1 so the
/// catalog loads in bounded segments. This is asserted by the property test.
const int kBatchTrackingPageSize = 30;

/// A single fixed-size page segment of the batch catalog, described as a
/// half-open record range `[offset, offset + limit)`.
class BatchSegment {
  /// Inclusive start index of this segment within the full record list.
  final int offset;

  /// Number of records contained in this segment. Always `<= pageSize`.
  final int limit;

  const BatchSegment(this.offset, this.limit);

  /// Exclusive end index of this segment within the full record list.
  int get end => offset + limit;

  @override
  String toString() => 'BatchSegment(offset: $offset, limit: $limit)';
}

/// Number of fixed-size segments required to reveal [totalCount] records,
/// i.e. `ceil(totalCount / pageSize)`.
///
/// Returns 0 for a non-positive [totalCount] (nothing to page).
int batchSegmentCount(int totalCount, {int pageSize = kBatchTrackingPageSize}) {
  assert(pageSize > 0, 'pageSize must be positive');
  if (totalCount <= 0) return 0;
  return (totalCount + pageSize - 1) ~/ pageSize; // ceil(N / P)
}

/// The number of records revealed after [segmentsLoaded] segments have been
/// loaded. Mirrors the screen's `_visibleCount`: it starts at one page and
/// grows by one page per load, clamped to [totalCount].
int batchVisibleCount(
  int totalCount,
  int segmentsLoaded, {
  int pageSize = kBatchTrackingPageSize,
}) {
  assert(pageSize > 0, 'pageSize must be positive');
  final safeTotal = totalCount < 0 ? 0 : totalCount;
  final revealed = (segmentsLoaded < 0 ? 0 : segmentsLoaded) * pageSize;
  return revealed.clamp(0, safeTotal);
}

/// Whether more records remain beyond a revealed window of [revealedCount]
/// records. Mirrors the screen's `_hasMore` getter.
bool batchHasMore(int totalCount, int revealedCount) =>
    revealedCount < totalCount;

/// Builds the ordered list of fixed-size segments that partition [totalCount]
/// records into pages of [pageSize] (the final segment may be smaller).
///
/// The returned segments are contiguous and non-overlapping: segment `k`
/// covers `[k * pageSize, min((k + 1) * pageSize, totalCount))`.
List<BatchSegment> batchSegments(
  int totalCount, {
  int pageSize = kBatchTrackingPageSize,
}) {
  assert(pageSize > 0, 'pageSize must be positive');
  final segments = <BatchSegment>[];
  if (totalCount <= 0) return segments;
  for (var offset = 0; offset < totalCount; offset += pageSize) {
    final remaining = totalCount - offset;
    final limit = remaining < pageSize ? remaining : pageSize;
    segments.add(BatchSegment(offset, limit));
  }
  return segments;
}
