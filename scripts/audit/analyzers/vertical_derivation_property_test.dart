/// Property-Based Test: Vertical Derivation Correctness (Property 2)
///
/// For any file path under `lib/features/<folder>/`, the derived vertical SHALL
/// equal `<folder>`. For any file path NOT under `lib/features/`, the derived
/// vertical SHALL be "core/general".
///
/// **Validates: Requirements 1.2**
library;

import 'dart:math';

import 'screen_discovery.dart';

void main() {
  print('=== Property 2: Vertical Derivation Correctness ===\n');

  final engine = ScreenDiscoveryEngine();
  final random = Random(42);
  var passed = 0;
  const iterations = 100;

  for (var i = 0; i < iterations; i++) {
    final testCase = _generateTestCase(random);
    final result = engine.deriveVertical(testCase.path);

    if (testCase.isUnderFeatures) {
      assert(
        result == testCase.expectedFolder,
        'Iteration $i: Expected vertical="${testCase.expectedFolder}" '
        'but got "$result" for path="${testCase.path}"',
      );
    } else {
      assert(
        result == 'core/general',
        'Iteration $i: Expected "core/general" but got "$result" '
        'for non-features path="${testCase.path}"',
      );
    }

    passed++;
  }

  print(
    '✓ Property 2: Vertical Derivation — $passed/$iterations iterations passed',
  );
}

// ─── Test case generation ──────────────────────────────────────────────────

class _TestInput {
  final String path;
  final bool isUnderFeatures;
  final String expectedFolder;

  const _TestInput({
    required this.path,
    required this.isUnderFeatures,
    required this.expectedFolder,
  });
}

_TestInput _generateTestCase(Random random) {
  final isUnderFeatures = random.nextBool();

  if (isUnderFeatures) {
    final folder = _randomFeatureFolder(random);
    final subpath = _randomSubpath(random);
    final fileName = _randomDartFile(random);
    return _TestInput(
      path: 'lib/features/$folder/$subpath/$fileName',
      isUnderFeatures: true,
      expectedFolder: folder,
    );
  } else {
    // Generate various non-features paths
    final pathType = random.nextInt(5);
    final path = switch (pathType) {
      0 => 'lib/core/${_randomDartFile(random)}',
      1 => 'lib/shared/widgets/${_randomDartFile(random)}',
      2 => 'lib/${_randomDartFile(random)}',
      3 =>
        'test/features/${_randomFeatureFolder(random)}/${_randomDartFile(random)}',
      _ => 'lib/utils/${_randomDartFile(random)}',
    };
    return _TestInput(
      path: path,
      isUnderFeatures: false,
      expectedFolder: 'core/general',
    );
  }
}

String _randomFeatureFolder(Random random) {
  const folders = [
    'restaurant',
    'billing',
    'pharmacy',
    'jewellery',
    'clinic',
    'hardware',
    'computer_shop',
    'clothing',
    'auto_parts',
    'grocery',
    'school_erp',
    'decoration_catering',
    'salon',
    'academic_coaching',
  ];
  return folders[random.nextInt(folders.length)];
}

String _randomSubpath(Random random) {
  const subpaths = [
    'presentation/screens',
    'presentation/widgets',
    'data/repositories',
    'data/models',
    'domain/entities',
    'domain/usecases',
  ];
  return subpaths[random.nextInt(subpaths.length)];
}

String _randomDartFile(Random random) {
  const prefixes = [
    'home',
    'list',
    'detail',
    'form',
    'settings',
    'dashboard',
    'report',
  ];
  const suffixes = ['screen', 'page', 'widget', 'view', 'controller', 'model'];
  final prefix = prefixes[random.nextInt(prefixes.length)];
  final suffix = suffixes[random.nextInt(suffixes.length)];
  return '${prefix}_$suffix.dart';
}
