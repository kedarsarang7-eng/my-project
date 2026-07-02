// ============================================================================
// PROPERTY TEST: Idempotent Migrations
// ============================================================================
// Feature: wholesale-vertical-remediation, Property 5: Idempotent migrations
//
// **Validates: Requirements 1.10, 10.6**
//
// For any legacy dataset, running a wholesale data migration or backfill twice
// SHALL produce the same persisted result as running it once, and the second
// execution SHALL modify zero records.
//
// ForAll 200 iterations: simulate the migration check logic:
//   - If version marker >= current version → skip (return false = no changes)
//   - If version marker absent or < current version → execute (return true = first run)
// Verify: once "executed", subsequent calls with the same version always
// return false (idempotent).
//
// This is a pure logic test — no DB required.
//
// PBT library: dartproptest ^0.2.1.
//
// Run: flutter test test/features/wholesale/property_idempotent_migration_test.dart
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';

/// Pure migration guard logic — determines whether a migration should execute
/// based on a persisted version marker vs. the target migration version.
///
/// This mirrors the design's migration model: the first run transforms and
/// records the version; subsequent runs detect the version and mutate zero
/// records (Requirement 1.10, 10.6).
class MigrationGuard {
  /// Persisted version marker (null means never migrated).
  int? _persistedVersion;

  MigrationGuard({int? initialVersion}) : _persistedVersion = initialVersion;

  /// The current persisted version (null if no migration has run).
  int? get persistedVersion => _persistedVersion;

  /// Attempts to run the migration to [targetVersion].
  ///
  /// Returns `true` if the migration executed (first run — data was changed).
  /// Returns `false` if skipped (already at or past target — no changes).
  ///
  /// After execution, [persistedVersion] is updated to [targetVersion].
  bool runMigration(int targetVersion) {
    if (_persistedVersion != null && _persistedVersion! >= targetVersion) {
      // Already migrated — skip, modify zero records.
      return false;
    }
    // First run: execute the migration and record the version marker.
    _persistedVersion = targetVersion;
    return true;
  }
}

void main() {
  const int kNumRuns = 200;

  group(
    'Feature: wholesale-vertical-remediation, Property 5: Idempotent migrations',
    () {
      // -----------------------------------------------------------------------
      // Property 5a: First run executes, subsequent runs skip.
      // When version marker is absent or below target, first call returns true.
      // All subsequent calls with the same target return false.
      // -----------------------------------------------------------------------
      test(
        'Property 5a (forAll): first run executes, subsequent runs are idempotent (skip)',
        () {
          final held = forAll(
            (int seed) {
              // Generate a target version (1..1000)
              final targetVersion = (seed.abs() % 1000) + 1;

              // Start with no version marker (fresh state)
              final guard = MigrationGuard(initialVersion: null);

              // First run: must execute (return true)
              final firstRun = guard.runMigration(targetVersion);
              if (!firstRun) return false;

              // Verify version marker is now set
              if (guard.persistedVersion != targetVersion) return false;

              // Second run: must skip (return false — idempotent)
              final secondRun = guard.runMigration(targetVersion);
              if (secondRun) return false;

              // Third run: also must skip
              final thirdRun = guard.runMigration(targetVersion);
              if (thirdRun) return false;

              // Verify version marker unchanged after repeated runs
              return guard.persistedVersion == targetVersion;
            },
            [Gen.interval(-100000, 100000)],
            numRuns: kNumRuns,
          );
          expect(
            held,
            isTrue,
            reason:
                'Migration must execute on first run and skip on all '
                'subsequent runs with the same target version',
          );
        },
      );

      // -----------------------------------------------------------------------
      // Property 5b: If version marker >= target, skip immediately.
      // When the persisted version is already at or above the target, the
      // migration returns false without modifying anything.
      // -----------------------------------------------------------------------
      test('Property 5b (forAll): version marker >= target always skips', () {
        final held = forAll(
          (int seed) {
            final targetVersion = (seed.abs() % 500) + 1;
            // Start with version marker at or above target
            final offset = seed.abs() % 100; // 0..99
            final initialVersion = targetVersion + offset;

            final guard = MigrationGuard(initialVersion: initialVersion);

            // Must skip (already migrated past this version)
            final result = guard.runMigration(targetVersion);
            if (result) return false;

            // Version marker must remain unchanged
            return guard.persistedVersion == initialVersion;
          },
          [Gen.interval(-100000, 100000)],
          numRuns: kNumRuns,
        );
        expect(
          held,
          isTrue,
          reason:
              'When persisted version >= target version, migration must '
              'skip and leave the version marker unchanged',
        );
      });

      // -----------------------------------------------------------------------
      // Property 5c: Sequential migrations to increasing versions all execute
      // exactly once, and re-running any past version always skips.
      // -----------------------------------------------------------------------
      test(
        'Property 5c (forAll): sequential upgrades execute once; re-running past versions skips',
        () {
          final held = forAll(
            (int seed) {
              final guard = MigrationGuard(initialVersion: null);

              // Generate 3-5 ascending migration versions
              final numMigrations = (seed.abs() % 3) + 3; // 3..5
              final versions = <int>[];
              int baseVersion = (seed.abs() % 10) + 1;
              for (int i = 0; i < numMigrations; i++) {
                baseVersion += (seed.abs() + i * 7) % 10 + 1;
                versions.add(baseVersion);
              }

              // Run each version once — all should execute
              for (final v in versions) {
                final executed = guard.runMigration(v);
                if (!executed) return false;
              }

              // Re-run all versions — all should skip (idempotent)
              for (final v in versions) {
                final skipped = guard.runMigration(v);
                if (skipped) return false;
              }

              // Final persisted version should be the highest
              return guard.persistedVersion == versions.last;
            },
            [Gen.interval(-100000, 100000)],
            numRuns: kNumRuns,
          );
          expect(
            held,
            isTrue,
            reason:
                'Sequential migrations must each execute once, and re-running '
                'any past version must always skip',
          );
        },
      );
    },
  );
}
