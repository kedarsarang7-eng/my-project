// ============================================================================
// PROPERTY TEST: Tiered / Rate-List Price Resolution with Fallback
// ============================================================================
// Feature: wholesale-vertical-remediation, Property 17: Tiered / rate-list price resolution with fallback
//
// **Validates: Requirements 11.4, 11.6**
//
// For any bill line for a party and quantity, when an applicable party rate
// list or quantity slab exists the resolved unit price SHALL equal the
// configured paise rate of the quantity-matching slab; when none applies the
// price SHALL fall back to the generic product price with no fabricated tier.
//
// ForAll 200 iterations: generate random RateContext (party-specific slabs,
// generic slabs, no slabs) + qty + genericPaise.
// - When a party-specific slab matches qty: resolver returns that slab's unitPaise
// - When no party slab matches but a generic slab does: returns generic slab's unitPaise
// - When nothing matches: returns genericPaise (fallback)
// - Verify netLinePaise(resolvedUnitPaise, qty, discountPaise) ==
//     resolvedUnitPaise * qty - discountPaise
//
// PBT library: dartproptest ^0.2.1.
//
// Run: flutter test test/features/wholesale/property_price_resolution_test.dart
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';

import 'package:dukanx/features/wholesale/domain/price_resolver.dart';
import 'package:dukanx/features/wholesale/domain/rate_list.dart';

void main() {
  const int kNumRuns = 200;
  const resolver = PriceResolver();

  group(
    'Feature: wholesale-vertical-remediation, Property 17: Tiered / rate-list price resolution with fallback',
    () {
      // -----------------------------------------------------------------------
      // Property 17a: Party-specific slab match returns that slab's unitPaise.
      // Generate a party rate list with a slab that covers the qty, then
      // verify the resolver returns that slab's unitPaise.
      // -----------------------------------------------------------------------
      test(
        'Property 17a (forAll): party-specific slab match returns slab unitPaise',
        () {
          final held = forAll(
            (int seed) {
              // Generate a quantity in [1..500]
              final qty = (seed.abs() % 500) + 1;
              // Generate a slab that covers this qty: minQty <= qty <= maxQty
              final minQty = (seed.abs() % qty) + 1; // 1..qty
              final maxQty = qty + (seed.abs() % 100); // qty..qty+99
              final slabUnitPaise = (seed.abs() % 10000) + 100; // 100..10099
              final genericPaise = (seed.abs() % 5000) + 50; // different

              final partySlab = PricingSlab(
                minQty: minQty,
                maxQty: maxQty,
                unitPaise: slabUnitPaise,
              );

              final partyRateList = RateList(
                id: 'rl-party-${seed.abs()}',
                tenantId: 'tenant_test',
                partyId: 'party_001',
                productId: 'product_001',
                slabs: [partySlab],
                createdAt: DateTime(2025, 1, 1),
              );

              final ctx = RateContext(
                partyRateLists: [partyRateList],
                genericRateLists: [],
              );

              final resolved = resolver.resolveUnitPaise(
                ctx: ctx,
                qty: qty,
                genericPaise: genericPaise,
              );

              return resolved == slabUnitPaise;
            },
            [Gen.interval(-100000, 100000)],
            numRuns: kNumRuns,
          );
          expect(
            held,
            isTrue,
            reason:
                'When a party-specific slab matches the qty, the resolver '
                'must return that slab\'s unitPaise',
          );
        },
      );

      // -----------------------------------------------------------------------
      // Property 17b: No party slab match, generic slab match returns generic
      // slab's unitPaise.
      // -----------------------------------------------------------------------
      test(
        'Property 17b (forAll): generic slab fallback returns generic slab unitPaise',
        () {
          final held = forAll(
            (int seed) {
              // Generate a quantity in [1..500]
              final qty = (seed.abs() % 500) + 1;

              // Party slab does NOT match (minQty > qty)
              final partySlabMin = qty + 1 + (seed.abs() % 100);
              final partySlabMax = partySlabMin + 50;
              final partySlabPaise = (seed.abs() % 5000) + 200;

              final partySlab = PricingSlab(
                minQty: partySlabMin,
                maxQty: partySlabMax,
                unitPaise: partySlabPaise,
              );

              // Generic slab DOES match (minQty <= qty)
              final genericSlabMin = (seed.abs() % qty) + 1;
              final genericSlabMax = qty + (seed.abs() % 100);
              final genericSlabPaise = (seed.abs() % 8000) + 100;

              final genericSlab = PricingSlab(
                minQty: genericSlabMin,
                maxQty: genericSlabMax,
                unitPaise: genericSlabPaise,
              );

              final genericPaise = (seed.abs() % 3000) + 50;

              final partyRateList = RateList(
                id: 'rl-party-${seed.abs()}',
                tenantId: 'tenant_test',
                partyId: 'party_001',
                productId: 'product_001',
                slabs: [partySlab],
                createdAt: DateTime(2025, 1, 1),
              );

              final genericRateList = RateList(
                id: 'rl-generic-${seed.abs()}',
                tenantId: 'tenant_test',
                partyId: null,
                productId: 'product_001',
                slabs: [genericSlab],
                createdAt: DateTime(2025, 1, 1),
              );

              final ctx = RateContext(
                partyRateLists: [partyRateList],
                genericRateLists: [genericRateList],
              );

              final resolved = resolver.resolveUnitPaise(
                ctx: ctx,
                qty: qty,
                genericPaise: genericPaise,
              );

              return resolved == genericSlabPaise;
            },
            [Gen.interval(-100000, 100000)],
            numRuns: kNumRuns,
          );
          expect(
            held,
            isTrue,
            reason:
                'When no party slab matches but a generic slab does, the '
                'resolver must return the generic slab\'s unitPaise',
          );
        },
      );

      // -----------------------------------------------------------------------
      // Property 17c: No slab matches at all → returns genericPaise (fallback).
      // -----------------------------------------------------------------------
      test(
        'Property 17c (forAll): no slab matches returns genericPaise fallback',
        () {
          final held = forAll(
            (int seed) {
              // Generate a quantity in [1..500]
              final qty = (seed.abs() % 500) + 1;

              // All slabs have minQty > qty (no match)
              final nonMatchMin = qty + 1 + (seed.abs() % 100);
              final nonMatchMax = nonMatchMin + 50;

              final partySlab = PricingSlab(
                minQty: nonMatchMin,
                maxQty: nonMatchMax,
                unitPaise: (seed.abs() % 5000) + 200,
              );

              final genericSlab = PricingSlab(
                minQty: nonMatchMin + 10,
                maxQty: nonMatchMax + 10,
                unitPaise: (seed.abs() % 8000) + 100,
              );

              final genericPaise = (seed.abs() % 10000) + 50;

              final partyRateList = RateList(
                id: 'rl-party-${seed.abs()}',
                tenantId: 'tenant_test',
                partyId: 'party_001',
                productId: 'product_001',
                slabs: [partySlab],
                createdAt: DateTime(2025, 1, 1),
              );

              final genericRateList = RateList(
                id: 'rl-generic-${seed.abs()}',
                tenantId: 'tenant_test',
                partyId: null,
                productId: 'product_001',
                slabs: [genericSlab],
                createdAt: DateTime(2025, 1, 1),
              );

              final ctx = RateContext(
                partyRateLists: [partyRateList],
                genericRateLists: [genericRateList],
              );

              final resolved = resolver.resolveUnitPaise(
                ctx: ctx,
                qty: qty,
                genericPaise: genericPaise,
              );

              return resolved == genericPaise;
            },
            [Gen.interval(-100000, 100000)],
            numRuns: kNumRuns,
          );
          expect(
            held,
            isTrue,
            reason:
                'When no slab matches, the resolver must fall back to '
                'genericPaise — never fabricate a tier',
          );
        },
      );

      // -----------------------------------------------------------------------
      // Property 17d: netLinePaise formula is correct.
      // Verify netLinePaise(resolvedUnitPaise, qty, discountPaise) ==
      //   resolvedUnitPaise * qty - discountPaise
      // -----------------------------------------------------------------------
      test(
        'Property 17d (forAll): netLinePaise == resolvedUnitPaise * qty - discountPaise',
        () {
          final held = forAll(
            (int seed) {
              final resolvedUnitPaise = (seed.abs() % 10000) + 1; // 1..10000
              final qty = (seed.abs() % 500) + 1; // 1..500
              final discountPaise = seed.abs() % 5000; // 0..4999

              final result = resolver.netLinePaise(
                resolvedUnitPaise: resolvedUnitPaise,
                qty: qty,
                discountPaise: discountPaise,
              );

              final expected = (resolvedUnitPaise * qty) - discountPaise;
              return result == expected;
            },
            [Gen.interval(-100000, 100000)],
            numRuns: kNumRuns,
          );
          expect(
            held,
            isTrue,
            reason:
                'netLinePaise must equal resolvedUnitPaise * qty - discountPaise '
                '(deterministic integer paise)',
          );
        },
      );

      // -----------------------------------------------------------------------
      // Property 17e: Empty rate lists always fall back to genericPaise.
      // -----------------------------------------------------------------------
      test(
        'Property 17e (forAll): empty rate context always returns genericPaise',
        () {
          final held = forAll(
            (int seed) {
              final qty = (seed.abs() % 1000) + 1;
              final genericPaise = (seed.abs() % 50000) + 1;

              const ctx = RateContext(partyRateLists: [], genericRateLists: []);

              final resolved = resolver.resolveUnitPaise(
                ctx: ctx,
                qty: qty,
                genericPaise: genericPaise,
              );

              return resolved == genericPaise;
            },
            [Gen.interval(-100000, 100000)],
            numRuns: kNumRuns,
          );
          expect(
            held,
            isTrue,
            reason:
                'With empty rate lists, resolver must always return genericPaise',
          );
        },
      );
    },
  );
}
