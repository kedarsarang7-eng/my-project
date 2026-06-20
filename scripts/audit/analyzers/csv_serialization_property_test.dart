/// Property-Based Test: CSV Serialization with Priority Logic (Property 3)
///
/// For any valid ScreenEntry, serializing to CSV and parsing back SHALL produce
/// an equivalent entry. Additionally, priority assignment matches the rules:
/// - Dashboards/entry-points → High
/// - Standard feature screens with navWired → Medium
/// - All others → Low
///
/// **Validates: Requirements 1.3**
library;

import 'dart:math';

import '../models/screen_entry.dart';
import 'screen_discovery.dart';

void main() {
  print('=== Property 3: CSV Serialization with Priority Logic ===\n');

  final engine = ScreenDiscoveryEngine();
  final random = Random(42);
  var passed = 0;
  const iterations = 100;

  for (var i = 0; i < iterations; i++) {
    final entry = _generateScreenEntry(random);

    // Test 1: CSV round-trip produces equivalent entry
    final csvRow = entry.toCsvRow();
    final parsed = ScreenEntry.fromCsvRow(csvRow);

    assert(
      entry == parsed,
      'Iteration $i: CSV round-trip failed.\n'
      '  Original: $entry\n'
      '  Parsed:   $parsed\n'
      '  CSV row:  $csvRow',
    );

    // Test 2: Priority assignment matches rules
    final assignedPriority = engine.assignPriority(entry);
    final fileNameLower = entry.fileName.toLowerCase();

    if (fileNameLower.contains('dashboard') ||
        fileNameLower.contains('home') ||
        fileNameLower.contains('main')) {
      assert(
        assignedPriority == Priority.high,
        'Iteration $i: Expected High priority for dashboard/home/main file "${entry.fileName}" '
        'but got ${assignedPriority.label}',
      );
    } else if (entry.navWired) {
      assert(
        assignedPriority == Priority.medium,
        'Iteration $i: Expected Medium priority for navWired screen "${entry.fileName}" '
        'but got ${assignedPriority.label}',
      );
    } else {
      assert(
        assignedPriority == Priority.low,
        'Iteration $i: Expected Low priority for "${entry.fileName}" (navWired=false) '
        'but got ${assignedPriority.label}',
      );
    }

    passed++;
  }

  print(
    '✓ Property 3: CSV Serialization with Priority — $passed/$iterations iterations passed',
  );
}

// ─── Test data generation ──────────────────────────────────────────────────

ScreenEntry _generateScreenEntry(Random random) {
  final fileName = _randomFileName(random);
  final feature = _randomFeature(random);
  final navWired = random.nextBool();
  final mockData = random.nextBool();
  final priority = Priority.values[random.nextInt(Priority.values.length)];

  return ScreenEntry(
    project: 'Dukan_x',
    feature: feature,
    fileName: fileName,
    relativePath: 'lib/features/$feature/presentation/screens/$fileName',
    businessTypes: feature,
    mockData: mockData,
    mockReasons: mockData ? _randomMockReasons(random) : '',
    apiConnected: random.nextBool(),
    offlineReady: random.nextBool(),
    uiConsistent: random.nextBool(),
    navWired: navWired,
    priority: priority,
    status: _randomStatus(random),
    statusReason: _randomReason(random),
    statusTimestamp:
        '2025-01-${(random.nextInt(28) + 1).toString().padLeft(2, '0')}T10:00:00Z',
  );
}

String _randomFileName(Random random) {
  // Mix of dashboard/home/main (→ High) and regular names
  const dashboardNames = [
    'dashboard_screen.dart',
    'home_screen.dart',
    'main_screen.dart',
  ];
  const regularNames = [
    'order_screen.dart',
    'menu_screen.dart',
    'settings_page.dart',
    'profile_screen.dart',
    'invoice_screen.dart',
    'report_screen.dart',
    'list_screen.dart',
    'detail_page.dart',
  ];

  // 30% chance of dashboard name to ensure good coverage of High priority
  if (random.nextInt(10) < 3) {
    return dashboardNames[random.nextInt(dashboardNames.length)];
  }
  return regularNames[random.nextInt(regularNames.length)];
}

String _randomFeature(Random random) {
  const features = ['restaurant', 'billing', 'pharmacy', 'jewellery', 'clinic'];
  return features[random.nextInt(features.length)];
}

String _randomMockReasons(Random random) {
  const reasons = [
    'hardcoded_array',
    'todo_placeholder',
    'mock_import',
    'inline_literal',
  ];
  final count = random.nextInt(3) + 1;
  final selected = <String>{};
  for (var i = 0; i < count; i++) {
    selected.add(reasons[random.nextInt(reasons.length)]);
  }
  return selected.join(',');
}

String _randomStatus(Random random) {
  const statuses = [
    'Not Started',
    'In Progress',
    'Remediated',
    'Validated',
    'Blocked',
  ];
  return statuses[random.nextInt(statuses.length)];
}

String _randomReason(Random random) {
  const reasons = [
    'Initial scan',
    'API connected',
    'Mock removed',
    'Validated OK',
    'Blocked by API',
  ];
  return reasons[random.nextInt(reasons.length)];
}
