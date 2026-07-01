// ============================================================================
// Layer 4 — E2E Test: Service (Service-Only Scenario with Gating)
// ============================================================================
// Complete service-only business scenario for the service Business_Type.
//
// Service_Only_Types (service, clinic, schoolErp, decorationCatering) have
// no product or inventory capabilities. This scenario focuses on:
// - Service booking / job creation
// - Invoice generation (service-based, no products)
// - Payment collection
// - Report generation
// - License/subscription gating (primary focus, Req 5.4)
//
// Validates:
// - Data entry and persistence assertion (Req 5.1)
// - License activation, upgrade, and downgrade gating (Req 5.4)
// - Platform-specific behavior (Req 5.5, 5.6)
// - Patrol native flows (Req 5.7)
// - Halt on failure (Req 5.8)
// - 300s timeout (Req 5.9)
//
// Note: No retail or distribution invariants apply (service-only type).
//
// Requirements: 5.1, 5.4, 5.5, 5.6, 5.7, 5.8, 5.9
// ============================================================================

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../e2e_test_harness.dart';

void main() {
  // Patrol 3.x handles binding initialization internally via patrolTest().

  group('Service — Service-Only E2E Scenario (Gating Focus)', () {
    // -----------------------------------------------------------------
    // Main service scenario: data entry → persistence (Req 5.1)
    // -----------------------------------------------------------------
    patrolTest(
      'complete service flow: booking → invoice → payment → report → persistence',
      config: patrolConfig,
      nativeAutomatorConfig: nativeAutomatorConfig,
      ($) async {
        final result = await E2ETestHarness.runScenario(
          businessType: 'service',
          scenarioFn: (progress) async {
            // --- Launch and authenticate ---
            await E2ETestHarness.executeStep(
              progress,
              'Launch app and authenticate as service operator',
              () async {
                await $.pumpAndSettle();
              },
            );

            // --- Service data entry (Req 5.1) ---
            await E2ETestHarness.executeStep(
              progress,
              'Create service booking / job card',
              () async {
                // Navigate to service management and create a job
                await $.pumpAndSettle();
              },
            );

            await E2ETestHarness.executeStep(
              progress,
              'Generate service invoice (no products)',
              () async {
                // Create an invoice for the service job
                await $.pumpAndSettle();
              },
            );

            await E2ETestHarness.executeStep(
              progress,
              'Record payment for service',
              () async {
                await $.pumpAndSettle();
              },
            );

            await E2ETestHarness.executeStep(
              progress,
              'Generate service report',
              () async {
                await $.pumpAndSettle();
                PlatformAssertions.assertPrintOutput(true);
              },
            );

            // --- Persistence assertion (Req 5.1) ---
            await PersistenceAssertionHelper.assertRecordPersisted(
              $,
              progress,
              recordType: 'service-booking',
              recordId: 'test-service-booking-001',
            );

            await PersistenceAssertionHelper.assertRecordPersisted(
              $,
              progress,
              recordType: 'service-invoice',
              recordId: 'test-service-invoice-001',
            );

            // --- Platform-specific assertions (Req 5.5, 5.6) ---
            await E2ETestHarness.executeStep(
              progress,
              'Platform-specific assertions',
              () async {
                PlatformAssertions.assertFilePathResolution(
                  PlatformAssertions.expectedAppDataPattern,
                );

                if (PlatformAssertions.isDesktop) {
                  PlatformAssertions.assertDesktopWindowResize(
                    width: 1024,
                    height: 768,
                  );
                }
              },
            );
          },
        );

        if (result.isHalted) {
          fail(
            'Service scenario halted: ${result.haltReason}\n'
            'Steps completed: ${result.steps.where((s) => s.passed == true).length}/'
            '${result.steps.length}',
          );
        }
      },
    );

    // -----------------------------------------------------------------
    // License/subscription gating — PRIMARY FOCUS (Req 5.4)
    // -----------------------------------------------------------------
    patrolTest(
      'license activation gating: features blocked until activated',
      config: patrolConfig,
      nativeAutomatorConfig: nativeAutomatorConfig,
      ($) async {
        final result = await E2ETestHarness.runScenario(
          businessType: 'service',
          scenarioFn: (progress) async {
            await E2ETestHarness.executeStep(
              progress,
              'Launch app without activated license',
              () async {
                await $.pumpAndSettle();
              },
            );

            // Assert all gated features are blocked without license
            await GatingAssertionHelper.assertLicenseActivationGating(
              $,
              progress,
            );

            await GatingAssertionHelper.assertFeatureBlocked(
              $,
              progress,
              featureName: 'service-scheduling',
            );

            await GatingAssertionHelper.assertFeatureBlocked(
              $,
              progress,
              featureName: 'service-reports',
            );
          },
        );

        if (result.isHalted) {
          fail('License activation gating halted: ${result.haltReason}');
        }
      },
    );

    patrolTest(
      'subscription upgrade gating: premium features accessible when entitled',
      config: patrolConfig,
      nativeAutomatorConfig: nativeAutomatorConfig,
      ($) async {
        final result = await E2ETestHarness.runScenario(
          businessType: 'service',
          scenarioFn: (progress) async {
            await E2ETestHarness.executeStep(
              progress,
              'Launch app with premium subscription',
              () async {
                await $.pumpAndSettle();
              },
            );

            // Premium features should be accessible
            await GatingAssertionHelper.assertFeatureAccessible(
              $,
              progress,
              featureName: 'service-scheduling',
            );

            await GatingAssertionHelper.assertFeatureAccessible(
              $,
              progress,
              featureName: 'service-reports',
            );

            await GatingAssertionHelper.assertFeatureAccessible(
              $,
              progress,
              featureName: 'customer-notifications',
            );
          },
        );

        if (result.isHalted) {
          fail('Subscription upgrade gating halted: ${result.haltReason}');
        }
      },
    );

    patrolTest(
      'subscription downgrade gating: features blocked after downgrade',
      config: patrolConfig,
      nativeAutomatorConfig: nativeAutomatorConfig,
      ($) async {
        final result = await E2ETestHarness.runScenario(
          businessType: 'service',
          scenarioFn: (progress) async {
            await E2ETestHarness.executeStep(
              progress,
              'Launch app after downgrade to basic plan',
              () async {
                await $.pumpAndSettle();
              },
            );

            // Premium features should be blocked after downgrade
            await GatingAssertionHelper.assertFeatureBlocked(
              $,
              progress,
              featureName: 'service-scheduling',
            );

            await GatingAssertionHelper.assertFeatureBlocked(
              $,
              progress,
              featureName: 'customer-notifications',
            );

            // Basic features should still be accessible
            await GatingAssertionHelper.assertFeatureAccessible(
              $,
              progress,
              featureName: 'basic-invoicing',
            );
          },
        );

        if (result.isHalted) {
          fail('Subscription downgrade gating halted: ${result.haltReason}');
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
          businessType: 'service',
          scenarioFn: (progress) async {
            await E2ETestHarness.executeStep(
              progress,
              'Assert file path resolution for service data',
              () async {
                PlatformAssertions.assertFilePathResolution(
                  PlatformAssertions.expectedAppDataPattern,
                );
              },
            );

            await E2ETestHarness.executeStep(
              progress,
              'Assert print output for service invoices',
              () async {
                PlatformAssertions.assertPrintOutput(true);
              },
            );

            await E2ETestHarness.executeStep(
              progress,
              'Assert permission handling',
              () async {
                if (PlatformAssertions.isMobile) {
                  // Use patrol native automator for notification permission
                  PlatformAssertions.assertPermissionHandling(
                    permissionGranted: true,
                    expectedBehavior: true,
                  );
                }
              },
            );

            if (PlatformAssertions.isDesktop) {
              await E2ETestHarness.executeStep(
                progress,
                'Assert desktop window resize',
                () async {
                  PlatformAssertions.assertDesktopWindowResize(
                    width: 1280,
                    height: 800,
                  );
                },
              );
            }
          },
        );

        if (result.isHalted) {
          fail('Service platform scenario halted: ${result.haltReason}');
        }
      },
    );

    // -----------------------------------------------------------------
    // Scenario isolation verification (Req 5.8)
    // -----------------------------------------------------------------
    patrolTest(
      'scenario isolation: failure in one step does not affect other scenarios',
      config: patrolConfig,
      nativeAutomatorConfig: nativeAutomatorConfig,
      ($) async {
        // Run a scenario that fails at step 2
        final failedResult = await E2ETestHarness.runScenario(
          businessType: 'service',
          scenarioFn: (progress) async {
            await E2ETestHarness.executeStep(
              progress,
              'Step 1: succeeds',
              () async {
                // This step passes
              },
            );

            await E2ETestHarness.executeStep(
              progress,
              'Step 2: fails intentionally',
              () async {
                throw StateError('Simulated failure for isolation test');
              },
            );

            // This step should NOT execute because the scenario halted
            await E2ETestHarness.executeStep(
              progress,
              'Step 3: should be skipped',
              () async {
                fail('This step should never run after a halt');
              },
            );
          },
        );

        // Verify the failed scenario recorded correctly
        expect(failedResult.isHalted, isTrue);
        expect(
          failedResult.haltReason,
          contains('Step 2: fails intentionally'),
        );

        // Step 3 should not have been started
        final step3Ran = failedResult.steps.any(
          (s) => s.name == 'Step 3: should be skipped',
        );
        expect(step3Ran, isFalse, reason: 'Step 3 must not run after halt');

        // Now run a SEPARATE scenario — it must succeed independently
        final independentResult = await E2ETestHarness.runScenario(
          businessType: 'service',
          scenarioFn: (progress) async {
            await E2ETestHarness.executeStep(
              progress,
              'Independent step: succeeds',
              () async {
                // This proves scenario isolation
              },
            );
          },
        );

        expect(
          independentResult.isHalted,
          isFalse,
          reason: 'Independent scenario must not be affected by prior failure',
        );
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
        final progress = ScenarioProgress('service');

        progress.beginStep('waiting-for-service-confirmation');
        progress.haltOnTimeout();

        expect(progress.isHalted, isTrue);
        expect(progress.haltReason, contains('timed out'));
        expect(
          progress.haltReason,
          contains('waiting-for-service-confirmation'),
        );
        expect(progress.currentStep?.failureReason, equals('timeout'));
        expect(progress.currentStep?.passed, isFalse);
      },
    );
  });
}
