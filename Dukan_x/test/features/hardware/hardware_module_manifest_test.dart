/// Unit test for Task 3.6 — Reconcile hardware module manifest with reachable
/// workflows surfaced by the Hardware Command Center.
///
/// **Validates: Requirements 1.6, 2.6**
///
/// Property 6: manifest and Command Center workflows internally consistent.
///
/// This test FAILS on unfixed code because hardware's `modules` list is missing
/// 'purchase', 'credit', 'delivery_challans', 'supplier_management',
/// 'projects', 'gst' — all of which are surfaced by the Command Center screen.
///
/// Preservation: no other business type's manifest changes.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/core/billing/business_type_config.dart';
import 'package:dukanx/models/business_type.dart';

void main() {
  group('Task 3.6 — Hardware module manifest ↔ Command Center consistency', () {
    /// The modules the Command Center screen exposes as workflows for hardware.
    /// Derived from hardware_command_center_screen.dart action cards.
    const commandCenterModules = <String>[
      'purchase', // GRN + Purchase Bills
      'credit', // Contractor Credit Control
      'delivery_challans', // Delivery Challans
      'supplier_management', // Supplier Management
      'projects', // Projects, Indents, Deposits
      'gst', // GST Reports
    ];

    test(
      'hardware modules list includes every module the Command Center surfaces',
      () {
        final config = BusinessTypeRegistry.getConfig(BusinessType.hardware);
        final modules = config.modules;

        for (final expected in commandCenterModules) {
          expect(
            modules.contains(expected),
            isTrue,
            reason:
                'COUNTEREXAMPLE (HARDWARE-006): hardware module manifest is '
                'missing "$expected" but the Command Center surfaces a workflow '
                'for it. Current modules: $modules',
          );
        }
      },
    );

    test('hardware still retains its original modules after the addition', () {
      final config = BusinessTypeRegistry.getConfig(BusinessType.hardware);
      final modules = config.modules;

      // These were in the original manifest and must remain.
      const originalModules = [
        'inventory',
        'sales',
        'returns',
        'quotations',
        'reports',
      ];

      for (final original in originalModules) {
        expect(
          modules.contains(original),
          isTrue,
          reason: 'hardware manifest should retain original module "$original"',
        );
      }
    });
  });

  group('Task 3.6 — Preservation: other business types unchanged', () {
    /// Snapshot of every non-hardware business type's modules list.
    /// These must NOT change when we fix hardware's manifest.
    final nonHardwareExpected = <BusinessType, List<String>>{
      BusinessType.grocery: [
        'inventory',
        'sales',
        'returns',
        'expenses',
        'reports',
      ],
      BusinessType.restaurant: ['menu', 'sales', 'kot', 'tables', 'reports'],
      BusinessType.pharmacy: [
        'inventory',
        'prescriptions',
        'sales',
        'returns',
        'suppliers',
        'reports',
      ],
      BusinessType.clothing: ['inventory', 'sales', 'returns', 'reports'],
      BusinessType.electronics: [
        'inventory',
        'sales',
        'returns',
        'warranty',
        'reports',
      ],
      BusinessType.mobileShop: [
        'inventory',
        'sales',
        'repairs',
        'second_hand',
        'reports',
      ],
      BusinessType.computerShop: [
        'inventory',
        'sales',
        'repairs',
        'custom_builds',
        'reports',
      ],
      BusinessType.service: ['jobs', 'invoices', 'customers', 'reports'],
      BusinessType.petrolPump: [
        'inventory',
        'sales',
        'shifts',
        'reading',
        'reports',
      ],
      BusinessType.vegetablesBroker: [
        'auction',
        'sales',
        'farmers',
        'buyers',
        'reports',
      ],
      BusinessType.wholesale: [
        'inventory',
        'sales',
        'bulk_orders',
        'customers',
        'reports',
      ],
      BusinessType.other: ['inventory', 'sales', 'reports'],
      BusinessType.clinic: [
        'appointments',
        'patients',
        'prescriptions',
        'inventory',
        'reports',
      ],
      BusinessType.bookStore: [
        'inventory',
        'sales',
        'school_orders',
        'reports',
      ],
      BusinessType.jewellery: [
        'inventory',
        'sales',
        'custom_orders',
        'reports',
      ],
      BusinessType.autoParts: ['inventory', 'sales', 'returns', 'reports'],
      BusinessType.decorationCatering: [
        'events',
        'sales',
        'caterers',
        'inventory',
        'reports',
      ],
      BusinessType.schoolErp: [
        'students',
        'fees',
        'attendance',
        'exams',
        'reports',
      ],
    };

    for (final entry in nonHardwareExpected.entries) {
      test('${entry.key.name} modules list is unchanged', () {
        final config = BusinessTypeRegistry.getConfig(entry.key);
        expect(
          config.modules,
          equals(entry.value),
          reason:
              'PRESERVATION VIOLATION (3.6): ${entry.key.name} modules list '
              'changed from ${entry.value} to ${config.modules}. Only hardware '
              'should be affected.',
        );
      });
    }
  });
}
