// ============================================================================
// PROPERTY TEST: Unresolved / Foreign-Tenant Abort
// ============================================================================
// Feature: wholesale-vertical-remediation, Property 4: Unresolved or foreign tenant aborts safely
//
// **Validates: Requirements 1.7, 10.7**
//
// For any wholesale operation invoked with a missing/unresolvable tenant, or
// any stock movement referencing a Godown location not owned by the active
// tenant, the system SHALL reject the operation, perform no read or write,
// leave persisted data unchanged, and raise the corresponding tenant error.
//
// ForAll 200 iterations: test StockByLocationLogic.applyMovement with a
// location that does NOT belong to the active tenant.
// - When locationBelongsToTenant returns false: must throw ForeignTenantMovementError
// - When it returns true: must NOT throw
//
// PBT library: dartproptest ^0.2.1.
//
// Run: flutter test test/features/wholesale/property_foreign_tenant_test.dart
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';

import 'package:dukanx/features/wholesale/domain/stock_by_location.dart';

void main() {
  const int kNumRuns = 200;

  group(
    'Feature: wholesale-vertical-remediation, Property 4: Unresolved or foreign tenant aborts safely',
    () {
      // -----------------------------------------------------------------------
      // Property 4a: Foreign-tenant location always throws ForeignTenantMovementError.
      // When locationBelongsToTenant returns false, applyMovement must throw
      // and leave the prior state unchanged.
      // -----------------------------------------------------------------------
      test(
        'Property 4a (forAll): foreign-tenant location throws ForeignTenantMovementError',
        () {
          final held = forAll(
            (int seed) {
              final activeTenantId = 'tenant_${seed.abs() % 1000}';
              final foreignLocationId = 'foreign_loc_${(seed.abs() + 7) % 500}';
              final productId = 'product_${seed.abs() % 200}';
              final initialQty = seed.abs() % 5000;
              final delta = ((seed + 31) % 201) - 100; // -100..100

              final prior = StockState(
                quantity: initialQty,
                tenantId: activeTenantId,
                productId: productId,
                locationId: foreignLocationId,
              );

              final movement = StockMovement(
                locationId: foreignLocationId,
                productId: productId,
                quantityDelta: delta,
              );

              // locationBelongsToTenant always returns false → foreign tenant
              bool locationBelongsToTenant(String locId, String tenantId) =>
                  false;

              try {
                StockByLocationLogic.applyMovement(
                  prior: prior,
                  movement: movement,
                  activeTenantId: activeTenantId,
                  locationBelongsToTenant: locationBelongsToTenant,
                );
                // Should NOT reach here — must throw
                return false;
              } on ForeignTenantMovementError catch (e) {
                // Correct: error thrown with correct metadata
                return e.locationId == foreignLocationId &&
                    e.activeTenantId == activeTenantId;
              } catch (_) {
                // Wrong error type
                return false;
              }
            },
            [Gen.interval(-100000, 100000)],
            numRuns: kNumRuns,
          );
          expect(
            held,
            isTrue,
            reason:
                'applyMovement must throw ForeignTenantMovementError when '
                'locationBelongsToTenant returns false',
          );
        },
      );

      // -----------------------------------------------------------------------
      // Property 4b: Valid-tenant location does NOT throw.
      // When locationBelongsToTenant returns true, applyMovement must succeed
      // and return the updated stock.
      // -----------------------------------------------------------------------
      test('Property 4b (forAll): valid-tenant location does NOT throw', () {
        final held = forAll(
          (int seed) {
            final activeTenantId = 'tenant_${seed.abs() % 1000}';
            final locationId = 'loc_${(seed.abs() + 3) % 500}';
            final productId = 'product_${seed.abs() % 200}';
            final initialQty = seed.abs() % 5000;
            final delta = ((seed + 17) % 201) - 100; // -100..100

            final prior = StockState(
              quantity: initialQty,
              tenantId: activeTenantId,
              productId: productId,
              locationId: locationId,
            );

            final movement = StockMovement(
              locationId: locationId,
              productId: productId,
              quantityDelta: delta,
            );

            // locationBelongsToTenant always returns true → valid tenant
            bool locationBelongsToTenant(String locId, String tenantId) => true;

            try {
              final result = StockByLocationLogic.applyMovement(
                prior: prior,
                movement: movement,
                activeTenantId: activeTenantId,
                locationBelongsToTenant: locationBelongsToTenant,
              );
              // Must succeed and produce correct updated quantity
              return result.quantity == initialQty + delta &&
                  result.tenantId == activeTenantId &&
                  result.locationId == locationId &&
                  result.productId == productId;
            } catch (_) {
              // Should NOT throw for valid tenant
              return false;
            }
          },
          [Gen.interval(-100000, 100000)],
          numRuns: kNumRuns,
        );
        expect(
          held,
          isTrue,
          reason:
              'applyMovement must NOT throw when locationBelongsToTenant '
              'returns true, and must return the correctly updated state',
        );
      });

      // -----------------------------------------------------------------------
      // Property 4c: Foreign-tenant rejection leaves prior state unchanged.
      // After a ForeignTenantMovementError, no mutation has occurred — verify
      // the prior state values remain accessible and unmodified.
      // -----------------------------------------------------------------------
      test(
        'Property 4c (forAll): foreign-tenant rejection preserves prior state',
        () {
          final held = forAll(
            (int seed) {
              final activeTenantId = 'tenant_${seed.abs() % 1000}';
              final foreignLocationId =
                  'foreign_loc_${(seed.abs() + 11) % 500}';
              final productId = 'product_${seed.abs() % 200}';
              final initialQty = seed.abs() % 5000;
              final delta = ((seed + 53) % 201) - 100;

              final prior = StockState(
                quantity: initialQty,
                tenantId: activeTenantId,
                productId: productId,
                locationId: foreignLocationId,
              );

              final movement = StockMovement(
                locationId: foreignLocationId,
                productId: productId,
                quantityDelta: delta,
              );

              bool locationBelongsToTenant(String locId, String tenantId) =>
                  false;

              try {
                StockByLocationLogic.applyMovement(
                  prior: prior,
                  movement: movement,
                  activeTenantId: activeTenantId,
                  locationBelongsToTenant: locationBelongsToTenant,
                );
                return false; // Should have thrown
              } on ForeignTenantMovementError {
                // After the error, prior state is unchanged (immutable value)
                return prior.quantity == initialQty &&
                    prior.tenantId == activeTenantId &&
                    prior.productId == productId &&
                    prior.locationId == foreignLocationId;
              } catch (_) {
                return false;
              }
            },
            [Gen.interval(-100000, 100000)],
            numRuns: kNumRuns,
          );
          expect(
            held,
            isTrue,
            reason:
                'After a ForeignTenantMovementError, the prior state must '
                'remain completely unchanged',
          );
        },
      );
    },
  );
}
