// ============================================================================
// EXPLORATION TEST — expected to FAIL on unfixed code. Failure = bug confirmed.
//
// Bug Condition (Property 23): Wired Backend Endpoints Are Reachable From a
// Real Flutter Call Site
//
// **Validates: Requirements 2.14**
//
// Context:
//   - The backend (my-backend) exposes restaurant-specific endpoints for:
//       1. restoSplitBill (RestaurantOpsRepository.splitBill)
//       2. serviceCharge (Bill.serviceCharge transmitted via bill save)
//       3. delivery tracking (getDeliveryTracking / updateDeliveryStatus / assignDeliveryRider)
//       4. combos (listCombos / createCombo / updateCombo / deleteCombo)
//       5. split payments (showSplitPaymentSheet / SplitPaymentResult → backend splitPayments array)
//
//   - Some of these endpoints are already wired into production code:
//       • restoSplitBill: called from bill_creation_screen_v2.dart (Task 17.3)
//       • serviceCharge: Bill.serviceCharge set in bill_creation_screen_v2.dart
//       • delivery tracking: called from restaurant_delivery_ops_screen.dart (Task 25)
//       • combos: called from restaurant_pricing_admin_screen.dart (Task 25)
//
//   - The remaining UNWIRED endpoint:
//       • split payments: split_payment_sheet.dart exists with full UI but is
//         NEVER imported or called from any production code in lib/
//
// This test asserts the CORRECT behavior (all 5 endpoint categories SHOULD
// have at least one call site in reachable production code). On UNFIXED code
// this FAILS because:
//   - split_payment_sheet.dart (showSplitPaymentSheet) is never imported
//     or invoked from any file under lib/features/restaurant/** or
//     lib/features/billing/presentation/screens/**
//
// COUNTEREXAMPLE (documented after first run):
//   The "split payments" endpoint category (showSplitPaymentSheet /
//   SplitPaymentResult) has ZERO call sites in production code. The widget
//   exists at lib/features/billing/presentation/widgets/split_payment_sheet.dart
//   but no file imports or invokes it — the backend splitPayments array is
//   never populated from a real Flutter call site.
//
// Run: flutter test test/features/restaurant/restaurant_backend_endpoint_reachability_test.dart
// ============================================================================
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Represents one backend endpoint category to verify reachability.
class EndpointCategory {
  final String name;
  final String description;

  /// Patterns to search for in production source code. At least ONE must match
  /// in at least ONE file under the allowed production directories.
  final List<String> searchPatterns;

  /// The source file(s) where the endpoint is defined/implemented.
  final String definitionFile;

  const EndpointCategory({
    required this.name,
    required this.description,
    required this.searchPatterns,
    required this.definitionFile,
  });
}

/// The fixed set of backend endpoint categories from Property 23.
const List<EndpointCategory> kEndpointCategories = [
  EndpointCategory(
    name: 'restoSplitBill',
    description:
        'RestaurantOpsRepository.splitBill — backend /resto/bills/{id}/split',
    searchPatterns: [
      // Call to the repository method (excluding its own definition)
      'restoOpsRepo.splitBill',
      '_repo.splitBill',
      'RestaurantOpsRepository().splitBill',
      'RestaurantOpsRepository.splitBill',
      'repo.splitBill(',
    ],
    definitionFile:
        'lib/features/restaurant/data/repositories/restaurant_ops_repository.dart',
  ),
  EndpointCategory(
    name: 'serviceCharge',
    description:
        'Bill.serviceCharge field set and transmitted (backend serviceChargeCents)',
    searchPatterns: [
      // The billing screen setting the service charge on the Bill
      'serviceCharge:',
      '_serviceChargeAmount',
      'serviceCharge =',
    ],
    definitionFile:
        'lib/features/restaurant/utils/restaurant_business_rules.dart',
  ),
  EndpointCategory(
    name: 'delivery tracking',
    description:
        'RestaurantOpsRepository.getDeliveryTracking / updateDeliveryStatus / assignDeliveryRider',
    searchPatterns: [
      'getDeliveryTracking',
      'updateDeliveryStatus',
      'assignDeliveryRider',
    ],
    definitionFile:
        'lib/features/restaurant/data/repositories/restaurant_ops_repository.dart',
  ),
  EndpointCategory(
    name: 'combos',
    description:
        'RestaurantOpsRepository.listCombos / createCombo / updateCombo / deleteCombo',
    searchPatterns: ['listCombos', 'createCombo', 'updateCombo', 'deleteCombo'],
    definitionFile:
        'lib/features/restaurant/data/repositories/restaurant_ops_repository.dart',
  ),
  EndpointCategory(
    name: 'split payments',
    description:
        'showSplitPaymentSheet / SplitPaymentResult — backend splitPayments array',
    searchPatterns: [
      'showSplitPaymentSheet',
      'SplitPaymentResult',
      'SplitTenderLine',
      'splitPayments',
    ],
    definitionFile:
        'lib/features/billing/presentation/widgets/split_payment_sheet.dart',
  ),
];

/// Production directories where call sites must exist (non-test, non-orphaned).
/// Excludes the endpoint definition file itself and test/.
const List<String> kProductionDirs = [
  'lib/features/restaurant',
  'lib/features/billing',
];

/// Recursively collect all .dart files under a directory.
List<File> _collectDartFiles(String dirPath) {
  final dir = Directory(dirPath);
  if (!dir.existsSync()) return const [];
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();
}

/// Check if a file contains any of the given patterns.
bool _fileContainsAny(File file, List<String> patterns) {
  final content = file.readAsStringSync();
  return patterns.any((p) => content.contains(p));
}

void main() {
  late List<File> productionFiles;

  setUpAll(() {
    // Collect all production .dart files under the allowed directories
    productionFiles = [];
    for (final dir in kProductionDirs) {
      productionFiles.addAll(_collectDartFiles(dir));
    }
    // Ensure we actually found some production files (sanity check)
    expect(
      productionFiles.isNotEmpty,
      isTrue,
      reason:
          'Test setup: must find production .dart files under $kProductionDirs',
    );
  });

  // ===========================================================================
  // GROUP 1: For each endpoint category, assert at least one call site exists
  //          in production code (excluding the endpoint definition file itself).
  //
  // On UNFIXED code: FAILS for "split payments" — no call site in production.
  // ===========================================================================
  group(
    'Property 23: Backend endpoints reachable from production code (Req 2.14)',
    () {
      for (final endpoint in kEndpointCategories) {
        test('"${endpoint.name}" has ≥1 call site in production code', () {
          // Filter out the definition file itself — we want call SITES, not
          // the definition.
          final definitionPath = endpoint.definitionFile.replaceAll('/', '\\');
          final definitionPathFwd = endpoint.definitionFile;

          final callSiteFiles = productionFiles.where((f) {
            final path = f.path.replaceAll('\\', '/');
            // Exclude the definition file
            if (path.endsWith(definitionPathFwd) ||
                f.path.endsWith(definitionPath)) {
              return false;
            }
            return _fileContainsAny(f, endpoint.searchPatterns);
          }).toList();

          expect(
            callSiteFiles.isNotEmpty,
            isTrue,
            reason:
                'COUNTEREXAMPLE (Property 23, Req 2.14): '
                'The "${endpoint.name}" endpoint category has ZERO call sites '
                'in production code under $kProductionDirs.\n\n'
                'Description: ${endpoint.description}\n'
                'Definition file: ${endpoint.definitionFile}\n'
                'Search patterns: ${endpoint.searchPatterns}\n\n'
                'The backend endpoint is defined and functional but no Flutter '
                'production code (widget, service, or screen) under '
                'lib/features/restaurant/** or lib/features/billing/** '
                'calls it — it is only referenced from test/** or not '
                'referenced at all.\n\n'
                'Expected: at least one reachable (non-test, non-orphaned) '
                'widget/service calls this endpoint.',
          );
        });
      }
    },
  );

  // ===========================================================================
  // GROUP 2: Verify that the endpoint definition files themselves exist
  //          (precondition — confirms endpoints are implemented).
  //
  // On UNFIXED code: PASSES — all endpoint implementations exist.
  // ===========================================================================
  group('Precondition: endpoint definition files exist', () {
    for (final endpoint in kEndpointCategories) {
      test('"${endpoint.name}" definition file exists', () {
        final file = File(endpoint.definitionFile);
        expect(
          file.existsSync(),
          isTrue,
          reason:
              'Endpoint definition file for "${endpoint.name}" must exist at '
              '${endpoint.definitionFile}',
        );
      });
    }
  });

  // ===========================================================================
  // GROUP 3: Verify that the endpoint is NOT only referenced from test/**
  //          (the specific bug condition — endpoints that exist only in tests).
  //
  // On UNFIXED code: FAILS for "split payments".
  // ===========================================================================
  group('Property 23: Endpoints not only referenced from test/ (Req 2.14)', () {
    test('"split payments" is NOT only in test/ or widget definition', () {
      // Specifically verify split_payment_sheet.dart is imported/used from
      // production billing/restaurant code (not just its own definition)
      final splitSheetFile = File(
        'lib/features/billing/presentation/widgets/split_payment_sheet.dart',
      );
      expect(
        splitSheetFile.existsSync(),
        isTrue,
        reason: 'split_payment_sheet.dart must exist as a precondition',
      );

      // Search for imports of split_payment_sheet in production files
      final importPattern = "split_payment_sheet";
      final callPattern = "showSplitPaymentSheet";

      final importers = productionFiles.where((f) {
        final path = f.path.replaceAll('\\', '/');
        // Exclude the definition file itself
        if (path.contains('split_payment_sheet.dart')) return false;
        final content = f.readAsStringSync();
        return content.contains(importPattern) || content.contains(callPattern);
      }).toList();

      expect(
        importers.isNotEmpty,
        isTrue,
        reason:
            'COUNTEREXAMPLE (Property 23, Req 2.14): '
            'split_payment_sheet.dart is NEVER imported or called from '
            'any production file under lib/features/restaurant/** or '
            'lib/features/billing/**.\n\n'
            'The widget exists at:\n'
            '  lib/features/billing/presentation/widgets/split_payment_sheet.dart\n'
            'It provides showSplitPaymentSheet() and SplitPaymentResult, '
            'which map to the backend splitPayments array '
            '(mobile.schema.ts → splitPayments[]).\n\n'
            'However, NO billing screen, restaurant screen, or service '
            'imports or invokes it — the multi-tender split payment flow '
            'is permanently unreachable for restaurant users.\n\n'
            'Expected: bill_creation_screen_v2.dart (or another billing '
            'screen) imports split_payment_sheet.dart and invokes '
            'showSplitPaymentSheet() to offer multi-tender payment.',
      );
    });
  });

  // ===========================================================================
  // GROUP 4: Sanity check — endpoints known to be wired DO have call sites.
  //          Validates test methodology is correct (no false positives).
  //
  // On UNFIXED code: PASSES for already-wired endpoints.
  // ===========================================================================
  group('Sanity: already-wired endpoints have call sites (methodology check)', () {
    test('"restoSplitBill" is called from bill_creation_screen_v2.dart', () {
      final billScreen = File(
        'lib/features/billing/presentation/screens/bill_creation_screen_v2.dart',
      );
      expect(billScreen.existsSync(), isTrue);
      final content = billScreen.readAsStringSync();
      // Task 17.3 wired splitBill from the billing screen
      expect(
        content.contains('splitBill'),
        isTrue,
        reason:
            'bill_creation_screen_v2.dart should call splitBill '
            '(wired in Task 17.3)',
      );
    });

    test(
      '"delivery tracking" is called from restaurant_delivery_ops_screen.dart',
      () {
        final screen = File(
          'lib/features/restaurant/presentation/screens/restaurant_delivery_ops_screen.dart',
        );
        expect(screen.existsSync(), isTrue);
        final content = screen.readAsStringSync();
        expect(
          content.contains('getDeliveryTracking') ||
              content.contains('updateDeliveryStatus') ||
              content.contains('assignDeliveryRider'),
          isTrue,
          reason:
              'restaurant_delivery_ops_screen.dart should call delivery '
              'tracking endpoints',
        );
      },
    );

    test('"combos" is called from restaurant_pricing_admin_screen.dart', () {
      final screen = File(
        'lib/features/restaurant/presentation/screens/restaurant_pricing_admin_screen.dart',
      );
      expect(screen.existsSync(), isTrue);
      final content = screen.readAsStringSync();
      expect(
        content.contains('listCombos') || content.contains('createCombo'),
        isTrue,
        reason:
            'restaurant_pricing_admin_screen.dart should call combo endpoints',
      );
    });
  });
}
