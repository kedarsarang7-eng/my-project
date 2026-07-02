// ============================================================================
// PROPERTY TEST: Entity Persistence Round-Trip (Data-Class Contract)
// ============================================================================
// Feature: wholesale-vertical-remediation, Property 10: Entity persistence round-trip
//
// **Validates: Requirements 7.2, 8.3, 10.3, 11.3, 12.7**
//
// Tests domain entities (TransportDetails, Warehouse, RateList, EWayRecord) can
// be constructed with random valid field values and fields are accessible.
//
// ForAll 200 iterations: generate random valid field values, construct entities,
// verify correctness. This is a data-class contract test (no DB).
//
// PBT library: dartproptest ^0.2.1.
//
// Run: flutter test test/features/wholesale/property_entity_roundtrip_test.dart
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';

import 'package:dukanx/features/wholesale/domain/transport_details.dart';
import 'package:dukanx/features/wholesale/domain/warehouse.dart';
import 'package:dukanx/features/wholesale/domain/rate_list.dart';
import 'package:dukanx/features/wholesale/domain/eway_record.dart';

void main() {
  const int kNumRuns = 200;

  group(
    'Feature: wholesale-vertical-remediation, Property 10: Entity persistence round-trip',
    () {
      // -----------------------------------------------------------------------
      // Property 10a: TransportDetails construction and field accessibility.
      // -----------------------------------------------------------------------
      test(
        'Property 10a (forAll): TransportDetails fields are accessible after construction',
        () {
          final held = forAll(
            (int seed) {
              final id = 'tenant_$seed-${seed * 1000}-abcdef01';
              final tenantId = 'tenant_$seed';
              final vehicleNumber =
                  'MH${(seed % 99).toString().padLeft(2, '0')}AB${seed % 9999}';
              final lrNumber = 'LR-${seed.abs()}';
              final transporterName = 'Transport Co $seed';
              final linkedChallanId = 'challan_$seed';
              final createdAt = DateTime.fromMillisecondsSinceEpoch(
                1700000000000 + seed * 1000,
              );

              final entity = TransportDetails(
                id: id,
                tenantId: tenantId,
                vehicleNumber: vehicleNumber,
                lrNumber: lrNumber,
                transporterName: transporterName,
                linkedChallanId: linkedChallanId,
                createdAt: createdAt,
              );

              // Verify all fields are correctly stored and accessible.
              return entity.id == id &&
                  entity.tenantId == tenantId &&
                  entity.vehicleNumber == vehicleNumber &&
                  entity.lrNumber == lrNumber &&
                  entity.transporterName == transporterName &&
                  entity.linkedChallanId == linkedChallanId &&
                  entity.createdAt == createdAt;
            },
            [Gen.interval(1, 99999)],
            numRuns: kNumRuns,
          );
          expect(
            held,
            isTrue,
            reason:
                'TransportDetails must store and return all fields correctly',
          );
        },
      );

      // -----------------------------------------------------------------------
      // Property 10b: TransportDetails equality and copyWith contract.
      // -----------------------------------------------------------------------
      test('Property 10b (forAll): TransportDetails equality and copyWith', () {
        final held = forAll(
          (int seed) {
            final entity = TransportDetails(
              id: 'id_$seed',
              tenantId: 'tenant_$seed',
              vehicleNumber: 'VH$seed',
              lrNumber: 'LR$seed',
              transporterName: 'Transporter $seed',
              linkedChallanId: 'ch_$seed',
              createdAt: DateTime(2024, 1, 1),
            );

            // Same values → equal
            final same = TransportDetails(
              id: 'id_$seed',
              tenantId: 'tenant_$seed',
              vehicleNumber: 'VH$seed',
              lrNumber: 'LR$seed',
              transporterName: 'Transporter $seed',
              linkedChallanId: 'ch_$seed',
              createdAt: DateTime(2024, 1, 1),
            );

            // copyWith with different field → not equal
            final modified = entity.copyWith(vehicleNumber: 'DIFFERENT');

            return entity == same &&
                entity.hashCode == same.hashCode &&
                modified.vehicleNumber == 'DIFFERENT' &&
                modified.id == entity.id;
          },
          [Gen.interval(1, 99999)],
          numRuns: kNumRuns,
        );
        expect(
          held,
          isTrue,
          reason: 'TransportDetails equality and copyWith must work correctly',
        );
      });

      // -----------------------------------------------------------------------
      // Property 10c: Warehouse construction and field accessibility.
      // -----------------------------------------------------------------------
      test(
        'Property 10c (forAll): Warehouse fields are accessible after construction',
        () {
          final held = forAll(
            (int seed) {
              final id = 'wh_tenant_$seed-${seed * 1000}-aabb0011';
              final tenantId = 'wh_tenant_$seed';
              final name = 'Godown ${seed.abs()}';
              final createdAt = DateTime.fromMillisecondsSinceEpoch(
                1700000000000 + seed * 500,
              );

              final entity = Warehouse(
                id: id,
                tenantId: tenantId,
                name: name,
                createdAt: createdAt,
              );

              return entity.id == id &&
                  entity.tenantId == tenantId &&
                  entity.name == name &&
                  entity.createdAt == createdAt;
            },
            [Gen.interval(1, 99999)],
            numRuns: kNumRuns,
          );
          expect(
            held,
            isTrue,
            reason: 'Warehouse must store and return all fields correctly',
          );
        },
      );

      // -----------------------------------------------------------------------
      // Property 10d: Warehouse equality contract.
      // -----------------------------------------------------------------------
      test('Property 10d (forAll): Warehouse equality contract', () {
        final held = forAll(
          (int seed) {
            final w1 = Warehouse(
              id: 'w_$seed',
              tenantId: 't_$seed',
              name: 'Godown $seed',
              createdAt: DateTime(2024, 6, 1),
            );
            final w2 = Warehouse(
              id: 'w_$seed',
              tenantId: 't_$seed',
              name: 'Godown $seed',
              createdAt: DateTime(2024, 6, 1),
            );
            final w3 = w1.copyWith(name: 'Different Godown');

            return w1 == w2 &&
                w1.hashCode == w2.hashCode &&
                w3.name == 'Different Godown' &&
                w3.id == w1.id;
          },
          [Gen.interval(1, 99999)],
          numRuns: kNumRuns,
        );
        expect(
          held,
          isTrue,
          reason: 'Warehouse equality and copyWith must work correctly',
        );
      });

      // -----------------------------------------------------------------------
      // Property 10e: RateList construction with PricingSlabs.
      // -----------------------------------------------------------------------
      test(
        'Property 10e (forAll): RateList with PricingSlabs fields are accessible',
        () {
          final held = forAll(
            (int seed) {
              final id = 'rl_$seed-${seed * 100}-ccdd0022';
              final tenantId = 'rl_tenant_$seed';
              final productId = 'prod_${seed.abs()}';
              final partyId = seed % 2 == 0 ? 'party_$seed' : null;
              final slabs = [
                PricingSlab(
                  minQty: 1,
                  maxQty: (seed % 50) + 10,
                  unitPaise: (seed % 1000) + 100,
                ),
                PricingSlab(
                  minQty: (seed % 50) + 11,
                  maxQty: null,
                  unitPaise: (seed % 500) + 50,
                ),
              ];
              final createdAt = DateTime(2024, 3, 15);

              final entity = RateList(
                id: id,
                tenantId: tenantId,
                partyId: partyId,
                productId: productId,
                slabs: slabs,
                createdAt: createdAt,
              );

              return entity.id == id &&
                  entity.tenantId == tenantId &&
                  entity.partyId == partyId &&
                  entity.productId == productId &&
                  entity.slabs.length == 2 &&
                  entity.slabs[0].minQty == 1 &&
                  entity.slabs[1].maxQty == null &&
                  entity.createdAt == createdAt;
            },
            [Gen.interval(1, 99999)],
            numRuns: kNumRuns,
          );
          expect(
            held,
            isTrue,
            reason: 'RateList must store and return all fields correctly',
          );
        },
      );

      // -----------------------------------------------------------------------
      // Property 10f: PricingSlab JSON round-trip (toJson → fromJson).
      // -----------------------------------------------------------------------
      test('Property 10f (forAll): PricingSlab JSON round-trip', () {
        final held = forAll(
          (int seed) {
            final minQty = (seed.abs() % 100) + 1;
            final maxQty = seed % 2 == 0 ? minQty + (seed % 50) + 1 : null;
            final unitPaise = (seed.abs() % 10000) + 1;

            final original = PricingSlab(
              minQty: minQty,
              maxQty: maxQty,
              unitPaise: unitPaise,
            );

            final json = original.toJson();
            final restored = PricingSlab.fromJson(json);

            return restored.minQty == original.minQty &&
                restored.maxQty == original.maxQty &&
                restored.unitPaise == original.unitPaise &&
                restored == original;
          },
          [Gen.interval(-99999, 99999)],
          numRuns: kNumRuns,
        );
        expect(
          held,
          isTrue,
          reason: 'PricingSlab must survive JSON round-trip unchanged',
        );
      });

      // -----------------------------------------------------------------------
      // Property 10g: EWayRecord construction and field accessibility.
      // -----------------------------------------------------------------------
      test(
        'Property 10g (forAll): EWayRecord fields are accessible after construction',
        () {
          final held = forAll(
            (int seed) {
              final id = 'ew_$seed-${seed * 100}-eeff0033';
              final tenantId = 'ew_tenant_$seed';
              final consignmentPaise = (seed.abs() % 10000000) + 5000000;
              final interState = seed % 2 == 0;
              final transporterName = 'EW Transport $seed';
              final approxDistanceKm = (seed.abs() % 2000) + 10;
              final vehicleNumber = 'KA${seed % 99}XY${seed % 9999}';
              final partyGstin = '${(seed % 29 + 10)}AABCU${seed % 9999}A1Z5';
              final createdAt = DateTime.fromMillisecondsSinceEpoch(
                1700000000000 + seed * 2000,
              );

              final entity = EWayRecord(
                id: id,
                tenantId: tenantId,
                consignmentPaise: consignmentPaise,
                interState: interState,
                transporterName: transporterName,
                approxDistanceKm: approxDistanceKm,
                vehicleNumber: vehicleNumber,
                partyGstin: partyGstin,
                ewayNumber: null, // Blocked — GSP unavailable
                status: EWayStatus.blocked,
                createdAt: createdAt,
              );

              return entity.id == id &&
                  entity.tenantId == tenantId &&
                  entity.consignmentPaise == consignmentPaise &&
                  entity.interState == interState &&
                  entity.transporterName == transporterName &&
                  entity.approxDistanceKm == approxDistanceKm &&
                  entity.vehicleNumber == vehicleNumber &&
                  entity.partyGstin == partyGstin &&
                  entity.ewayNumber == null &&
                  entity.status == EWayStatus.blocked &&
                  entity.createdAt == createdAt;
            },
            [Gen.interval(1, 99999)],
            numRuns: kNumRuns,
          );
          expect(
            held,
            isTrue,
            reason: 'EWayRecord must store and return all fields correctly',
          );
        },
      );

      // -----------------------------------------------------------------------
      // Property 10h: EWayRecord money field is integer (paise) — never double.
      // -----------------------------------------------------------------------
      test(
        'Property 10h (forAll): EWayRecord.consignmentPaise is always int',
        () {
          final held = forAll(
            (int seed) {
              final paise = seed.abs() * 100 + 50;

              final entity = EWayRecord(
                id: 'ew_int_$seed',
                tenantId: 'tenant',
                consignmentPaise: paise,
                interState: false,
                transporterName: 'T',
                approxDistanceKm: 100,
                vehicleNumber: 'VH1234',
                partyGstin: '29AABCU1234A1Z5',
                status: EWayStatus.blocked,
                createdAt: DateTime(2024),
              );

              return entity.consignmentPaise is int &&
                  entity.consignmentPaise == paise;
            },
            [Gen.interval(0, 99999)],
            numRuns: kNumRuns,
          );
          expect(
            held,
            isTrue,
            reason: 'EWayRecord.consignmentPaise must always be int (paise)',
          );
        },
      );
    },
  );
}
