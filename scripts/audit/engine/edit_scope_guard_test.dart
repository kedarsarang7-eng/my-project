/// Unit tests for EditScopeGuard.verifyShared
///
/// Validates:
/// - Req 1.4: Records shared edits with consumer list
/// - Req 1.5: Exactly one pass/fail per consuming Business_Type
/// - Req 1.6: Any fail → BlockedItem + withholds Sign_Off
library;

import '../models/audit_engine_models.dart';
import 'edit_scope_guard.dart';

void main() {
  print('=== EditScopeGuard.verifyShared Unit Tests ===\n');

  _testAllConsumersPass();
  _testSomeConsumersFail();
  _testFailBecomesBlockedItem();
  _testMultipleFailsMultipleBlockedItems();
  _testDeduplicatesConsumers();
  _testStoresNoteInSharedImpactNotes();
  _testResetClearsSharedImpactNotes();
  _testDefaultVerifyPassesAll();
  _testEmptyConsumerList();
  _testWidgetPathPreserved();
  _testVerifyCallbackReceivesCorrectArgs();

  print('\n✓ All EditScopeGuard.verifyShared tests passed.');
}

void _testAllConsumersPass() {
  print('Test: All consumers pass → no blocked items...');
  final guard = EditScopeGuard();

  final consumers = [
    BusinessType.grocery,
    BusinessType.pharmacy,
    BusinessType.restaurant,
  ];

  final note = guard.verifyShared(
    'lib/widgets/shared_table.dart',
    consumers,
    verify: (path, consumer) => true,
  );

  // Exactly one result per consumer
  assert(
    note.consumerVerification.length == 3,
    'Expected 3 results, got ${note.consumerVerification.length}',
  );
  assert(
    note.consumerVerification[BusinessType.grocery] == true,
    'Grocery should pass',
  );
  assert(
    note.consumerVerification[BusinessType.pharmacy] == true,
    'Pharmacy should pass',
  );
  assert(
    note.consumerVerification[BusinessType.restaurant] == true,
    'Restaurant should pass',
  );

  // No blocked items when all pass
  assert(guard.blockedItems.isEmpty, 'No blocked items when all pass');

  print('  ✓ All consumers pass, no blocked items recorded');
}

void _testSomeConsumersFail() {
  print('Test: Some consumers fail → correct pass/fail per consumer...');
  final guard = EditScopeGuard();

  final consumers = [
    BusinessType.grocery,
    BusinessType.pharmacy,
    BusinessType.restaurant,
  ];

  final note = guard.verifyShared(
    'lib/core/theme/shared_button.dart',
    consumers,
    verify: (path, consumer) => consumer != BusinessType.pharmacy,
  );

  assert(note.consumerVerification.length == 3, 'Should have 3 results');
  assert(
    note.consumerVerification[BusinessType.grocery] == true,
    'Grocery should pass',
  );
  assert(
    note.consumerVerification[BusinessType.pharmacy] == false,
    'Pharmacy should fail',
  );
  assert(
    note.consumerVerification[BusinessType.restaurant] == true,
    'Restaurant should pass',
  );

  print('  ✓ Correct pass/fail recorded per consumer');
}

void _testFailBecomesBlockedItem() {
  print('Test: Any fail → BlockedItem identifying affected Business_Type...');
  final guard = EditScopeGuard();

  final consumers = [BusinessType.grocery, BusinessType.clinic];

  guard.verifyShared(
    'lib/widgets/data_list.dart',
    consumers,
    verify: (path, consumer) => consumer != BusinessType.clinic,
  );

  assert(
    guard.blockedItems.length == 1,
    'Expected 1 blocked item, got ${guard.blockedItems.length}',
  );
  final blocked = guard.blockedItems.first;
  assert(
    blocked.targetBusinessType == BusinessType.clinic,
    'Target should be clinic, got ${blocked.targetBusinessType}',
  );
  assert(
    blocked.blockingReason == 'external-dependency',
    'Reason should be external-dependency',
  );
  assert(
    blocked.missingArtifact == 'lib/widgets/data_list.dart',
    'Missing artifact should be the widget path',
  );

  print('  ✓ Failed consumer produces BlockedItem with correct target');
}

void _testMultipleFailsMultipleBlockedItems() {
  print('Test: Multiple fails produce one BlockedItem each...');
  final guard = EditScopeGuard();

  final consumers = [
    BusinessType.grocery,
    BusinessType.pharmacy,
    BusinessType.restaurant,
  ];

  guard.verifyShared(
    'lib/core/shared.dart',
    consumers,
    verify: (path, consumer) => false, // all fail
  );

  assert(
    guard.blockedItems.length == 3,
    'Expected 3 blocked items, got ${guard.blockedItems.length}',
  );
  final targetTypes = guard.blockedItems
      .map((b) => b.targetBusinessType)
      .toSet();
  assert(targetTypes.contains(BusinessType.grocery), 'Should contain grocery');
  assert(
    targetTypes.contains(BusinessType.pharmacy),
    'Should contain pharmacy',
  );
  assert(
    targetTypes.contains(BusinessType.restaurant),
    'Should contain restaurant',
  );

  print('  ✓ Each failed consumer has its own BlockedItem');
}

void _testDeduplicatesConsumers() {
  print('Test: Duplicate consumers are deduplicated (each appears once)...');
  final guard = EditScopeGuard();

  // Pass duplicates in the list
  final consumers = [
    BusinessType.grocery,
    BusinessType.grocery,
    BusinessType.pharmacy,
    BusinessType.pharmacy,
    BusinessType.pharmacy,
  ];

  int callCount = 0;
  final note = guard.verifyShared(
    'lib/widgets/dup_test.dart',
    consumers,
    verify: (path, consumer) {
      callCount++;
      return true;
    },
  );

  // Only 2 unique consumers
  assert(
    note.consumerVerification.length == 2,
    'Expected 2 unique results, got ${note.consumerVerification.length}',
  );
  assert(
    callCount == 2,
    'Verify callback should be called once per unique consumer, got $callCount',
  );

  print('  ✓ Duplicates removed, each consumer appears exactly once');
}

void _testStoresNoteInSharedImpactNotes() {
  print('Test: Notes stored in sharedImpactNotes getter...');
  final guard = EditScopeGuard();

  guard.verifyShared('lib/core/widget_a.dart', [
    BusinessType.electronics,
  ], verify: (_, __) => true);
  guard.verifyShared('lib/core/widget_b.dart', [
    BusinessType.clothing,
    BusinessType.hardware,
  ], verify: (_, __) => true);

  assert(
    guard.sharedImpactNotes.length == 2,
    'Expected 2 notes, got ${guard.sharedImpactNotes.length}',
  );
  assert(
    guard.sharedImpactNotes[0].widgetPath == 'lib/core/widget_a.dart',
    'First note path mismatch',
  );
  assert(
    guard.sharedImpactNotes[1].widgetPath == 'lib/core/widget_b.dart',
    'Second note path mismatch',
  );

  print('  ✓ All notes accessible via sharedImpactNotes');
}

void _testResetClearsSharedImpactNotes() {
  print('Test: reset() clears sharedImpactNotes and blockedItems...');
  final guard = EditScopeGuard();

  guard.verifyShared('lib/core/something.dart', [
    BusinessType.grocery,
  ], verify: (_, __) => false);

  assert(guard.sharedImpactNotes.isNotEmpty, 'Should have notes before reset');
  assert(
    guard.blockedItems.isNotEmpty,
    'Should have blocked items before reset',
  );

  guard.reset();

  assert(guard.sharedImpactNotes.isEmpty, 'Notes should be empty after reset');
  assert(
    guard.blockedItems.isEmpty,
    'Blocked items should be empty after reset',
  );
  assert(
    guard.rejectionLog.isEmpty,
    'Rejection log should be empty after reset',
  );

  print('  ✓ reset() clears all internal state');
}

void _testDefaultVerifyPassesAll() {
  print('Test: Default verify callback passes all consumers...');
  final guard = EditScopeGuard();

  final note = guard.verifyShared('lib/widgets/default_test.dart', [
    BusinessType.restaurant,
    BusinessType.wholesale,
  ]);

  // Default callback passes everything
  assert(
    note.consumerVerification[BusinessType.restaurant] == true,
    'Restaurant should pass with default verify',
  );
  assert(
    note.consumerVerification[BusinessType.wholesale] == true,
    'Wholesale should pass with default verify',
  );
  assert(guard.blockedItems.isEmpty, 'No blocked items with default verify');

  print('  ✓ Default verify callback passes all consumers');
}

void _testEmptyConsumerList() {
  print('Test: Empty consumer list → empty verification map...');
  final guard = EditScopeGuard();

  final note = guard.verifyShared(
    'lib/core/orphan.dart',
    [],
    verify: (_, __) => true,
  );

  assert(note.consumerVerification.isEmpty, 'Map should be empty');
  assert(guard.sharedImpactNotes.length == 1, 'Note should still be recorded');
  assert(guard.blockedItems.isEmpty, 'No blocked items for empty list');

  print('  ✓ Empty consumer list handled gracefully');
}

void _testWidgetPathPreserved() {
  print('Test: widgetPath is preserved in the returned note...');
  final guard = EditScopeGuard();

  const path = 'lib/core/theme/design_tokens.dart';
  final note = guard.verifyShared(path, [
    BusinessType.jewellery,
  ], verify: (_, __) => true);

  assert(note.widgetPath == path, 'Widget path should be preserved');

  print('  ✓ Widget path correctly preserved');
}

void _testVerifyCallbackReceivesCorrectArgs() {
  print('Test: Verify callback receives correct widgetPath and consumer...');
  final guard = EditScopeGuard();

  const widgetPath = 'lib/core/data_table.dart';
  final expectedConsumers = [BusinessType.mobileShop, BusinessType.autoParts];

  final receivedPaths = <String>[];
  final receivedConsumers = <BusinessType>[];

  guard.verifyShared(
    widgetPath,
    expectedConsumers,
    verify: (path, consumer) {
      receivedPaths.add(path);
      receivedConsumers.add(consumer);
      return true;
    },
  );

  assert(
    receivedPaths.every((p) => p == widgetPath),
    'All calls should receive the widget path',
  );
  assert(
    receivedConsumers.toSet().length == 2,
    'Should receive 2 unique consumers',
  );
  assert(
    receivedConsumers.contains(BusinessType.mobileShop),
    'Should include mobileShop',
  );
  assert(
    receivedConsumers.contains(BusinessType.autoParts),
    'Should include autoParts',
  );

  print('  ✓ Callback receives correct arguments');
}
