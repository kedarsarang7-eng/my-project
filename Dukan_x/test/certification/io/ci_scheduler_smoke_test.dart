// CI/Scheduler Smoke Tests
// Validates: Requirements 8.1, 8.4, 8.5
//
// Asserts:
// - The regression trigger fires within 10 min of commit (structural: timeout-minutes <= 10)
// - The nightly 24-hour schedule exists (cron or schedule trigger)
// - Each test suite resides under its required root directory

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Resolves the workspace root (Dukan_x/) regardless of where tests are run from.
Directory _findDukanRoot() {
  // Start from the test file's location and walk up to find pubspec.yaml
  var dir = Directory.current;
  while (dir.path != dir.parent.path) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) {
      return dir;
    }
    dir = dir.parent;
  }
  // Fallback: assume we're already at Dukan_x root
  return Directory.current;
}

void main() {
  late Directory root;

  setUpAll(() {
    root = _findDukanRoot();
  });

  group('Layer directory roots (Req 8.5 — suite placement)', () {
    test('test/unit/ directory exists (Layer 1 root)', () {
      final unitDir = Directory('${root.path}/test/unit');
      expect(
        unitDir.existsSync(),
        isTrue,
        reason: 'Layer 1 unit test root test/unit/ must exist',
      );
    });

    test('test/widget/ directory exists (Layer 2 root)', () {
      final widgetDir = Directory('${root.path}/test/widget');
      expect(
        widgetDir.existsSync(),
        isTrue,
        reason: 'Layer 2 widget test root test/widget/ must exist',
      );
    });

    test('integration_test/ directory exists (Layer 3 root)', () {
      final integrationDir = Directory('${root.path}/integration_test');
      expect(
        integrationDir.existsSync(),
        isTrue,
        reason: 'Layer 3 integration test root integration_test/ must exist',
      );
    });

    test('e2e/ directory exists (Layer 4 root)', () {
      final e2eDir = Directory('${root.path}/e2e');
      expect(
        e2eDir.existsSync(),
        isTrue,
        reason: 'Layer 4 E2E test root e2e/ must exist',
      );
    });
  });

  group('CI workflow configuration (Req 8.1, 8.4, 8.5)', () {
    late Directory workflowsDir;
    late List<File> workflowFiles;

    setUpAll(() {
      workflowsDir = Directory('${root.path}/.github/workflows');
      if (workflowsDir.existsSync()) {
        workflowFiles = workflowsDir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.yml') || f.path.endsWith('.yaml'))
            .toList();
      } else {
        workflowFiles = [];
      }
    });

    test(
      '.github/workflows/ contains a CI file that references regression testing',
      () {
        expect(
          workflowsDir.existsSync(),
          isTrue,
          reason: '.github/workflows/ directory must exist',
        );
        expect(
          workflowFiles,
          isNotEmpty,
          reason: 'At least one workflow YAML file must exist',
        );

        // Find a workflow that references regression
        final hasRegression = workflowFiles.any((file) {
          final content = file.readAsStringSync().toLowerCase();
          return content.contains('regression');
        });
        expect(
          hasRegression,
          isTrue,
          reason:
              'At least one CI workflow must reference regression testing (Req 8.1)',
        );
      },
    );

    test(
      'CI workflow has a nightly schedule (cron or schedule trigger) — Req 8.5',
      () {
        // At least one workflow file must have a schedule/cron trigger
        final hasSchedule = workflowFiles.any((file) {
          final content = file.readAsStringSync();
          return content.contains('schedule') && content.contains('cron');
        });
        expect(
          hasSchedule,
          isTrue,
          reason:
              'At least one CI workflow must have a nightly schedule (cron) trigger (Req 8.5)',
        );

        // Additionally verify the cron pattern implies a 24-hour cycle
        final scheduleFile = workflowFiles.firstWhere((file) {
          final content = file.readAsStringSync();
          return content.contains('schedule') && content.contains('cron');
        });
        final content = scheduleFile.readAsStringSync();
        // A daily cron has exactly 5 fields; check it runs once per day
        // Pattern: minute hour * * * (runs daily)
        final cronRegex = RegExp(r"cron:\s*'(\d+\s+\d+\s+\*\s+\*\s+\*)'");
        final match = cronRegex.firstMatch(content);
        expect(
          match,
          isNotNull,
          reason:
              'Nightly cron must be a daily pattern (min hour * * *) for 24-hour cycle',
        );
      },
    );

    test('CI workflow triggers on push/PR (within 10 min of commit) — Req 8.1', () {
      // Find the regression workflow and verify it triggers on push or pull_request
      final regressionFile = workflowFiles.firstWhere(
        (file) {
          final content = file.readAsStringSync().toLowerCase();
          return content.contains('regression');
        },
        orElse: () =>
            throw TestFailure('No workflow file references regression testing'),
      );

      final content = regressionFile.readAsStringSync();

      // Check push or pull_request trigger
      final hasPushTrigger =
          content.contains('push:') || content.contains('pull_request:');
      expect(
        hasPushTrigger,
        isTrue,
        reason:
            'Regression workflow must trigger on push or pull_request (Req 8.1)',
      );

      // Structural check: the workflow's timeout-minutes must be <= 10
      // to satisfy "within 10 minutes of commit"
      final timeoutRegex = RegExp(r'timeout-minutes:\s*(\d+)');
      final timeoutMatch = timeoutRegex.firstMatch(content);
      expect(
        timeoutMatch,
        isNotNull,
        reason:
            'Regression workflow must declare timeout-minutes for the 10-min SLA',
      );
      final timeout = int.parse(timeoutMatch!.group(1)!);
      expect(
        timeout,
        lessThanOrEqualTo(10),
        reason: 'Regression workflow timeout must be ≤ 10 minutes (Req 8.1)',
      );
    });
  });
}
