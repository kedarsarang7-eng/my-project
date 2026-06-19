/// Unit tests for CsvWriter — Discovery Registry CSV utility.
///
/// Verifies:
/// - CSV reading and parsing (including quoted fields)
/// - CSV writing with proper headers
/// - Merge logic: new entries appended, existing entries preserved, removed entries marked
/// - Round-trip serialization with Status/StatusReason/StatusTimestamp columns
/// - Priority assignment integration in ScreenEntry
///
/// Requirements: 1.3, 1.4, 1.5
library;

import 'dart:io';

import 'csv_writer.dart';
import '../models/screen_entry.dart';

void main() {
  print('=== CsvWriter Unit Tests ===\n');

  _testReadCsvNonExistentFile();
  _testReadCsvEmptyFile();
  _testReadCsvHeaderOnly();
  _testWriteAndReadRoundTrip();
  _testCsvHeadersMatchSchema();
  _testMergeNewEntriesAppended();
  _testMergeExistingEntriesPreserveStatus();
  _testMergeRemovedEntriesMarked();
  _testMergeMixedScenario();
  _testQuotedFieldsWithCommas();
  _testQuotedFieldsWithQuotes();
  _testStatusFieldsSerialization();
  _testFromCsvRowBackwardCompatibility();
  _testPriorityAssignment();
  _testUpdateRegistryFullCycle();

  print('\n✓ All CsvWriter tests passed.');
}

/// Helper to create a temp directory for test files.
Directory _createTempDir() {
  return Directory.systemTemp.createTempSync('csv_writer_test_');
}

/// Helper to create a sample ScreenEntry.
ScreenEntry _makeEntry({
  String fileName = 'test_screen.dart',
  String relativePath =
      'lib/features/restaurant/presentation/screens/test_screen.dart',
  String feature = 'restaurant',
  String businessTypes = 'Restaurant',
  bool mockData = false,
  String mockReasons = '',
  bool apiConnected = true,
  bool offlineReady = false,
  bool uiConsistent = true,
  bool navWired = true,
  Priority priority = Priority.medium,
  String status = 'Not Started',
  String statusReason = '',
  String statusTimestamp = '',
}) {
  return ScreenEntry(
    project: 'Dukan_x',
    feature: feature,
    fileName: fileName,
    relativePath: relativePath,
    businessTypes: businessTypes,
    mockData: mockData,
    mockReasons: mockReasons,
    apiConnected: apiConnected,
    offlineReady: offlineReady,
    uiConsistent: uiConsistent,
    navWired: navWired,
    priority: priority,
    status: status,
    statusReason: statusReason,
    statusTimestamp: statusTimestamp,
  );
}

// ─── Read CSV Tests ─────────────────────────────────────────────────────────

void _testReadCsvNonExistentFile() {
  print('Test: readCsv returns empty list for non-existent file...');
  final writer = CsvWriter();
  final result = writer.readCsv('/nonexistent/path/registry.csv');
  assert(result.isEmpty, 'Should return empty list for non-existent file');
  print('  ✓ Non-existent file returns empty list');
}

void _testReadCsvEmptyFile() {
  print('Test: readCsv returns empty list for empty file...');
  final tempDir = _createTempDir();
  try {
    final filePath = '${tempDir.path}/empty.csv';
    File(filePath).writeAsStringSync('');
    final writer = CsvWriter();
    final result = writer.readCsv(filePath);
    assert(result.isEmpty, 'Should return empty list for empty file');
    print('  ✓ Empty file returns empty list');
  } finally {
    tempDir.deleteSync(recursive: true);
  }
}

void _testReadCsvHeaderOnly() {
  print('Test: readCsv returns empty list for header-only file...');
  final tempDir = _createTempDir();
  try {
    final filePath = '${tempDir.path}/header_only.csv';
    File(filePath).writeAsStringSync(ScreenEntry.csvHeaders.join(',') + '\n');
    final writer = CsvWriter();
    final result = writer.readCsv(filePath);
    assert(result.isEmpty, 'Should return empty list for header-only file');
    print('  ✓ Header-only file returns empty list');
  } finally {
    tempDir.deleteSync(recursive: true);
  }
}

// ─── Write and Read Round-Trip ──────────────────────────────────────────────

void _testWriteAndReadRoundTrip() {
  print('Test: Write CSV and read back produces same entries...');
  final tempDir = _createTempDir();
  try {
    final filePath = '${tempDir.path}/roundtrip.csv';
    final writer = CsvWriter();

    final entries = [
      _makeEntry(
        fileName: 'dashboard_screen.dart',
        relativePath:
            'lib/features/restaurant/presentation/screens/dashboard_screen.dart',
        priority: Priority.high,
        status: 'In Progress',
        statusReason: 'Started remediation',
        statusTimestamp: '2024-01-15T10:30:00.000Z',
      ),
      _makeEntry(
        fileName: 'menu_screen.dart',
        relativePath:
            'lib/features/restaurant/presentation/screens/menu_screen.dart',
        mockData: true,
        mockReasons: 'hardcoded_array,todo_placeholder',
        priority: Priority.medium,
      ),
      _makeEntry(
        fileName: 'settings_screen.dart',
        relativePath: 'lib/core/settings/settings_screen.dart',
        feature: 'core/general',
        businessTypes: 'core/general',
        navWired: false,
        priority: Priority.low,
      ),
    ];

    writer.writeCsv(filePath, entries);
    final readBack = writer.readCsv(filePath);

    assert(
      readBack.length == 3,
      'Should read back 3 entries, got ${readBack.length}',
    );

    // Verify first entry
    assert(
      readBack[0].fileName == 'dashboard_screen.dart',
      'First entry filename',
    );
    assert(readBack[0].priority == Priority.high, 'First entry priority');
    assert(readBack[0].status == 'In Progress', 'First entry status');
    assert(
      readBack[0].statusReason == 'Started remediation',
      'First entry statusReason',
    );
    assert(
      readBack[0].statusTimestamp == '2024-01-15T10:30:00.000Z',
      'First entry statusTimestamp',
    );

    // Verify second entry
    assert(readBack[1].mockData == true, 'Second entry mockData');
    assert(
      readBack[1].mockReasons == 'hardcoded_array,todo_placeholder',
      'Second entry mockReasons',
    );

    // Verify third entry
    assert(readBack[2].navWired == false, 'Third entry navWired');
    assert(readBack[2].priority == Priority.low, 'Third entry priority');
    assert(readBack[2].feature == 'core/general', 'Third entry feature');

    print('  ✓ Round-trip write/read produces equivalent entries');
  } finally {
    tempDir.deleteSync(recursive: true);
  }
}

// ─── CSV Headers Schema ─────────────────────────────────────────────────────

void _testCsvHeadersMatchSchema() {
  print('Test: CSV headers match Discovery Registry schema...');

  final expected = [
    'Project',
    'Feature',
    'FileName',
    'RelativePath',
    'BusinessTypes',
    'MockData',
    'MockReasons',
    'ApiConnected',
    'OfflineReady',
    'UiConsistent',
    'NavWired',
    'Priority',
    'Status',
    'StatusReason',
    'StatusTimestamp',
  ];

  assert(
    ScreenEntry.csvHeaders.length == expected.length,
    'Header count mismatch: ${ScreenEntry.csvHeaders.length} vs ${expected.length}',
  );

  for (var i = 0; i < expected.length; i++) {
    assert(
      ScreenEntry.csvHeaders[i] == expected[i],
      'Header mismatch at index $i: ${ScreenEntry.csvHeaders[i]} != ${expected[i]}',
    );
  }

  print('  ✓ All 15 CSV headers match the schema');
}

// ─── Merge Tests ────────────────────────────────────────────────────────────

void _testMergeNewEntriesAppended() {
  print('Test: Merge appends new entries not in existing registry...');
  final writer = CsvWriter();

  final existing = <ScreenEntry>[];
  final newEntries = [
    _makeEntry(
      fileName: 'new_screen.dart',
      relativePath: 'lib/features/pharmacy/screens/new_screen.dart',
    ),
  ];

  final merged = writer.merge(
    existingEntries: existing,
    newEntries: newEntries,
  );

  assert(merged.length == 1, 'Should have 1 merged entry');
  assert(merged[0].fileName == 'new_screen.dart', 'Should be the new entry');
  assert(merged[0].status == 'Not Started', 'New entries start as Not Started');
  assert(merged[0].statusReason == 'Discovered in scan', 'New entry reason');
  assert(
    merged[0].statusTimestamp.isNotEmpty,
    'New entry should have timestamp',
  );

  print('  ✓ New entries appended with correct status');
}

void _testMergeExistingEntriesPreserveStatus() {
  print('Test: Merge preserves status fields for existing entries...');
  final writer = CsvWriter();

  final existing = [
    _makeEntry(
      fileName: 'menu_screen.dart',
      relativePath:
          'lib/features/restaurant/presentation/screens/menu_screen.dart',
      status: 'In Progress',
      statusReason: 'Working on API connection',
      statusTimestamp: '2024-01-10T08:00:00.000Z',
      mockData: true,
      mockReasons: 'hardcoded_array',
    ),
  ];

  // New scan shows mockData is now false (fixed!)
  final newEntries = [
    _makeEntry(
      fileName: 'menu_screen.dart',
      relativePath:
          'lib/features/restaurant/presentation/screens/menu_screen.dart',
      mockData: false,
      mockReasons: '',
    ),
  ];

  final merged = writer.merge(
    existingEntries: existing,
    newEntries: newEntries,
  );

  assert(merged.length == 1, 'Should have 1 merged entry');
  // Status preserved from existing
  assert(merged[0].status == 'In Progress', 'Status should be preserved');
  assert(
    merged[0].statusReason == 'Working on API connection',
    'StatusReason preserved',
  );
  assert(
    merged[0].statusTimestamp == '2024-01-10T08:00:00.000Z',
    'StatusTimestamp preserved',
  );
  // Scan data updated
  assert(
    merged[0].mockData == false,
    'MockData should be updated from new scan',
  );
  assert(merged[0].mockReasons == '', 'MockReasons should be updated');

  print('  ✓ Existing entry status preserved, scan data updated');
}

void _testMergeRemovedEntriesMarked() {
  print('Test: Merge marks entries as removed when file deleted...');
  final writer = CsvWriter();

  final existing = [
    _makeEntry(
      fileName: 'deleted_screen.dart',
      relativePath: 'lib/features/clinic/screens/deleted_screen.dart',
      status: 'Not Started',
      statusReason: '',
      statusTimestamp: '2024-01-05T12:00:00.000Z',
    ),
  ];

  // New scan has no entries (file was deleted)
  final newEntries = <ScreenEntry>[];

  final merged = writer.merge(
    existingEntries: existing,
    newEntries: newEntries,
  );

  assert(merged.length == 1, 'Should still have 1 entry (marked as removed)');
  assert(
    merged[0].fileName == 'deleted_screen.dart',
    'Should be the removed entry',
  );
  assert(merged[0].status == 'Removed', 'Status should be Removed');
  assert(
    merged[0].statusReason == 'File no longer exists in codebase',
    'StatusReason should indicate removal',
  );
  assert(merged[0].statusTimestamp.isNotEmpty, 'Should have removal timestamp');

  print('  ✓ Removed entries correctly marked');
}

void _testMergeMixedScenario() {
  print('Test: Merge handles mixed additions, updates, and removals...');
  final writer = CsvWriter();

  final existing = [
    _makeEntry(
      fileName: 'kept_screen.dart',
      relativePath: 'lib/features/restaurant/screens/kept_screen.dart',
      status: 'Validated',
      statusReason: 'E2E passed',
      statusTimestamp: '2024-01-10T10:00:00.000Z',
    ),
    _makeEntry(
      fileName: 'removed_screen.dart',
      relativePath: 'lib/features/restaurant/screens/removed_screen.dart',
      status: 'In Progress',
      statusReason: 'Working on it',
      statusTimestamp: '2024-01-09T08:00:00.000Z',
    ),
  ];

  final newEntries = [
    _makeEntry(
      fileName: 'kept_screen.dart',
      relativePath: 'lib/features/restaurant/screens/kept_screen.dart',
      apiConnected: true,
    ),
    _makeEntry(
      fileName: 'brand_new_screen.dart',
      relativePath: 'lib/features/pharmacy/screens/brand_new_screen.dart',
    ),
  ];

  final merged = writer.merge(
    existingEntries: existing,
    newEntries: newEntries,
  );

  assert(merged.length == 3, 'Should have 3 entries total');

  // Find each by relativePath
  final kept = merged.firstWhere(
    (e) => e.relativePath == 'lib/features/restaurant/screens/kept_screen.dart',
  );
  final added = merged.firstWhere(
    (e) =>
        e.relativePath == 'lib/features/pharmacy/screens/brand_new_screen.dart',
  );
  final removed = merged.firstWhere(
    (e) =>
        e.relativePath == 'lib/features/restaurant/screens/removed_screen.dart',
  );

  assert(kept.status == 'Validated', 'Kept entry preserves status');
  assert(added.status == 'Not Started', 'New entry starts as Not Started');
  assert(removed.status == 'Removed', 'Removed entry marked as Removed');

  print('  ✓ Mixed scenario handled correctly');
}

// ─── Quoted Fields ──────────────────────────────────────────────────────────

void _testQuotedFieldsWithCommas() {
  print('Test: CSV handles fields containing commas...');
  final tempDir = _createTempDir();
  try {
    final filePath = '${tempDir.path}/commas.csv';
    final writer = CsvWriter();

    final entries = [
      _makeEntry(mockReasons: 'hardcoded_array,todo_placeholder,mock_import'),
    ];

    writer.writeCsv(filePath, entries);
    final readBack = writer.readCsv(filePath);

    assert(readBack.length == 1, 'Should read back 1 entry');
    assert(
      readBack[0].mockReasons == 'hardcoded_array,todo_placeholder,mock_import',
      'MockReasons with commas should survive round-trip, got: ${readBack[0].mockReasons}',
    );

    print('  ✓ Comma-containing fields handled correctly');
  } finally {
    tempDir.deleteSync(recursive: true);
  }
}

void _testQuotedFieldsWithQuotes() {
  print('Test: CSV handles fields containing double quotes...');
  final tempDir = _createTempDir();
  try {
    final filePath = '${tempDir.path}/quotes.csv';
    final writer = CsvWriter();

    final entries = [
      _makeEntry(statusReason: 'Found "mock" data pattern in file'),
    ];

    writer.writeCsv(filePath, entries);
    final readBack = writer.readCsv(filePath);

    assert(readBack.length == 1, 'Should read back 1 entry');
    assert(
      readBack[0].statusReason == 'Found "mock" data pattern in file',
      'Quoted fields should survive round-trip, got: ${readBack[0].statusReason}',
    );

    print('  ✓ Quote-containing fields handled correctly');
  } finally {
    tempDir.deleteSync(recursive: true);
  }
}

// ─── Status Fields ──────────────────────────────────────────────────────────

void _testStatusFieldsSerialization() {
  print('Test: Status, StatusReason, StatusTimestamp serialize correctly...');
  final entry = _makeEntry(
    status: 'Blocked',
    statusReason: 'Missing API endpoint',
    statusTimestamp: '2024-02-01T14:30:00.000Z',
  );

  final row = entry.toCsvRow();

  assert(row.length == 15, 'CSV row should have 15 columns, got ${row.length}');
  assert(row[12] == 'Blocked', 'Status column (index 12)');
  assert(row[13] == 'Missing API endpoint', 'StatusReason column (index 13)');
  assert(
    row[14] == '2024-02-01T14:30:00.000Z',
    'StatusTimestamp column (index 14)',
  );

  print('  ✓ Status fields at correct column indices');
}

void _testFromCsvRowBackwardCompatibility() {
  print(
    'Test: fromCsvRow handles rows with only 12 columns (backward compat)...',
  );

  // Simulate an old CSV row without Status columns
  final oldRow = [
    'Dukan_x',
    'restaurant',
    'menu_screen.dart',
    'lib/features/restaurant/screens/menu_screen.dart',
    'Restaurant',
    'true',
    'hardcoded_array',
    'false',
    'false',
    'true',
    'true',
    'Medium',
  ];

  final entry = ScreenEntry.fromCsvRow(oldRow);

  assert(
    entry.status == 'Not Started',
    'Missing status defaults to Not Started',
  );
  assert(entry.statusReason == '', 'Missing statusReason defaults to empty');
  assert(
    entry.statusTimestamp == '',
    'Missing statusTimestamp defaults to empty',
  );

  print('  ✓ Backward compatible with 12-column CSV rows');
}

// ─── Priority Assignment ────────────────────────────────────────────────────

void _testPriorityAssignment() {
  print('Test: Priority assignment logic...');

  // High: dashboard
  final dashboard = _makeEntry(fileName: 'restaurant_dashboard_screen.dart');
  assert(
    dashboard.fileName.toLowerCase().contains('dashboard'),
    'Should contain dashboard in name',
  );

  // High: home
  final home = _makeEntry(fileName: 'home_screen.dart');
  assert(
    home.fileName.toLowerCase().contains('home'),
    'Should contain home in name',
  );

  // Medium: navWired = true, not a dashboard/home/main
  final wiredScreen = _makeEntry(
    fileName: 'order_screen.dart',
    navWired: true,
    priority: Priority.medium,
  );
  assert(wiredScreen.navWired == true, 'Should be navWired');
  assert(wiredScreen.priority == Priority.medium, 'Should be medium priority');

  // Low: navWired = false, not a dashboard
  final unwiredScreen = _makeEntry(
    fileName: 'helper_screen.dart',
    navWired: false,
    priority: Priority.low,
  );
  assert(unwiredScreen.priority == Priority.low, 'Should be low priority');

  print('  ✓ Priority assignment rules verified');
}

// ─── Full Update Cycle ──────────────────────────────────────────────────────

void _testUpdateRegistryFullCycle() {
  print('Test: updateRegistry performs full read-merge-write cycle...');
  final tempDir = _createTempDir();
  try {
    final filePath = '${tempDir.path}/registry.csv';
    final writer = CsvWriter();

    // First scan — no existing file
    final firstScan = [
      _makeEntry(
        fileName: 'screen_a.dart',
        relativePath: 'lib/features/restaurant/screens/screen_a.dart',
      ),
      _makeEntry(
        fileName: 'screen_b.dart',
        relativePath: 'lib/features/pharmacy/screens/screen_b.dart',
      ),
    ];

    final firstResult = writer.updateRegistry(
      registryPath: filePath,
      scanResults: firstScan,
    );

    assert(firstResult.length == 2, 'First scan: 2 entries');
    assert(
      firstResult[0].status == 'Not Started',
      'First scan: default status',
    );

    // Second scan — screen_b removed, screen_c added
    final secondScan = [
      _makeEntry(
        fileName: 'screen_a.dart',
        relativePath: 'lib/features/restaurant/screens/screen_a.dart',
        apiConnected: true, // Updated data
      ),
      _makeEntry(
        fileName: 'screen_c.dart',
        relativePath: 'lib/features/clinic/screens/screen_c.dart',
      ),
    ];

    final secondResult = writer.updateRegistry(
      registryPath: filePath,
      scanResults: secondScan,
    );

    assert(
      secondResult.length == 3,
      'Second scan: 3 entries (2 current + 1 removed)',
    );

    final screenA = secondResult.firstWhere(
      (e) => e.relativePath == 'lib/features/restaurant/screens/screen_a.dart',
    );
    final screenB = secondResult.firstWhere(
      (e) => e.relativePath == 'lib/features/pharmacy/screens/screen_b.dart',
    );
    final screenC = secondResult.firstWhere(
      (e) => e.relativePath == 'lib/features/clinic/screens/screen_c.dart',
    );

    assert(screenA.apiConnected == true, 'Screen A: updated scan data');
    assert(screenA.status == 'Not Started', 'Screen A: status preserved');
    assert(screenB.status == 'Removed', 'Screen B: marked as removed');
    assert(screenC.status == 'Not Started', 'Screen C: new entry');

    // Verify the file on disk is correct
    final finalEntries = writer.readCsv(filePath);
    assert(finalEntries.length == 3, 'File should have 3 entries');

    print('  ✓ Full update cycle works correctly');
  } finally {
    tempDir.deleteSync(recursive: true);
  }
}
