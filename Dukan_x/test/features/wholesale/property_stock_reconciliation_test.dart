// ============================================================================
// PROPERTY TEST: Stock-by-Location Reconciliation
// ============================================================================
// Feature: wholesale-vertical-remediation, Property 16: Stock-by-location reconciliation
//
// **Validates: Requirements 10.4**
//
// For any sequence of stock movements across godown locations owned by the
// tenant, each movement SHALL be attributed to exactly one location, and the
// sum of per-location quantities for a product SHALL equal the sum of all
// movement deltas (starting from 0).
//
// ForAll 200 iterations: generate random stock movements, apply via
// StockByLocationLogic.applyMovement, and verify:
//   - After any sequence of movements to a single product across multiple
//     locations, the sum of per-location quantities equals the sum of all
//     movement deltas.
//
// PBT library: dartproptest ^0.2.1.
//
// Run: flutter test test/features/wholesale/property_stock_reconciliation_test.dart
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';

import 'package:dukanx/features/wholesale/domain/stock_by_location.dart';

void main() {
  const int kNumRuns = 200;

  // All test locations belong to the active tenant.
  bool locationBelongsToTenant(String locationId, String tenantId) => true;

  group(
    'Feature: wholesale-vertical-remediation, Property 16: Stock-by-location reconciliation',
    () {
      // -----------------------------------------------------------------------
      // Property 16a: Sum of per-location quantities equals sum of all deltas.
      // Apply multiple movements to a single product across 2-4 locations;
      // verify that the total stock (sum of all location quantities) equals the
      // sum of all movement deltas.
      // -----------------------------------------------------------------------
      test(
        'Property 16a (forAll): per-location sum equals sum of all movement deltas',
        () {
          final held = forAll(
            (int seed) {
              const tenantId = 'tenant_test';
              const productId = 'product_001';
              // Generate 2-4 location ids
              final numLocations = (seed.abs() % 3) + 2; // 2..4
              final locationIds = List.generate(numLocations, (i) => 'loc_$i');

              // Generate 5-15 movements across these locations
              final numMovements = (seed.abs() % 11) + 5; // 5..15

              // Track per-location quantities (starting from 0)
              final perLocationQty = <String, int>{};
              for (final loc in locationIds) {
                perLocationQty[loc] = 0;
              }

              int totalDeltas = 0;

              for (int i = 0; i < numMovements; i++) {
                // Pick a location deterministically
                final locIndex = (seed.abs() + i * 7) % numLocations;
                final locationId = locationIds[locIndex];

                // Generate a delta in [-100, 100]
                final delta = ((seed + i * 13) % 201) - 100;

                final movement = StockMovement(
                  locationId: locationId,
                  productId: productId,
                  quantityDelta: delta,
                );

                // Build prior state
                final prior = StockState(
                  quantity: perLocationQty[locationId]!,
                  tenantId: tenantId,
                  productId: productId,
                  locationId: locationId,
                );

                // Apply movement
                final result = StockByLocationLogic.applyMovement(
                  prior: prior,
                  movement: movement,
                  activeTenantId: tenantId,
                  locationBelongsToTenant: locationBelongsToTenant,
                );

                // Update our tracking
                perLocationQty[locationId] = result.quantity;
                totalDeltas += delta;
              }

              // Verify: sum of per-location quantities == sum of all deltas
              final sumOfLocations = perLocationQty.values.fold(
                0,
                (a, b) => a + b,
              );
              return sumOfLocations == totalDeltas;
            },
            [Gen.interval(-100000, 100000)],
            numRuns: kNumRuns,
          );
          expect(
            held,
            isTrue,
            reason:
                'Sum of per-location quantities must equal sum of all movement deltas',
          );
        },
      );

      // -----------------------------------------------------------------------
      // Property 16b: Each movement is attributed to exactly one location.
      // After applying a movement, only the targeted location's quantity changes.
      // -----------------------------------------------------------------------
      test(
        'Property 16b (forAll): movement affects only the targeted location',
        () {
          final held = forAll(
            (int seed) {
              const tenantId = 'tenant_test';
              const productId = 'product_001';
              final locationIds = ['loc_A', 'loc_B', 'loc_C'];

              // Initialize all locations with some starting quantity
              final perLocationQty = <String, int>{
                'loc_A': (seed.abs() % 100),
                'loc_B': (seed.abs() % 200) + 50,
                'loc_C': (seed.abs() % 150) + 25,
              };

              // Pick a target location
              final targetIdx = seed.abs() % 3;
              final targetLoc = locationIds[targetIdx];
              final delta = ((seed + 42) % 201) - 100; // -100..100

              // Snapshot before
              final beforeQty = Map<String, int>.from(perLocationQty);

              // Apply movement to target location
              final prior = StockState(
                quantity: perLocationQty[targetLoc]!,
                tenantId: tenantId,
                productId: productId,
                locationId: targetLoc,
              );

              final movement = StockMovement(
                locationId: targetLoc,
                productId: productId,
                quantityDelta: delta,
              );

              final result = StockByLocationLogic.applyMovement(
                prior: prior,
                movement: movement,
                activeTenantId: tenantId,
                locationBelongsToTenant: locationBelongsToTenant,
              );

              perLocationQty[targetLoc] = result.quantity;

              // Verify: target location changed correctly
              if (perLocationQty[targetLoc] != beforeQty[targetLoc]! + delta) {
                return false;
              }

              // Verify: other locations unchanged
              for (final loc in locationIds) {
                if (loc != targetLoc) {
                  if (perLocationQty[loc] != beforeQty[loc]) return false;
                }
              }

              return true;
            },
            [Gen.interval(-100000, 100000)],
            numRuns: kNumRuns,
          );
          expect(
            held,
            isTrue,
            reason:
                'A movement must affect only the targeted location, leaving others unchanged',
          );
        },
      );

      // -----------------------------------------------------------------------
      // Property 16c: Applying a movement with delta 0 does not change quantity.
      // -----------------------------------------------------------------------
      test(
        'Property 16c (forAll): zero-delta movement leaves quantity unchanged',
        () {
          final held = forAll(
            (int seed) {
              const tenantId = 'tenant_test';
              const productId = 'product_001';
              const locationId = 'loc_warehouse';

              final initialQty = seed.abs() % 10000;

              final prior = StockState(
                quantity: initialQty,
                tenantId: tenantId,
                productId: productId,
                locationId: locationId,
              );

              final movement = StockMovement(
                locationId: locationId,
                productId: productId,
                quantityDelta: 0,
              );

              final result = StockByLocationLogic.applyMovement(
                prior: prior,
                movement: movement,
                activeTenantId: tenantId,
                locationBelongsToTenant: locationBelongsToTenant,
              );

              return result.quantity == initialQty;
            },
            [Gen.interval(-100000, 100000)],
            numRuns: kNumRuns,
          );
          expect(
            held,
            isTrue,
            reason: 'Zero-delta movement must not change the quantity',
          );
        },
      );
    },
  );
}
