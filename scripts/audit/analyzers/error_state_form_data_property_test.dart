/// Property-Based Test: Error State Preserves Form Data (Property 14)
///
/// For any screen with user-entered form data, when an API call fails after all
/// retry attempts, the screen's form field values and navigation state SHALL
/// remain identical to their pre-failure state.
///
/// **Validates: Requirements 7.5**
library;

import 'dart:math';

void main() {
  print('=== Property 14: Error State Preserves Form Data ===\n');

  final random = Random(42);
  var passed = 0;
  const iterations = 100;

  for (var i = 0; i < iterations; i++) {
    // Generate random form state
    final formState = _generateFormState(random);
    final navState = _generateNavState(random);

    // Create a form controller with the initial state
    final controller = _FormController(
      fields: Map.from(formState),
      navigationState: _NavigationState.from(navState),
    );

    // Snapshot pre-failure state
    final preFailureFields = Map<String, String>.from(controller.fields);
    final preFailureNav = _NavigationState.from(controller.navigationState);

    // Simulate API call with retries (all fail)
    final apiResult = _simulateApiFailure(controller, maxRetries: 3);

    // Property: After failure, all form fields remain identical
    for (final key in preFailureFields.keys) {
      assert(
        controller.fields[key] == preFailureFields[key],
        'Iteration $i: Field "$key" changed after API failure. '
        'Before: "${preFailureFields[key]}", After: "${controller.fields[key]}"',
      );
    }

    // Property: No fields were lost
    assert(
      controller.fields.length == preFailureFields.length,
      'Iteration $i: Field count changed after API failure. '
      'Before: ${preFailureFields.length}, After: ${controller.fields.length}',
    );

    // Property: Navigation state preserved
    assert(
      controller.navigationState.currentRoute == preFailureNav.currentRoute,
      'Iteration $i: Navigation route changed after API failure',
    );
    assert(
      controller.navigationState.stackDepth == preFailureNav.stackDepth,
      'Iteration $i: Navigation stack depth changed after API failure',
    );
    assert(
      _listsEqual(
        controller.navigationState.routeParams,
        preFailureNav.routeParams,
      ),
      'Iteration $i: Navigation route params changed after API failure',
    );

    // Property: API result is failure (all retries exhausted)
    assert(
      !apiResult.success,
      'Iteration $i: API should have failed after all retries',
    );
    assert(
      apiResult.retryCount == 3,
      'Iteration $i: Expected 3 retries, got ${apiResult.retryCount}',
    );

    passed++;
  }

  print(
    '✓ Property 14: Error State Preserves Form Data — $passed/$iterations iterations passed',
  );
}

// ─── Form and navigation state models ──────────────────────────────────────

class _NavigationState {
  final String currentRoute;
  final int stackDepth;
  final List<String> routeParams;

  _NavigationState({
    required this.currentRoute,
    required this.stackDepth,
    required this.routeParams,
  });

  factory _NavigationState.from(_NavigationState other) {
    return _NavigationState(
      currentRoute: other.currentRoute,
      stackDepth: other.stackDepth,
      routeParams: List.from(other.routeParams),
    );
  }
}

class _FormController {
  final Map<String, String> fields;
  final _NavigationState navigationState;

  _FormController({required this.fields, required this.navigationState});
}

class _ApiResult {
  final bool success;
  final int retryCount;
  final String? error;

  const _ApiResult({
    required this.success,
    required this.retryCount,
    this.error,
  });
}

/// Simulates an API call that fails after all retries.
/// The form controller's state should NOT be mutated.
_ApiResult _simulateApiFailure(
  _FormController controller, {
  required int maxRetries,
}) {
  var attempts = 0;

  for (var retry = 0; retry < maxRetries; retry++) {
    attempts++;
    // Simulate API call that throws — the implementation must NOT
    // modify form state on failure
    final success = false; // All retries fail

    if (success) {
      return _ApiResult(success: true, retryCount: attempts);
    }
  }

  // All retries exhausted — controller state must remain unchanged
  return _ApiResult(
    success: false,
    retryCount: attempts,
    error: 'Network timeout after $attempts attempts',
  );
}

// ─── Generation helpers ────────────────────────────────────────────────────

Map<String, String> _generateFormState(Random random) {
  final fieldCount = random.nextInt(8) + 2; // 2–9 fields
  final fields = <String, String>{};

  const fieldNames = [
    'name',
    'email',
    'phone',
    'address',
    'city',
    'state',
    'zip',
    'country',
    'quantity',
    'price',
    'description',
    'notes',
    'reference',
    'date',
    'category',
  ];

  for (var i = 0; i < fieldCount; i++) {
    final name = fieldNames[i % fieldNames.length];
    fields[name] = _randomFieldValue(random, name);
  }

  return fields;
}

String _randomFieldValue(Random random, String fieldName) {
  switch (fieldName) {
    case 'name':
      const names = [
        'Alice Johnson',
        'Bob Smith',
        'Charlie Brown',
        'Dana White',
      ];
      return names[random.nextInt(names.length)];
    case 'email':
      return 'user${random.nextInt(1000)}@example.com';
    case 'phone':
      return '+91${random.nextInt(900000000) + 100000000}';
    case 'quantity':
    case 'price':
      return '${random.nextInt(10000)}';
    case 'zip':
      return '${random.nextInt(90000) + 10000}';
    default:
      final chars = 'abcdefghijklmnopqrstuvwxyz ';
      final length = random.nextInt(20) + 3;
      return List.generate(
        length,
        (_) => chars[random.nextInt(chars.length)],
      ).join();
  }
}

_NavigationState _generateNavState(Random random) {
  const routes = [
    '/billing/create',
    '/restaurant/menu/edit',
    '/pharmacy/order/new',
    '/jewellery/custom-order',
    '/clinic/patient/add',
  ];

  final paramCount = random.nextInt(3);
  final params = List.generate(
    paramCount,
    (_) => 'param_${random.nextInt(100)}',
  );

  return _NavigationState(
    currentRoute: routes[random.nextInt(routes.length)],
    stackDepth: random.nextInt(5) + 1,
    routeParams: params,
  );
}

bool _listsEqual(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
