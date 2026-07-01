// Feature: comprehensive-test-certification, Property 14
//
// Property 14: Benchmark document is valid only when all six practice
// categories are mapped.
//
// For any Benchmark_Document, validation succeeds if and only if each of the
// six required practice categories maps to at least one concrete, named action;
// otherwise validation rejects the document, names each unmapped category, and
// retains any previously generated valid content.
//
// **Validates: Requirements 12.2, 12.3**
//
// PBT library: dartproptest ^0.2.1.
//   forAll((args...) => <bool>, [gen1, gen2, ...], numRuns: 200);
//
// Run: flutter test test/certification/pbt/property_14_benchmark_mapping_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/benchmark.dart';
import '../pbt/generators.dart';

// ============================================================================
// GENERATORS
// ============================================================================

/// All six practice categories.
const List<PracticeCategory> _allCategories = PracticeCategory.values;

/// Generates a random action name string.
final Generator<String> _actionNameGen = Gen.interval(
  1,
  99999,
).map((i) => 'action-$i');

/// Generates a random description string.
final Generator<String> _descriptionGen = Gen.interval(
  1,
  99999,
).map((i) => 'Description for action $i');

/// Generates an index into PracticeCategory.values (0–5).
final Generator<int> _categoryIndexGen = Gen.interval(0, 5);

/// Generates a number of actions per category (1–4).
final Generator<int> _actionsPerCategoryGen = Gen.interval(1, 4);

// ============================================================================
// HELPERS
// ============================================================================

/// Builds a fully-mapped BenchmarkDocument where every category has at least
/// one concrete action, using the provided seed values for variation.
BenchmarkDocument _buildFullDocument(int seed, int actionsPerCategory) {
  final mappings = <PracticeCategory, List<ConcreteAction>>{};
  final count = (actionsPerCategory % 4) + 1; // 1–4 actions per category

  for (final category in _allCategories) {
    final actions = <ConcreteAction>[];
    for (var i = 0; i < count; i++) {
      actions.add(
        ConcreteAction(
          category: category,
          actionName: 'action-${seed}-${category.index}-$i',
          description: 'Concrete action $i for ${category.name} (seed $seed)',
        ),
      );
    }
    mappings[category] = actions;
  }

  return BenchmarkDocument(mappings: mappings);
}

/// Removes a single category from a fully-mapped document by its index.
BenchmarkDocument _removeCategory(BenchmarkDocument doc, int categoryIndex) {
  final idx = categoryIndex % _allCategories.length;
  final category = _allCategories[idx];
  final newMappings = Map<PracticeCategory, List<ConcreteAction>>.from(
    doc.mappings,
  );
  newMappings.remove(category);
  return BenchmarkDocument(mappings: newMappings);
}

// ============================================================================
// TESTS
// ============================================================================

void main() {
  const validator = BenchmarkValidator();

  group('Feature: comprehensive-test-certification, Property 14: '
      'Benchmark document is valid only when all six practice categories '
      'are mapped', () {
    // FORWARD: all 6 categories mapped to ≥1 action → accepted
    test('Property 14 FORWARD: all 6 categories mapped to ≥1 action '
        '→ accepted', () {
      final held = forAll(
        (int seed, int actionsPerCategory) {
          final doc = _buildFullDocument(seed, actionsPerCategory);
          final result = validator.validate(doc);

          // Must be accepted with no unmapped categories
          return result.accepted == true && result.unmappedCategories.isEmpty;
        },
        [Gen.interval(1, 99999), _actionsPerCategoryGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // REJECTION: remove any one category → rejected, names the unmapped category
    test('Property 14 REJECTION: remove any one category '
        '→ rejected, names the unmapped category', () {
      final held = forAll(
        (int seed, int actionsPerCategory, int categoryIndex) {
          final fullDoc = _buildFullDocument(seed, actionsPerCategory);
          final idx = categoryIndex % _allCategories.length;
          final removedCategory = _allCategories[idx];

          // Remove one category from the document
          final brokenDoc = _removeCategory(fullDoc, categoryIndex);
          final result = validator.validate(brokenDoc);

          // Must be rejected and name the removed category
          return result.accepted == false &&
              result.unmappedCategories.contains(removedCategory);
        },
        [Gen.interval(1, 99999), _actionsPerCategoryGen, _categoryIndexGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });
  });
}
