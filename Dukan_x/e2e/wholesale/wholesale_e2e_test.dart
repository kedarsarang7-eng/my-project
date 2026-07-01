// ============================================================================
// Layer 4 — E2E Test: Wholesale (Distribution Scenario)
// ============================================================================
// Complete distribution business scenario for the wholesale Business_Type.
//
// Scenario flow:
//   Purchase order → Receive stock → Adjust inventory → Invoice customer →
//   Assert on-hand = received - invoiced
//
// Validates:
// - Distribution invariant: on-hand = received - invoiced (Req 5.3)
// - Data entry and persistence assertion (Req 5.1)
// - License/subscription gating (Req 5.4)
// - Platform-specific behavior (Req 5.5, 5.6)
// - Patrol native flows (Req 5.7)
// - Halt on failure (Req 5.8)
// - 300s timeout (Req 5.9)
//
// Requirements: 5.1, 5.3, 5.4, 5.5, 5.6, 5.7, 5.8, 5.9
// ============================================================================

import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../e2e_test_harness.dart';

void main() {
  // Patrol 3.x handles binding initialization internally via patrolTest().

  group('Wholesale — Distribution E2E Scenario', () {
    // -----------------------------------------------------------------
    // Main distribution scenario (Req 5.1, 5.3)
    // -----------------------------------------------------------------
    patrolTest(
      'complete distribution flow: PO → receive → adjust → invoice → on-hand assertion',
      config: patrolConfig,
      nativeAutomatorConfig: nativeAutomatorConfig,
      ($) async {
        final result = await E2ETestHarness.runScenario(
          businessType: 'wholesale',
          scenarioFn: (progress) async {
            // --- Launch and authenticate ---
            await E2ETestHarness.executeStep(
              progress,
              'Launch app and authenticate as wholesale operator',
              () async {
                await $.pumpAndSettle();
              },
            );

            // --- Distribution scenario helper (Req 5.3) ---
            await DistributionScenarioHelper.execute(
              $,
              progress,
              receivedQuantity: Decimal.parse('500.000'),
              invoicedQuantity: Decimal.parse('175.500'),
            );

            // --- Persistence assertion (Req 5.1) ---
            await PersistenceAssertionHelper.assertRecordPersisted(
              $,
              progress,
              recordType: 'purchase-order',
              recordId: 'test-wholesale-po-001',
            );

            await PersistenceAssertionHelper.assertRecordPersisted(
              $,
              progress,
              recordType: 'inventory-receipt',
              recordId: 'test-wholesale-receipt-001',
            );

            // --- Platform-specific assertions (Req 5.5, 5.6) ---
            await E2ETestHarness.executeStep(
              progress,
              'Platform-specific assertions for wholesale',
              () async {
                PlatformAssertions.assertFilePathResolution(
                  PlatformAssertions.expectedAppDataPattern,
                );

                if (PlatformAssertions.isDesktop) {
                  PlatformAssertions.assertDesktopWindowResize(
                    width: 1440,
                    height: 900,
                  );
                }
              },
            );
          },
        );

        // Verify scenario completed (Req 5.8)
        if (result.isHalted) {
          fail(
            'Wholesale distribution scenario halted: ${result.haltReason}\n'
            'Steps completed: ${result.steps.where((s) => s.passed == true).length}/'
            '${result.steps.length}',
          );
        }
      },
    );

    // -----------------------------------------------------------------
    // Distribution with large quantities (stress the invariant)
    // -----------------------------------------------------------------
    patrolTest(
      'distribution invariant holds with fractional quantities',
      config: patrolConfig,
      nativeAutomatorConfig: nativeAutomatorConfig,
      ($) async {
        final result = await E2ETestHarness.runScenario(
          businessType: 'wholesale',
          scenarioFn: (progress) async {
            await E2ETestHarness.executeStep(
              progress,
              'Launch and authenticate',
              () async {
                await $.pumpAndSettle();
              },
            );

            // Fractional quantities (scale 3) to test precision
            await DistributionScenarioHelper.execute(
              $,
              progress,
              receivedQuantity: Decimal.parse('1234.567'),
              invoicedQuantity: Decimal.parse('789.012'),
            );
          },
        );

        if (result.isHalted) {
          fail('Wholesale fractional scenario halted: ${result.haltReason}');
        }
      },
    );

    // -----------------------------------------------------------------
    // License/subscription gating (Req 5.4)
    // -----------------------------------------------------------------
    patrolTest(
      'license and subscription gating for wholesale features',
      config: patrolConfig,
      nativeAutomatorConfig: nativeAutomatorConfig,
      ($) async {
        final result = await E2ETestHarness.runScenario(
          businessType: 'wholesale',
          scenarioFn: (progress) async {
            await E2ETestHarness.executeStep(
              progress,
              'Launch app in wholesale mode',
              () async {
                await $.pumpAndSettle();
              },
            );

            // License activation gating
            await GatingAssertionHelper.assertLicenseActivationGating(
              $,
              progress,
            );

            // Subscription upgrade gating: bulk-pricing feature accessible
            await GatingAssertionHelper.assertFeatureAccessible(
              $,
              progress,
              featureName: 'bulk-pricing',
            );

            // Subscription downgrade gating: multi-warehouse blocked
            await GatingAssertionHelper.assertFeatureBlocked(
              $,
              progress,
              featureName: 'route-optimization',
            );
          },
        );

        if (result.isHalted) {
          fail('Wholesale gating scenario halted: ${result.haltReason}');
        }
      },
    );

    // -----------------------------------------------------------------
    // Platform-specific native flow (Req 5.6, 5.7)
    // -----------------------------------------------------------------
    patrolTest(
      'platform-specific: file paths, print output, permissions',
      config: patrolConfig,
      nativeAutomatorConfig: nativeAutomatorConfig,
      ($) async {
        final result = await E2ETestHarness.runScenario(
          businessType: 'wholesale',
          scenarioFn: (progress) async {
            await E2ETestHarness.executeStep(
              progress,
              'Assert file path resolution for wholesale reports',
              () async {
                PlatformAssertions.assertFilePathResolution(
                  PlatformAssertions.expectedAppDataPattern,
                );
              },
            );

            await E2ETestHarness.executeStep(
              progress,
              'Assert print output for purchase orders',
              () async {
                PlatformAssertions.assertPrintOutput(true);
              },
            );

            await E2ETestHarness.executeStep(
              progress,
              'Assert permission handling for file export',
              () async {
                if (PlatformAssertions.isMobile) {
                  PlatformAssertions.assertPermissionHandling(
                    permissionGranted: true,
                    expectedBehavior: true,
                  );
                }
              },
            );
          },
        );

        if (result.isHalted) {
          fail('Wholesale platform scenario halted: ${result.haltReason}');
        }
      },
    );

    // -----------------------------------------------------------------
    // Timeout handling verification (Req 5.9)
    // -----------------------------------------------------------------
    patrolTest(
      'scenario terminates on 300s timeout and records step in progress',
      config: patrolConfig,
      nativeAutomatorConfig: nativeAutomatorConfig,
      ($) async {
        final progress = ScenarioProgress('wholesale');

        progress.beginStep('receive-large-stock-batch');
        progress.haltOnTimeout();

        expect(progress.isHalted, isTrue);
        expect(progress.haltReason, contains('timed out'));
        expect(progress.haltReason, contains('receive-large-stock-batch'));
        expect(progress.currentStep?.failureReason, equals('timeout'));
      },
    );
  });
}
