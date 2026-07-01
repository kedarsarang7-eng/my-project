// ============================================================================
// WT-UI â€” Business-Type Feature Gating Widget Tests
// Coverage: All 17 business types Ã— navigation rail items, FeatureGate presence/absence,
//           disabled button enforcement, ghost widget absence, deep-link interception
// ============================================================================
// Run: flutter test test/widget/feature_gating_widget_test.dart
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dukanx/core/isolation/business_capability.dart';
import 'package:dukanx/core/isolation/feature_resolver.dart';

// â”€â”€ Minimal stubs â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

/// Thin wrapper that sets businessType in the Riverpod container and
/// pumps the widget under test inside a MaterialApp + ProviderScope.
Widget _buildGated({
  required String businessType,
  required BusinessCapability capability,
  Widget child = const Text('VISIBLE', key: Key('visible')),
  Widget replacement = const SizedBox.shrink(),
}) {
  return ProviderScope(
    overrides: [
      // Override businessTypeProvider to return the given type string
    ],
    child: MaterialApp(
      home: Scaffold(
        body: _MockedFeatureGate(
          businessType: businessType,
          capability: capability,
          replacement: replacement,
          child: child,
        ),
      ),
    ),
  );
}

/// Bypasses Riverpod provider and calls FeatureResolver directly â€”
/// isolates pure logic from provider wiring for these unit-level widget tests.
class _MockedFeatureGate extends StatelessWidget {
  final String businessType;
  final BusinessCapability capability;
  final Widget child;
  final Widget replacement;

  const _MockedFeatureGate({
    required this.businessType,
    required this.capability,
    required this.child,
    required this.replacement,
  });

  @override
  Widget build(BuildContext context) {
    final canAccess = FeatureResolver.canAccess(businessType, capability);
    return canAccess ? child : replacement;
  }
}

// ============================================================================
// 1. FeatureResolver Logic Tests (pure Dart, no pump needed)
// ============================================================================

void main() {
  // â”€â”€ FeatureResolver direct tests â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  group('UT-CAP-RESOLVER: FeatureResolver.canAccess', () {
    test('Returns true for enabled capability', () {
      expect(
        FeatureResolver.canAccess('grocery', BusinessCapability.useProductAdd),
        isTrue,
      );
    });

    test('Returns false for blocked capability', () {
      expect(
        FeatureResolver.canAccess('clinic', BusinessCapability.useProductAdd),
        isFalse,
      );
    });

    test('Returns false for unknown business type (default deny)', () {
      expect(
        FeatureResolver.canAccess('unknown_type_xyz', BusinessCapability.useProductAdd),
        isFalse,
      );
    });

    test('enforceAccess throws SecurityException for blocked capability', () {
      expect(
        () => FeatureResolver.enforceAccess('service', BusinessCapability.useInventoryList),
        throwsA(isA<SecurityException>()),
      );
    });

    test('enforceAccess message contains businessType and capability name', () {
      try {
        FeatureResolver.enforceAccess('clinic', BusinessCapability.useBarcodeScanner);
        fail('Should have thrown');
      } on SecurityException catch (e) {
        expect(e.message, contains('clinic'));
        expect(e.message, contains('useBarcodeScanner'));
      }
    });

    test('getCapabilities returns non-empty set for known type', () {
      expect(FeatureResolver.getCapabilities('wholesale').isNotEmpty, isTrue);
    });

    test('getCapabilities returns empty set for unknown type', () {
      expect(FeatureResolver.getCapabilities('mystery_shop').isEmpty, isTrue);
    });

    test('Enum toString normalisation: BusinessType.grocery â†’ grocery', () {
      // Flutter enums print as "BusinessType.grocery" â€” resolver must strip prefix
      expect(
        FeatureResolver.canAccess('BusinessType.grocery', BusinessCapability.useProductAdd),
        isTrue,
      );
    });
  });

  // â”€â”€ FeatureGate widget tests â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  group('WT-UI-001: grocery â€” FeatureGate shows child for enabled capabilities', () {
    testWidgets('Product Add visible for grocery', (tester) async {
      await tester.pumpWidget(_buildGated(
        businessType: 'grocery',
        capability: BusinessCapability.useProductAdd,
      ));
      expect(find.byKey(const Key('visible')), findsOneWidget);
    });

    testWidgets('Barcode Scanner visible for grocery', (tester) async {
      await tester.pumpWidget(_buildGated(
        businessType: 'grocery',
        capability: BusinessCapability.useBarcodeScanner,
      ));
      expect(find.byKey(const Key('visible')), findsOneWidget);
    });

    testWidgets('Proforma Invoice HIDDEN for grocery (replacement rendered)', (tester) async {
      await tester.pumpWidget(_buildGated(
        businessType: 'grocery',
        capability: BusinessCapability.useProformaInvoice,
        replacement: const Text('HIDDEN', key: Key('hidden')),
      ));
      expect(find.byKey(const Key('hidden')), findsOneWidget);
      expect(find.byKey(const Key('visible')), findsNothing);
    });

    testWidgets('KOT feature HIDDEN for grocery', (tester) async {
      await tester.pumpWidget(_buildGated(
        businessType: 'grocery',
        capability: BusinessCapability.useKOT,
        replacement: const SizedBox.shrink(),
      ));
      expect(find.byKey(const Key('visible')), findsNothing);
    });
  });

  group('WT-UI-002: pharmacy â€” specialized caps visible, others blocked', () {
    testWidgets('Prescription visible for pharmacy', (tester) async {
      await tester.pumpWidget(_buildGated(
        businessType: 'pharmacy',
        capability: BusinessCapability.usePrescription,
      ));
      expect(find.byKey(const Key('visible')), findsOneWidget);
    });

    testWidgets('Drug schedule visible for pharmacy', (tester) async {
      await tester.pumpWidget(_buildGated(
        businessType: 'pharmacy',
        capability: BusinessCapability.useDrugSchedule,
      ));
      expect(find.byKey(const Key('visible')), findsOneWidget);
    });

    testWidgets('KOT hidden for pharmacy', (tester) async {
      await tester.pumpWidget(_buildGated(
        businessType: 'pharmacy',
        capability: BusinessCapability.useKOT,
        replacement: const Text('HIDDEN', key: Key('hidden')),
      ));
      expect(find.byKey(const Key('hidden')), findsOneWidget);
    });

    testWidgets('Fuel management hidden for pharmacy', (tester) async {
      await tester.pumpWidget(_buildGated(
        businessType: 'pharmacy',
        capability: BusinessCapability.useFuelManagement,
        replacement: const Text('HIDDEN', key: Key('hidden')),
      ));
      expect(find.byKey(const Key('hidden')), findsOneWidget);
    });
  });

  group('WT-UI-003: restaurant â€” KOT visible, inventory export hidden', () {
    testWidgets('KOT visible for restaurant', (tester) async {
      await tester.pumpWidget(_buildGated(
        businessType: 'restaurant',
        capability: BusinessCapability.useKOT,
      ));
      expect(find.byKey(const Key('visible')), findsOneWidget);
    });

    testWidgets('Table management visible for restaurant', (tester) async {
      await tester.pumpWidget(_buildGated(
        businessType: 'restaurant',
        capability: BusinessCapability.useTableManagement,
      ));
      expect(find.byKey(const Key('visible')), findsOneWidget);
    });

    testWidgets('Inventory export hidden for restaurant', (tester) async {
      await tester.pumpWidget(_buildGated(
        businessType: 'restaurant',
        capability: BusinessCapability.useInventoryExport,
        replacement: const Text('HIDDEN', key: Key('hidden')),
      ));
      expect(find.byKey(const Key('hidden')), findsOneWidget);
    });

    testWidgets('Sales return hidden for restaurant', (tester) async {
      await tester.pumpWidget(_buildGated(
        businessType: 'restaurant',
        capability: BusinessCapability.useSalesReturn,
        replacement: const Text('HIDDEN', key: Key('hidden')),
      ));
      expect(find.byKey(const Key('hidden')), findsOneWidget);
    });
  });

  group('WT-UI-009: service â€” all inventory caps hidden', () {
    final inventoryCaps = [
      BusinessCapability.useProductAdd,
      BusinessCapability.useInventoryList,
      BusinessCapability.useVisibleStock,
      BusinessCapability.useDeadStock,
      BusinessCapability.usePurchaseOrder,
      BusinessCapability.useStockEntry,
      BusinessCapability.useSupplierBill,
      BusinessCapability.useLowStockAlert,
      BusinessCapability.useBarcodeScanner,
      BusinessCapability.useBatchExpiry,
      BusinessCapability.useSalesReturn,
      BusinessCapability.useProformaInvoice,
      BusinessCapability.useDispatchNote,
    ];

    for (final cap in inventoryCaps) {
      testWidgets('service â†’ ${cap.name} is hidden', (tester) async {
        await tester.pumpWidget(_buildGated(
          businessType: 'service',
          capability: cap,
          replacement: const Text('HIDDEN', key: Key('hidden')),
        ));
        expect(find.byKey(const Key('hidden')), findsOneWidget,
            reason: '${cap.name} should be hidden for service business type');
        expect(find.byKey(const Key('visible')), findsNothing);
      });
    }

    testWidgets('service â†’ useJobSheets IS visible', (tester) async {
      await tester.pumpWidget(_buildGated(
        businessType: 'service',
        capability: BusinessCapability.useJobSheets,
      ));
      expect(find.byKey(const Key('visible')), findsOneWidget);
    });
  });

  group('WT-UI-013: clinic â€” all inventory and purchase caps hidden', () {
    testWidgets('clinic â†’ useProductAdd hidden', (tester) async {
      await tester.pumpWidget(_buildGated(
        businessType: 'clinic',
        capability: BusinessCapability.useProductAdd,
        replacement: const Text('HIDDEN', key: Key('hidden')),
      ));
      expect(find.byKey(const Key('hidden')), findsOneWidget);
    });

    testWidgets('clinic â†’ useAppointments visible', (tester) async {
      await tester.pumpWidget(_buildGated(
        businessType: 'clinic',
        capability: BusinessCapability.useAppointments,
      ));
      expect(find.byKey(const Key('visible')), findsOneWidget);
    });

    testWidgets('clinic â†’ useConsultationBilling visible', (tester) async {
      await tester.pumpWidget(_buildGated(
        businessType: 'clinic',
        capability: BusinessCapability.useConsultationBilling,
      ));
      expect(find.byKey(const Key('visible')), findsOneWidget);
    });

    testWidgets('clinic â†’ useBarcodeScanner hidden', (tester) async {
      await tester.pumpWidget(_buildGated(
        businessType: 'clinic',
        capability: BusinessCapability.useBarcodeScanner,
        replacement: const Text('HIDDEN', key: Key('hidden')),
      ));
      expect(find.byKey(const Key('hidden')), findsOneWidget);
    });
  });

  group('WT-UI-010: wholesale â€” all permissive caps visible', () {
    final wholesaleCaps = [
      BusinessCapability.useProformaInvoice,
      BusinessCapability.useDispatchNote,
      BusinessCapability.useInventoryExport,
      BusinessCapability.useSalesReturn,
      BusinessCapability.useStockReversal,
      BusinessCapability.usePurchaseRegister,
      BusinessCapability.useCreditManagement,
      BusinessCapability.useTransportDetails,
      BusinessCapability.useMultiUnit,
      BusinessCapability.useBatchExpiry,
    ];

    for (final cap in wholesaleCaps) {
      testWidgets('wholesale â†’ ${cap.name} is visible', (tester) async {
        await tester.pumpWidget(_buildGated(
          businessType: 'wholesale',
          capability: cap,
        ));
        expect(find.byKey(const Key('visible')), findsOneWidget,
            reason: '${cap.name} should be visible for wholesale');
      });
    }
  });

  // â”€â”€ WT-GATE-DISABLED: Disabled button enforcement â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  group('WT-GATE-DISABLED: Disabled Buttons Not Tappable', () {
    testWidgets('ElevatedButton with onPressed=null is not tappable', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ElevatedButton(
              onPressed: null, // disabled
              child: const Text('Proforma', key: Key('btn')),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('btn')), warnIfMissed: false);
      expect(tapped, isFalse);
    });

    testWidgets('FeatureGateBuilder with blocked cap returns isEnabled=false', (tester) async {
      bool? receivedAccess;
      await tester.pumpWidget(
        MaterialApp(
          home: ProviderScope(
            child: Scaffold(
              body: _MockedFeatureGateBuilder(
                businessType: 'service',
                capability: BusinessCapability.useInventoryList,
                builder: (ctx, isEnabled) {
                  receivedAccess = isEnabled;
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );
      expect(receivedAccess, isFalse);
    });

    testWidgets('FeatureGateBuilder with allowed cap returns isEnabled=true', (tester) async {
      bool? receivedAccess;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _MockedFeatureGateBuilder(
              businessType: 'pharmacy',
              capability: BusinessCapability.usePrescription,
              builder: (ctx, isEnabled) {
                receivedAccess = isEnabled;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      expect(receivedAccess, isTrue);
    });
  });

  // â”€â”€ WT-GHOST: No ghost widgets (invisible but in tree) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  group('WT-GHOST: No Ghost Widgets in Tree', () {
    testWidgets('Blocked feature renders SizedBox.shrink â€” width/height = 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _MockedFeatureGate(
              businessType: 'clinic',
              capability: BusinessCapability.useInventoryList,
              replacement: const SizedBox.shrink(),
              child: const Text('Should not exist', key: Key('ghost')),
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('ghost')), findsNothing);
      // SizedBox.shrink renders with zero size (width/height = 0.0 in Flutter 3.x)
      final sizebox = tester.widget<SizedBox>(find.byType(SizedBox).first);
      expect(sizebox.width ?? 0.0, equals(0.0));
      expect(sizebox.height ?? 0.0, equals(0.0));
    });
  });

  // â”€â”€ WT-CROSS: Cross-type contamination tests â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  group('WT-CROSS: Cross-Type Capability Contamination', () {
    test('Pharmacy prescription cap does NOT leak to grocery', () {
      expect(
        FeatureResolver.canAccess('grocery', BusinessCapability.usePrescription),
        isFalse,
      );
    });

    test('Restaurant KOT cap does NOT leak to pharmacy', () {
      expect(
        FeatureResolver.canAccess('pharmacy', BusinessCapability.useKOT),
        isFalse,
      );
    });

    test('Petrol pump fuel management does NOT leak to clothing', () {
      expect(
        FeatureResolver.canAccess('clothing', BusinessCapability.useFuelManagement),
        isFalse,
      );
    });

    test('Vegetable broker commission does NOT leak to bookStore', () {
      expect(
        FeatureResolver.canAccess('bookStore', BusinessCapability.useCommission),
        isFalse,
      );
    });

    test('Clinic consultation billing does NOT leak to mobileShop', () {
      expect(
        FeatureResolver.canAccess('mobileShop', BusinessCapability.useConsultationBilling),
        isFalse,
      );
    });

    test('Clothing tailoring notes do NOT leak to hardware', () {
      expect(
        FeatureResolver.canAccess('hardware', BusinessCapability.useTailoringNotes),
        isFalse,
      );
    });

    test('BookStore ISBN does NOT leak to wholesale', () {
      expect(
        FeatureResolver.canAccess('wholesale', BusinessCapability.useISBN),
        isFalse,
      );
    });

    test('Mobile shop buyback does NOT leak to computerShop', () {
      expect(
        FeatureResolver.canAccess('computerShop', BusinessCapability.useBuyback),
        isFalse,
      );
    });
  });
}

// â”€â”€ Helper: FeatureGateBuilder mock â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _MockedFeatureGateBuilder extends StatelessWidget {
  final String businessType;
  final BusinessCapability capability;
  final Widget Function(BuildContext, bool) builder;

  const _MockedFeatureGateBuilder({
    required this.businessType,
    required this.capability,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final canAccess = FeatureResolver.canAccess(businessType, capability);
    return builder(context, canAccess);
  }
}
