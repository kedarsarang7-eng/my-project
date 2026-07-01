// D9 PERFORMANCE — paginated window reproduction tests (task 3.2.9).
//
// Validates the documented D9 fix pattern from `design.md`:
//
//   "paginate (`limit + cursor`); index queries; offload heavy work
//    (`compute` / isolates); collapse N+1 reads into batch queries; verify
//    against documented budgets (1s first frame, 60fps scroll)."
//
// Seed scale (per `tasks.md` task 1 D9 sweep): >=5k products, >=10k
// invoices, >=2k students. We exercise the canonical helper at
// `lib/core/perf/paginated_window.dart` because:
//   1. The Hive-backed repos under `features/*/data/repositories/`
//      delegate to the same helper.
//   2. The static walker in `test/audit/bug_condition_audit_test.dart`
//      D9 sub-test recognises `limit:` / `cursor` markers — using the
//      helper keeps every callsite compliant.
// Below-budget execution at 5k / 10k row scale demonstrates the page is
// bounded and not materializing the full set on every read.

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/core/perf/paginated_window.dart';

/// Documented first-frame budget per clause 2.14: 1s on mid-tier devices.
/// We use a much tighter 100ms ceiling for the in-memory page slice
/// because the 1s budget covers full screen render including I/O — the
/// pure data-window operation must be a small fraction of that.
const _firstFrameBudget = Duration(milliseconds: 100);

void main() {
  group('D9 — paginated window contract', () {
    test('returns the full list unchanged when limit is null '
        '(preservation 3.1)', () {
      final items = List.generate(5000, (i) => i);
      final out = paginate<int>(items, limit: null);
      expect(out, equals(items));
      // Defensive copy: mutating the returned list does not mutate input.
      out.removeLast();
      expect(items.length, 5000);
    });

    test('bounds the page to <= limit rows over a 5k-product seed', () {
      final products = List.generate(5000, (i) => 'product-$i');
      final page = paginate<String>(products, limit: 50, offset: 0);
      expect(page.length, 50);
      expect(page.first, 'product-0');
      expect(page.last, 'product-49');
    });

    test('honours offset to walk a 10k-invoice seed without reloading', () {
      final invoices = List.generate(10000, (i) => i);
      final pages = <List<int>>[];
      const pageSize = 200;
      for (var offset = 0; offset < invoices.length; offset += pageSize) {
        pages.add(paginate<int>(invoices, limit: pageSize, offset: offset));
      }
      // Every page is exactly `pageSize` rows (10000 / 200 = 50 pages).
      expect(pages.length, 50);
      expect(pages.every((p) => p.length == pageSize), isTrue);
      // The pages reconstruct the input in order.
      final reassembled = pages.expand((p) => p).toList();
      expect(reassembled, equals(invoices));
    });

    test('clamps offset past the end to an empty page', () {
      final students = List.generate(2000, (i) => i);
      final page = paginate<int>(students, limit: 100, offset: 5000);
      expect(page, isEmpty);
    });

    test('first paginated read of a 5k row set finishes within budget '
        '(clause 2.14, 1s ceiling)', () {
      final products = List.generate(5000, (i) => i);
      final sw = Stopwatch()..start();
      final page = paginate<int>(products, limit: 50, offset: 0);
      sw.stop();
      expect(page.length, 50);
      expect(
        sw.elapsed,
        lessThan(_firstFrameBudget),
        reason:
            'first-page slice must complete in <100ms to leave headroom '
            'for the rest of the 1s first-frame budget (clause 2.14).',
      );
    });

    test(
      'first paginated read of a 10k invoice set finishes within budget',
      () {
        final invoices = List.generate(10000, (i) => i);
        final sw = Stopwatch()..start();
        final page = paginate<int>(invoices, limit: 100, offset: 0);
        sw.stop();
        expect(page.length, 100);
        expect(sw.elapsed, lessThan(_firstFrameBudget));
      },
    );

    test('isBoundedPage flags pages that genuinely reduce work', () {
      // pageSize > total: not actually bounded.
      expect(isBoundedPage(50, 100), isFalse);
      // pageSize == total: not actually bounded.
      expect(isBoundedPage(100, 100), isFalse);
      // pageSize == 0: degenerate.
      expect(isBoundedPage(100, 0), isFalse);
      // pageSize bounds work: bounded.
      expect(isBoundedPage(5000, 50), isTrue);
      expect(isBoundedPage(10000, 200), isTrue);
    });
  });
}
