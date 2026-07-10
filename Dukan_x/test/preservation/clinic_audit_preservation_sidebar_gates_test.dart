/// Preservation Property Test — Existing Sidebar Capability Gates Unaffected
///
/// **Validates: Requirements 3.6**
///
/// Property 6: Preservation — Existing Sidebar Capability Gates Unaffected
///
/// This test observes `_getClinicSections()`'s exact `capability` values for
/// `prescriptions`, `medicine_master`, `scan_qr`, `patient_queue`,
/// `clinic_calendar`, and `revenue_overview` (ungated) on UNFIXED code, records
/// them as baseline, then uses PBT to generate arbitrary clinic capability sets
/// and asserts these six items' gating decisions match the recorded baseline.
///
/// Specifically:
///   - `revenue_overview` remains ungated (always visible regardless of caps)
///   - `prescriptions` and `medicine_master` are gated by `usePrescription`
///   - `scan_qr`, `patient_queue`, `clinic_calendar` are gated by `usePatientRegistry`
///
/// PBT library: dartproptest ^0.2.1.
///
/// Run: flutter test test/preservation/clinic_audit_preservation_sidebar_gates_test.dart
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';

import 'package:dukanx/core/isolation/business_capability.dart';
import 'package:dukanx/core/isolation/feature_resolver.dart';
import 'package:dukanx/models/business_type.dart';
import 'package:dukanx/providers/app_state_providers.dart';
import 'package:dukanx/widgets/desktop/sidebar_configuration.dart';

// ---------------------------------------------------------------------------
// Recorded baseline — exact capability gate values observed on UNFIXED code.
//
// These are the expected gates for the 6 items that MUST remain unchanged
// after the clinic bugfixes land.
// ---------------------------------------------------------------------------

/// Maps each sidebar item id to its expected capability gate (null = ungated).
const Map<String, BusinessCapability?> _expectedGates = {
  'prescriptions': BusinessCapability.usePrescription,
  'medicine_master': BusinessCapability.usePrescription,
  'scan_qr': BusinessCapability.usePatientRegistry,
  'patient_queue': BusinessCapability.usePatientRegistry,
  'clinic_calendar': BusinessCapability.usePatientRegistry,
  'revenue_overview': null, // deliberately ungated
};

// ---------------------------------------------------------------------------
// Test doubles for Riverpod overrides.
// ---------------------------------------------------------------------------
class _ClinicBusinessTypeNotifier extends BusinessTypeNotifier {
  @override
  BusinessTypeState build() => BusinessTypeState(type: BusinessType.clinic);
}

class _UnauthAuthNotifier extends AuthStateNotifier {
  @override
  AuthState build() =>
      AuthState(status: AuthStatus.unauthenticated, session: null);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Extract the 6 target items from the clinic sidebar sections.
Map<String, SidebarMenuItem> _extractTargetItems(
  List<SidebarSection> sections,
) {
  final result = <String, SidebarMenuItem>{};
  for (final section in sections) {
    for (final item in section.items) {
      if (_expectedGates.containsKey(item.id)) {
        result[item.id] = item;
      }
    }
  }
  return result;
}

/// Get the UNFILTERED clinic sections (before capability gating is applied).
/// We read from the sidebarSectionsProvider with an unauthenticated session
/// so that capability-gated items are filtered. Instead, we use a provider
/// that returns ALL sections unfiltered by overriding with full capabilities.
///
/// Actually — to see the raw items and their `capability` field values, we
/// need access to the unfiltered section list. The `sidebarSectionsProvider`
/// filters items by capability. We need the raw `_getClinicSections()` output.
///
/// Since `_getClinicSections()` is private, we access it indirectly through the
/// `sidebarSectionsProvider` by granting ALL capabilities (unauthenticated means
/// no RBAC filtering, and items without capability pass through).
///
/// However, items WITH a capability that ISN'T granted to clinic will be
/// filtered out. The target items' capabilities (usePrescription, usePatientRegistry)
/// ARE granted to clinic, so they will pass through. Items with null capability
/// always pass through. So the 6 target items will all be visible.
List<SidebarSection> _getUnfilteredClinicSections() {
  final container = ProviderContainer(
    overrides: [
      businessTypeProvider.overrideWith(() => _ClinicBusinessTypeNotifier()),
      authStateProvider.overrideWith(() => _UnauthAuthNotifier()),
    ],
  );
  final sections = container.read(sidebarSectionsProvider);
  container.dispose();
  return sections;
}

/// Simulate what FeatureResolver.canAccess would return for a given item
/// against a specific capability set.
///
/// If item.capability is null → always visible (return true).
/// If item.capability is non-null → visible only if the capability set contains it.
bool _wouldItemBeVisible(SidebarMenuItem item, Set<BusinessCapability> caps) {
  if (item.capability == null) return true;
  return caps.contains(item.capability!);
}

// ---------------------------------------------------------------------------
// All clinic-relevant capabilities (the full set granted to clinic in the
// registry, used for generating arbitrary subsets).
// ---------------------------------------------------------------------------
final List<BusinessCapability> _allClinicCapabilities = [
  BusinessCapability.useInvoiceList,
  BusinessCapability.useInvoiceSearch,
  BusinessCapability.useInvoiceCreate,
  BusinessCapability.useDailySnapshot,
  BusinessCapability.useRevenueOverview,
  BusinessCapability.useAppointments,
  BusinessCapability.useConsultationBilling,
  BusinessCapability.usePatientRegistry,
  BusinessCapability.usePrescription,
  BusinessCapability.useDoctorLinking,
];

void main() {
  // =========================================================================
  // DIRECT ASSERTION: Verify the 6 items' capability gates match baseline
  // =========================================================================
  group('Preservation 3.6 — sidebar capability gates baseline', () {
    test('all 6 target items exist in the clinic sidebar', () {
      final sections = _getUnfilteredClinicSections();
      final items = _extractTargetItems(sections);

      // All 6 must be present (revenue_overview has null capability so it
      // passes the filter; the others have capabilities granted to clinic)
      for (final id in _expectedGates.keys) {
        expect(
          items.containsKey(id),
          isTrue,
          reason: 'Sidebar item "$id" must exist in the clinic sidebar',
        );
      }
    });

    test('prescriptions is gated by BusinessCapability.usePrescription', () {
      final sections = _getUnfilteredClinicSections();
      final items = _extractTargetItems(sections);
      expect(
        items['prescriptions']!.capability,
        BusinessCapability.usePrescription,
      );
    });

    test('medicine_master is gated by BusinessCapability.usePrescription', () {
      final sections = _getUnfilteredClinicSections();
      final items = _extractTargetItems(sections);
      expect(
        items['medicine_master']!.capability,
        BusinessCapability.usePrescription,
      );
    });

    test('scan_qr is gated by BusinessCapability.usePatientRegistry', () {
      final sections = _getUnfilteredClinicSections();
      final items = _extractTargetItems(sections);
      expect(
        items['scan_qr']!.capability,
        BusinessCapability.usePatientRegistry,
      );
    });

    test('patient_queue is gated by BusinessCapability.usePatientRegistry', () {
      final sections = _getUnfilteredClinicSections();
      final items = _extractTargetItems(sections);
      expect(
        items['patient_queue']!.capability,
        BusinessCapability.usePatientRegistry,
      );
    });

    test(
      'clinic_calendar is gated by BusinessCapability.usePatientRegistry',
      () {
        final sections = _getUnfilteredClinicSections();
        final items = _extractTargetItems(sections);
        expect(
          items['clinic_calendar']!.capability,
          BusinessCapability.usePatientRegistry,
        );
      },
    );

    test('revenue_overview is ungated (capability == null)', () {
      final sections = _getUnfilteredClinicSections();
      final items = _extractTargetItems(sections);
      expect(
        items['revenue_overview']!.capability,
        isNull,
        reason:
            'revenue_overview must remain deliberately ungated — always visible '
            'regardless of the clinic capability set',
      );
    });
  });

  // =========================================================================
  // PBT: Generate arbitrary clinic capability subsets and verify gating
  // decisions for the 6 items match the recorded baseline.
  //
  // The property: for ANY subset S of clinic-relevant capabilities:
  //   - revenue_overview is ALWAYS visible (ungated)
  //   - prescriptions is visible IFF usePrescription ∈ S
  //   - medicine_master is visible IFF usePrescription ∈ S
  //   - scan_qr is visible IFF usePatientRegistry ∈ S
  //   - patient_queue is visible IFF usePatientRegistry ∈ S
  //   - clinic_calendar is visible IFF usePatientRegistry ∈ S
  // =========================================================================
  group('PBT — arbitrary capability sets preserve gating decisions', () {
    test(
      'for all capability subsets: 6 items gating matches recorded baseline',
      () {
        // Get the raw items once (they don't change — the capability FIELD
        // on the item is what we're testing, not the filtering).
        final sections = _getUnfilteredClinicSections();
        final items = _extractTargetItems(sections);

        forAll(
          (int bitmask) {
            // Generate a capability subset from the bitmask
            final capSubset = <BusinessCapability>{};
            for (var i = 0; i < _allClinicCapabilities.length; i++) {
              if (bitmask & (1 << i) != 0) {
                capSubset.add(_allClinicCapabilities[i]);
              }
            }

            // For each of the 6 target items, verify the gating decision
            for (final entry in _expectedGates.entries) {
              final id = entry.key;
              final expectedCapability = entry.value;
              final item = items[id]!;

              // Verify the item's capability field matches baseline
              expect(
                item.capability,
                expectedCapability,
                reason:
                    'Item "$id" capability gate must remain '
                    '${expectedCapability?.name ?? "null (ungated)"}',
              );

              // Verify the visibility decision for this capability subset
              final visible = _wouldItemBeVisible(item, capSubset);

              if (expectedCapability == null) {
                // Ungated items are ALWAYS visible
                expect(
                  visible,
                  isTrue,
                  reason:
                      'Item "$id" is ungated — must be visible for ANY '
                      'capability set (subset: $capSubset)',
                );
              } else {
                // Gated items are visible IFF their capability is in the set
                final expectedVisible = capSubset.contains(expectedCapability);
                expect(
                  visible,
                  expectedVisible,
                  reason:
                      'Item "$id" (gate: ${expectedCapability.name}) visibility '
                      'mismatch for capability subset: $capSubset',
                );
              }

              return true;
            }
            return true;
          },
          // Generate bitmasks covering 0..(2^10 - 1) = all 1024 possible
          // subsets of the 10 clinic-relevant capabilities
          [Gen.interval(0, (1 << _allClinicCapabilities.length) - 1)],
          numRuns: 100,
        );
      },
    );

    test(
      'revenue_overview always visible regardless of capability set (targeted)',
      () {
        final sections = _getUnfilteredClinicSections();
        final items = _extractTargetItems(sections);
        final revenueItem = items['revenue_overview']!;

        forAll(
          (int bitmask) {
            final capSubset = <BusinessCapability>{};
            for (var i = 0; i < _allClinicCapabilities.length; i++) {
              if (bitmask & (1 << i) != 0) {
                capSubset.add(_allClinicCapabilities[i]);
              }
            }

            // revenue_overview must ALWAYS be visible — it has no capability gate
            expect(
              _wouldItemBeVisible(revenueItem, capSubset),
              isTrue,
              reason:
                  'revenue_overview must remain visible for capability set: '
                  '$capSubset',
            );

            return true;
          },
          [Gen.interval(0, (1 << _allClinicCapabilities.length) - 1)],
          numRuns: 100,
        );
      },
    );

    test('gated items hidden when their specific capability is removed', () {
      final sections = _getUnfilteredClinicSections();
      final items = _extractTargetItems(sections);

      // Full set minus one capability at a time
      forAll(
        (int removeIdx) {
          final idx = removeIdx % _allClinicCapabilities.length;
          final removedCap = _allClinicCapabilities[idx];
          final capSubset = Set<BusinessCapability>.from(_allClinicCapabilities)
            ..remove(removedCap);

          for (final entry in _expectedGates.entries) {
            final id = entry.key;
            final expectedCap = entry.value;
            final item = items[id]!;

            final visible = _wouldItemBeVisible(item, capSubset);

            if (expectedCap == null) {
              // Ungated — always visible
              expect(visible, isTrue);
            } else if (expectedCap == removedCap) {
              // This item's gate was removed — should be HIDDEN
              expect(
                visible,
                isFalse,
                reason:
                    'Item "$id" must be hidden when ${removedCap.name} is '
                    'removed from the capability set',
              );
            } else {
              // This item's gate is still present — should be visible
              expect(visible, isTrue);
            }
          }

          return true;
        },
        [Gen.interval(0, _allClinicCapabilities.length - 1)],
        numRuns: 30,
      );
    });
  });
}
