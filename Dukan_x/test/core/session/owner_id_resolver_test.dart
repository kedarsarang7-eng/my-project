import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/core/session/owner_id_resolver.dart';

/// Unit tests for the shared, fail-safe owner-id resolver (Phase 1 / task 4.2).
///
/// These cover the pure fail-safe chokepoint [requireOwnerId], which guarantees
/// no `?? 'SYSTEM'` style fallback can ever be produced. The session-backed
/// [resolveOwnerId] simply delegates to this same check, so the contract is
/// fully exercised here without needing a database or GetIt.
void main() {
  group('requireOwnerId — fail-safe owner attribution', () {
    test('returns the id unchanged for a valid non-blank owner id', () {
      expect(requireOwnerId('usr_A'), 'usr_A');
      expect(requireOwnerId('clinic-123-abc'), 'clinic-123-abc');
    });

    test('throws OwnerIdMissingException when owner id is null', () {
      expect(
        () => requireOwnerId(null),
        throwsA(isA<OwnerIdMissingException>()),
      );
    });

    test('throws OwnerIdMissingException when owner id is empty', () {
      expect(() => requireOwnerId(''), throwsA(isA<OwnerIdMissingException>()));
    });

    test('throws OwnerIdMissingException when owner id is whitespace only', () {
      expect(
        () => requireOwnerId('   '),
        throwsA(isA<OwnerIdMissingException>()),
      );
    });

    test('NEVER substitutes a SYSTEM placeholder for a missing owner id', () {
      // The whole point of the fail-safe: a blocked write, not a SYSTEM bucket.
      try {
        requireOwnerId(null, operation: 'create patient');
        fail('expected OwnerIdMissingException to be thrown');
      } on OwnerIdMissingException catch (e) {
        expect(e.toString(), isNot(contains('SYSTEM bucket')));
        expect(e.operation, 'create patient');
        // Message documents that the write was blocked rather than defaulted.
        expect(e.toString().toLowerCase(), contains('blocked'));
      }
    });

    test('exception carries the operation label for diagnostics', () {
      const ex = OwnerIdMissingException('enqueue appointment sync');
      expect(ex.operation, 'enqueue appointment sync');
      expect(ex.toString(), contains('enqueue appointment sync'));
    });
  });
}
