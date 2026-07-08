/// Unit + Widget tests for the PO → GRN → Purchase Bill pipeline.
///
/// **Validates: Requirements 1.5, 2.5, 1.15, 2.15**
///
/// Bug Condition: isBugCondition(input) where input.surface == 'hardwareOps.grnOrBill'
///
/// These tests verify:
///   1. HardwareOpsRepository exposes GRN/Bill methods (listGrn, createGrn,
///      listPurchaseBills, createPurchaseBill, returnPurchaseBill)
///   2. GRN and Purchase Bill screens exist and are reachable from the workspace
///   3. The sidebar navigation handler resolves 'hardware_grn' and
///      'hardware_purchase_bills' to real screens
///   4. The command center includes GRN and Purchase Bill action cards
///   5. Existing PO create/list is unchanged (preservation)
///
/// NOTE: Uses source-file probes (like the existing exploration tests) to avoid
/// transitive dependency on the broken app_database.g.dart codegen.
///
/// Run: flutter test test/features/hardware/hardware_grn_purchase_bill_test.dart
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Reads a source file relative to the project root.
String _readSource(String relativePath) {
  final f = File(relativePath);
  return f.existsSync() ? f.readAsStringSync() : '';
}

void main() {
  // ===========================================================================
  // 1. Repository method existence — GRN & Purchase Bill methods
  // ===========================================================================
  group('Bug Condition B — GRN/Bill repository methods exist', () {
    final repoSrc = _readSource(
      'lib/features/hardware/data/hardware_ops_repository.dart',
    );

    test('HardwareOpsRepository has listGrn method', () {
      expect(
        repoSrc.contains('Future<HardwareMapList> listGrn('),
        isTrue,
        reason:
            'COUNTEREXAMPLE (3.2): HardwareOpsRepository does not expose '
            'listGrn() — GRN listing is missing.',
      );
    });

    test('HardwareOpsRepository has createGrn method', () {
      expect(
        repoSrc.contains('Future<bool> createGrn('),
        isTrue,
        reason:
            'COUNTEREXAMPLE (3.2): HardwareOpsRepository does not expose '
            'createGrn() — GRN creation is missing.',
      );
    });

    test('HardwareOpsRepository has listPurchaseBills method', () {
      expect(
        repoSrc.contains('Future<HardwareMapList> listPurchaseBills('),
        isTrue,
        reason:
            'COUNTEREXAMPLE (3.2): HardwareOpsRepository does not expose '
            'listPurchaseBills() — Purchase Bill listing is missing.',
      );
    });

    test('HardwareOpsRepository has createPurchaseBill method', () {
      expect(
        repoSrc.contains('Future<bool> createPurchaseBill('),
        isTrue,
        reason:
            'COUNTEREXAMPLE (3.2): HardwareOpsRepository does not expose '
            'createPurchaseBill() — Purchase Bill creation is missing.',
      );
    });

    test('HardwareOpsRepository has returnPurchaseBill method', () {
      expect(
        repoSrc.contains('Future<bool> returnPurchaseBill('),
        isTrue,
        reason:
            'COUNTEREXAMPLE (3.2): HardwareOpsRepository does not expose '
            'returnPurchaseBill() — Purchase Bill return is missing.',
      );
    });
  });

  // ===========================================================================
  // 2. Screen existence — GRN and Purchase Bill screen files exist
  // ===========================================================================
  group('Bug Condition B — GRN/Bill screens exist', () {
    test('HardwareGrnScreen file exists', () {
      final exists = File(
        'lib/features/hardware/presentation/screens/hardware_grn_screen.dart',
      ).existsSync();
      expect(
        exists,
        isTrue,
        reason:
            'COUNTEREXAMPLE (3.2): hardware_grn_screen.dart does not exist — '
            'no GRN screen has been created.',
      );
    });

    test('HardwareGrnScreen contains StatefulWidget class', () {
      final src = _readSource(
        'lib/features/hardware/presentation/screens/hardware_grn_screen.dart',
      );
      expect(
        src.contains('class HardwareGrnScreen extends StatefulWidget'),
        isTrue,
        reason:
            'COUNTEREXAMPLE (3.2): hardware_grn_screen.dart does not declare '
            'a HardwareGrnScreen StatefulWidget.',
      );
    });

    test('HardwareGrnScreen accepts purchaseOrderId parameter', () {
      final src = _readSource(
        'lib/features/hardware/presentation/screens/hardware_grn_screen.dart',
      );
      expect(
        src.contains('purchaseOrderId'),
        isTrue,
        reason:
            'COUNTEREXAMPLE (3.2): HardwareGrnScreen does not accept a '
            'purchaseOrderId parameter for PO → GRN linking.',
      );
    });

    test('HardwarePurchaseBillScreen file exists', () {
      final exists = File(
        'lib/features/hardware/presentation/screens/hardware_purchase_bill_screen.dart',
      ).existsSync();
      expect(
        exists,
        isTrue,
        reason:
            'COUNTEREXAMPLE (3.2): hardware_purchase_bill_screen.dart does not '
            'exist — no Purchase Bill screen has been created.',
      );
    });

    test('HardwarePurchaseBillScreen contains StatefulWidget class', () {
      final src = _readSource(
        'lib/features/hardware/presentation/screens/hardware_purchase_bill_screen.dart',
      );
      expect(
        src.contains('class HardwarePurchaseBillScreen extends StatefulWidget'),
        isTrue,
        reason:
            'COUNTEREXAMPLE (3.2): hardware_purchase_bill_screen.dart does not '
            'declare a HardwarePurchaseBillScreen StatefulWidget.',
      );
    });

    test('HardwarePurchaseBillScreen has returnPurchaseBill action', () {
      final src = _readSource(
        'lib/features/hardware/presentation/screens/hardware_purchase_bill_screen.dart',
      );
      expect(
        src.contains('returnPurchaseBill'),
        isTrue,
        reason:
            'COUNTEREXAMPLE (3.2): HardwarePurchaseBillScreen does not wire '
            'the returnPurchaseBill action — cannot return a bill.',
      );
    });
  });

  // ===========================================================================
  // 3. Navigation wiring — AppScreen enum includes GRN and Purchase Bills
  // ===========================================================================
  group('Bug Condition B — GRN/Bill navigation is wired', () {
    final appScreensSrc = _readSource('lib/core/navigation/app_screens.dart');

    test('AppScreen enum includes hardwareGrn', () {
      expect(
        appScreensSrc.contains('hardwareGrn'),
        isTrue,
        reason:
            'COUNTEREXAMPLE (3.2): AppScreen enum does not include hardwareGrn '
            '— GRN is not a recognised in-shell navigation target.',
      );
    });

    test('AppScreen enum includes hardwarePurchaseBills', () {
      expect(
        appScreensSrc.contains('hardwarePurchaseBills'),
        isTrue,
        reason:
            'COUNTEREXAMPLE (3.2): AppScreen enum does not include '
            'hardwarePurchaseBills — Purchase Bills is not a recognised '
            'in-shell navigation target.',
      );
    });
  });

  // ===========================================================================
  // 4. Sidebar navigation handler resolves GRN/Bill screens
  // ===========================================================================
  group('Bug Condition B — sidebar resolver wires GRN/Bill screens', () {
    final handlerSrc = _readSource(
      'lib/widgets/desktop/sidebar_navigation_handler.dart',
    );

    test('sidebar_navigation_handler.dart resolves hardware_grn', () {
      expect(
        handlerSrc.contains("case 'hardware_grn':"),
        isTrue,
        reason:
            'COUNTEREXAMPLE (3.2): sidebar_navigation_handler.dart does not '
            'have a case for hardware_grn — GRN screen is unreachable from '
            'the shell.',
      );
    });

    test('sidebar_navigation_handler.dart resolves hardware_purchase_bills', () {
      expect(
        handlerSrc.contains("case 'hardware_purchase_bills':"),
        isTrue,
        reason:
            'COUNTEREXAMPLE (3.2): sidebar_navigation_handler.dart does not '
            'have a case for hardware_purchase_bills — Purchase Bill screen is '
            'unreachable from the shell.',
      );
    });

    test('sidebar_navigation_handler imports HardwareGrnScreen', () {
      expect(
        handlerSrc.contains('hardware_grn_screen.dart'),
        isTrue,
        reason:
            'COUNTEREXAMPLE (3.2): sidebar_navigation_handler.dart does not '
            'import hardware_grn_screen.dart — cannot resolve GRN screen.',
      );
    });

    test('sidebar_navigation_handler imports HardwarePurchaseBillScreen', () {
      expect(
        handlerSrc.contains('hardware_purchase_bill_screen.dart'),
        isTrue,
        reason:
            'COUNTEREXAMPLE (3.2): sidebar_navigation_handler.dart does not '
            'import hardware_purchase_bill_screen.dart — cannot resolve '
            'Purchase Bill screen.',
      );
    });
  });

  // ===========================================================================
  // 5. Workspace integration — GRN/Bill cards present in workspace
  // ===========================================================================
  group('Bug Condition B — workspace screen includes GRN/Bill cards', () {
    final workspaceSrc = _readSource(
      'lib/features/hardware/presentation/screens/hardware_phase12_workspace_screen.dart',
    );

    test('workspace screen references HardwareGrnScreen', () {
      expect(
        workspaceSrc.contains('HardwareGrnScreen'),
        isTrue,
        reason:
            'COUNTEREXAMPLE (3.2): HardwarePhase12WorkspaceScreen does not '
            'reference HardwareGrnScreen — no GRN navigation from workspace.',
      );
    });

    test('workspace screen references HardwarePurchaseBillScreen', () {
      expect(
        workspaceSrc.contains('HardwarePurchaseBillScreen'),
        isTrue,
        reason:
            'COUNTEREXAMPLE (3.2): HardwarePhase12WorkspaceScreen does not '
            'reference HardwarePurchaseBillScreen — no Bill navigation from '
            'workspace.',
      );
    });

    test('workspace screen has Goods Receipt Notes card', () {
      expect(
        workspaceSrc.contains('Goods Receipt Notes'),
        isTrue,
        reason:
            'COUNTEREXAMPLE (3.2): workspace screen does not display a GRN '
            'section card.',
      );
    });

    test('workspace screen has Purchase Bills card', () {
      expect(
        workspaceSrc.contains('Purchase Bills'),
        isTrue,
        reason:
            'COUNTEREXAMPLE (3.2): workspace screen does not display a '
            'Purchase Bills section card.',
      );
    });
  });

  // ===========================================================================
  // 6. Command center integration — GRN/Bill cards present
  // ===========================================================================
  group('Bug Condition B — command center includes GRN/Bill cards', () {
    final ccSrc = _readSource(
      'lib/features/hardware/presentation/screens/hardware_command_center_screen.dart',
    );

    test('command center includes Goods Receipt Notes card', () {
      expect(
        ccSrc.contains('Goods Receipt Notes'),
        isTrue,
        reason:
            'COUNTEREXAMPLE (3.2): HardwareCommandCenterScreen does not '
            'include a GRN card — GRN is unreachable from the command center.',
      );
    });

    test('command center includes Purchase Bills card', () {
      expect(
        ccSrc.contains('Purchase Bills'),
        isTrue,
        reason:
            'COUNTEREXAMPLE (3.2): HardwareCommandCenterScreen does not '
            'include a Purchase Bills card — unreachable from command center.',
      );
    });

    test('command center references hardware_grn navId', () {
      expect(
        ccSrc.contains('hardware_grn'),
        isTrue,
        reason:
            'COUNTEREXAMPLE (3.2): command center does not reference '
            'hardware_grn navId — navigation target not configured.',
      );
    });

    test('command center references hardware_purchase_bills navId', () {
      expect(
        ccSrc.contains('hardware_purchase_bills'),
        isTrue,
        reason:
            'COUNTEREXAMPLE (3.2): command center does not reference '
            'hardware_purchase_bills navId.',
      );
    });
  });

  // ===========================================================================
  // 7. Preservation — existing PO methods remain unchanged
  // ===========================================================================
  group('Preservation — PO create/list unchanged', () {
    final repoSrc = _readSource(
      'lib/features/hardware/data/hardware_ops_repository.dart',
    );

    test('listPurchaseOrders method still exists', () {
      expect(
        repoSrc.contains('listPurchaseOrders()'),
        isTrue,
        reason: 'Preservation violated: listPurchaseOrders removed.',
      );
    });

    test('createPurchaseOrder method still exists', () {
      expect(
        repoSrc.contains('createPurchaseOrder('),
        isTrue,
        reason: 'Preservation violated: createPurchaseOrder removed.',
      );
    });

    test('listPurchaseOrdersAsMap method still exists', () {
      expect(
        repoSrc.contains('listPurchaseOrdersAsMap()'),
        isTrue,
        reason: 'Preservation violated: listPurchaseOrdersAsMap removed.',
      );
    });

    test('PO API path unchanged', () {
      final contractsSrc = _readSource(
        'lib/features/hardware/data/hardware_phase12_contracts.dart',
      );
      expect(
        contractsSrc.contains("'/hardware/purchase-orders'"),
        isTrue,
        reason: 'Preservation violated: PO API path changed.',
      );
    });
  });

  // ===========================================================================
  // 8. Pipeline completeness — PO → GRN → Purchase Bill flow is linked
  // ===========================================================================
  group('Pipeline completeness — PO → GRN → Bill', () {
    test('GRN screen references createGrn with purchaseOrderId', () {
      final src = _readSource(
        'lib/features/hardware/presentation/screens/hardware_grn_screen.dart',
      );
      expect(
        src.contains('purchaseOrderId') && src.contains('createGrn'),
        isTrue,
        reason:
            'COUNTEREXAMPLE (3.2): GRN screen does not link createGrn to a '
            'purchase order — pipeline broken at PO → GRN.',
      );
    });

    test('Purchase Bill screen references createPurchaseBill with grnId', () {
      final src = _readSource(
        'lib/features/hardware/presentation/screens/hardware_purchase_bill_screen.dart',
      );
      expect(
        src.contains('grnId') && src.contains('createPurchaseBill'),
        isTrue,
        reason:
            'COUNTEREXAMPLE (3.2): Purchase Bill screen does not link '
            'createPurchaseBill to a GRN — pipeline broken at GRN → Bill.',
      );
    });

    test('GRN screen has navigation to Purchase Bill', () {
      final src = _readSource(
        'lib/features/hardware/presentation/screens/hardware_grn_screen.dart',
      );
      // GRN cards should have an action to create/view a purchase bill
      expect(
        src.contains('PurchaseBill'),
        isTrue,
        reason:
            'COUNTEREXAMPLE (3.2): GRN screen has no link to Purchase Bill — '
            'pipeline broken at GRN → Bill navigation.',
      );
    });
  });
}
