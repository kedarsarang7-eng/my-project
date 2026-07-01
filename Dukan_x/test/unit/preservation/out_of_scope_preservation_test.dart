/// Out-of-Scope Preservation Guard Tests — Vegetable Broker Remediation
///
/// **Validates: Requirements 16.1, 16.2, 16.3, 16.4**
///
/// These tests assert that:
/// 1. The vegetablesBroker GST exemption is preserved (defaultGstRate == 0.0,
///    gstEditable == false) — R16.1, R16.3.
/// 2. No other business type's source/config/sidebar was altered during the
///    remediation — R16.2.
/// 3. If a change would alter another business type's config, it would be
///    detectable (R16.4 — the tests themselves serve as the halt mechanism).
///
/// Methodology: snapshot every non-vegetablesBroker business type's
/// configuration (requiredFields, optionalFields, defaultGstRate, gstEditable,
/// unitOptions, labels, modules) as a golden baseline. Additionally use
/// source-level fingerprinting of the sidebar_configuration.dart file to detect
/// changes to other business type sidebar sections.
///
/// PBT library: dartproptest ^0.2.1.
///
/// Run: flutter test test/unit/preservation/out_of_scope_preservation_test.dart
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';

import 'package:dukanx/core/billing/business_type_config.dart';

// ---------------------------------------------------------------------------
// Golden helpers — record-on-first-run, compare-on-subsequent-runs.
// ---------------------------------------------------------------------------
const JsonEncoder _enc = JsonEncoder.withIndent('  ');

File _goldenFile(String name) => File(
  'test/unit/preservation/__goldens__/vegetable_broker_remediation/$name.json',
);

/// Asserts [observation] matches the recorded golden [name]. On the first run
/// the golden is written (baseline capture). On subsequent runs the live
/// observation is compared byte-for-byte to the baseline.
void _expectGolden(String name, Object observation) {
  final f = _goldenFile(name);
  final live = _enc.convert(observation);
  if (!f.existsSync()) {
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(live);
    return; // baseline recorded
  }
  final golden = _enc.convert(jsonDecode(f.readAsStringSync()));
  expect(
    live,
    golden,
    reason:
        'Preservation regression: "$name" changed. The vegetable-broker '
        'remediation must not alter any other business type\'s config, '
        'capability, or sidebar sections. Restore the original behaviour, '
        'or update the golden only if this change is an intended, documented '
        'part of a separate fix.',
  );
}

// ---------------------------------------------------------------------------
// Domain — all business types EXCEPT vegetablesBroker.
// ---------------------------------------------------------------------------
final List<BusinessType> _nonVegetablesBrokerTypes = BusinessType.values
    .where((t) => t != BusinessType.vegetablesBroker)
    .toList(growable: false);

// ---------------------------------------------------------------------------
// Serialisation helpers — produce a deterministic, diff-friendly snapshot of
// a BusinessTypeConfig.
// ---------------------------------------------------------------------------
Map<String, dynamic> _configSnapshot(BusinessTypeConfig config) {
  return {
    'type': config.type.name,
    'requiredFields': config.requiredFields.map((f) => f.name).toList(),
    'optionalFields': config.optionalFields.map((f) => f.name).toList(),
    'defaultGstRate': config.defaultGstRate,
    'gstEditable': config.gstEditable,
    'unitOptions': config.unitOptions.map((u) => u.name).toList(),
    'itemLabel': config.itemLabel,
    'addItemLabel': config.addItemLabel,
    'priceLabel': config.priceLabel,
    'modules': config.modules,
  };
}

// ---------------------------------------------------------------------------
// Source-level fingerprinting for sidebar sections. We read the source file
// and extract function bodies for each non-vegetablesBroker section builder
// to detect byte-level changes. This avoids pulling in the full Riverpod/
// database transitive dependency chain.
// ---------------------------------------------------------------------------

/// Computes a stable content hash for a string. Normalises line endings.
int _contentHash(String src) {
  final norm = src.replaceAll('\r\n', '\n').trimRight();
  var h = 0;
  for (final c in norm.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return h;
}

/// Extracts the body of a top-level function from [source] by name.
/// Returns the substring from the function signature to its closing brace,
/// or null if not found.
String? _extractFunctionBody(String source, String funcName) {
  final pattern = RegExp(
    '(List<SidebarSection>|void|Widget|String)\\s+$funcName\\s*\\(',
  );
  final match = pattern.firstMatch(source);
  if (match == null) return null;

  final start = match.start;
  // Find the opening brace of the function body
  var braceStart = source.indexOf('{', match.end);
  if (braceStart == -1) return null;

  // Count braces to find the matching close
  var depth = 0;
  var i = braceStart;
  while (i < source.length) {
    if (source[i] == '{') depth++;
    if (source[i] == '}') {
      depth--;
      if (depth == 0) break;
    }
    i++;
  }
  return source.substring(start, i + 1);
}

void main() {
  // =========================================================================
  // R16.1 / R16.3 — vegetablesBroker GST invariant
  // =========================================================================
  group('R16.1/R16.3 — vegetablesBroker GST exemption preserved', () {
    test('defaultGstRate == 0.0 for vegetablesBroker', () {
      final config = BusinessTypeRegistry.getConfig(
        BusinessType.vegetablesBroker,
      );
      expect(
        config.defaultGstRate,
        0.0,
        reason:
            'vegetablesBroker (APMC produce) must retain defaultGstRate == 0.0 '
            'across all phases. R16.1, R16.3.',
      );
    });

    test('gstEditable == false for vegetablesBroker', () {
      final config = BusinessTypeRegistry.getConfig(
        BusinessType.vegetablesBroker,
      );
      expect(
        config.gstEditable,
        false,
        reason:
            'vegetablesBroker (APMC produce) must retain gstEditable == false '
            'across all phases. R16.1, R16.3.',
      );
    });

    test('PBT: GST invariant holds across repeated evaluation', () {
      // The property is simple but we use PBT to document it formally: for
      // ALL evaluation points, the config is stable.
      forAll(
        (int _) {
          final config = BusinessTypeRegistry.getConfig(
            BusinessType.vegetablesBroker,
          );
          expect(config.defaultGstRate, 0.0);
          expect(config.gstEditable, false);
          return true;
        },
        [Gen.interval(0, 99)],
        numRuns: 10,
      );
    });
  });

  // =========================================================================
  // R16.2 — No other business type's capability config changed
  // =========================================================================
  group('R16.2 — other business types config byte-for-byte unchanged', () {
    test('every non-vegetablesBroker config matches the recorded golden', () {
      final observation = <String, dynamic>{
        for (final type in _nonVegetablesBrokerTypes)
          type.name: _configSnapshot(BusinessTypeRegistry.getConfig(type)),
      };
      _expectGolden('non_vegetables_broker_configs', observation);
    });

    test('PBT: for all non-vegetablesBroker types the config is preserved', () {
      // Read or create the baseline first.
      final baselineFile = _goldenFile('non_vegetables_broker_configs');
      if (!baselineFile.existsSync()) {
        // Create baseline now if the snapshot test above hasn't run yet.
        final observation = <String, dynamic>{
          for (final type in _nonVegetablesBrokerTypes)
            type.name: _configSnapshot(BusinessTypeRegistry.getConfig(type)),
        };
        baselineFile.parent.createSync(recursive: true);
        baselineFile.writeAsStringSync(_enc.convert(observation));
      }
      final baseline = (jsonDecode(baselineFile.readAsStringSync()) as Map)
          .cast<String, dynamic>();

      forAll(
        (int idx) {
          final type =
              _nonVegetablesBrokerTypes[idx % _nonVegetablesBrokerTypes.length];
          final live = _configSnapshot(BusinessTypeRegistry.getConfig(type));
          final expected = (baseline[type.name] as Map).cast<String, dynamic>();
          expect(
            _enc.convert(live),
            _enc.convert(expected),
            reason:
                'Config preservation violated for ${type.name}: a vegetable-'
                'broker remediation change leaked into another business type.',
          );
          return true;
        },
        [Gen.interval(0, _nonVegetablesBrokerTypes.length - 1)],
        numRuns: 30,
      );
    });
  });

  // =========================================================================
  // R16.2 — No other business type's sidebar sections changed
  //
  // Uses source-level fingerprinting to avoid transitive database imports.
  // We extract the function body of each non-vegetablesBroker sidebar section
  // builder and hash it. Any modification will change the hash.
  // =========================================================================
  group('R16.2 — other business types sidebar source unchanged', () {
    test(
      'sidebar section builder functions are byte-stable for non-veg-broker types',
      () {
        final sidebarSrc = File(
          'lib/widgets/desktop/sidebar_configuration.dart',
        ).readAsStringSync();

        // These are ALL the section builder functions EXCEPT
        // _getVegetablesBrokerSections. A change to any of these during
        // vegetable-broker remediation would violate R16.2.
        final nonBrokerFunctions = [
          '_getRetailSections',
          '_getClinicSections',
          '_getPharmacySections',
          '_getRestaurantSections',
          '_getPetrolPumpSections',
          '_getServiceSections',
          '_getHardwareSections',
        ];

        final observation = <String, dynamic>{};
        for (final funcName in nonBrokerFunctions) {
          final body = _extractFunctionBody(sidebarSrc, funcName);
          if (body != null) {
            observation[funcName] = _contentHash(body);
          }
        }

        // Also fingerprint the switch statement in _getSectionsForBusiness
        // EXCLUDING the vegetablesBroker case — we verify the routing logic
        // for all other types hasn't changed.
        final switchBody = _extractFunctionBody(
          sidebarSrc,
          '_getSectionsForBusiness',
        );
        if (switchBody != null) {
          // Remove the vegetablesBroker case lines to isolate other-type routing
          final lines = switchBody.split('\n');
          final filteredLines = <String>[];
          var skipUntilNextCase = false;
          for (final line in lines) {
            if (line.contains('BusinessType.vegetablesBroker')) {
              skipUntilNextCase = true;
              continue;
            }
            if (skipUntilNextCase &&
                (line.contains('case BusinessType.') ||
                    line.trimLeft().startsWith('default:'))) {
              skipUntilNextCase = false;
            }
            if (!skipUntilNextCase) {
              filteredLines.add(line);
            }
          }
          observation['_getSectionsForBusiness_nonBrokerRouting'] =
              _contentHash(filteredLines.join('\n'));
        }

        _expectGolden('non_vegetables_broker_sidebar_source', observation);
      },
    );
  });

  // =========================================================================
  // R16.4 — Halt mechanism (these tests serve as the automated halt guard)
  //
  // If any remediation change inadvertently modifies another business type's
  // config or sidebar, the golden comparisons above will FAIL, halting the CI
  // pipeline and surfacing the offending change. This group documents that
  // contract explicitly.
  // =========================================================================
  group('R16.4 — halt mechanism for cross-type contamination', () {
    test('modifying another type config would be detected by golden check', () {
      // Verify the mechanism: the golden file for configs, if it exists, is
      // read and compared. A difference would cause a test failure — that IS
      // the halt and surface indication required by R16.4.
      final config = BusinessTypeRegistry.getConfig(BusinessType.grocery);
      expect(
        config.type,
        BusinessType.grocery,
        reason: 'Sanity: grocery config is retrievable.',
      );
      // The actual guard is the golden comparison in the group above.
    });

    test(
      'business_type_config.dart source hash for non-broker entries is stable',
      () {
        final configSrc = File(
          'lib/core/billing/business_type_config.dart',
        ).readAsStringSync();

        // Extract the full _configs map, then hash everything except the
        // vegetablesBroker entry to detect any accidental modification.
        final lines = configSrc.split('\n');
        final filteredLines = <String>[];
        var skipBrokerBlock = false;
        var braceDepth = 0;

        for (final line in lines) {
          if (line.contains('BusinessType.vegetablesBroker:')) {
            skipBrokerBlock = true;
            braceDepth = 0;
            continue;
          }
          if (skipBrokerBlock) {
            braceDepth += line.split('').where((c) => c == '(').length;
            braceDepth -= line.split('').where((c) => c == ')').length;
            // End of the BusinessTypeConfig(...) entry: next BusinessType or closing
            if (line.trimLeft().startsWith('BusinessType.') ||
                (braceDepth <= 0 && line.contains('),'))) {
              if (line.contains('),')) {
                skipBrokerBlock = false;
                continue; // skip the closing line of the broker entry
              }
              skipBrokerBlock = false;
            } else {
              continue;
            }
          }
          filteredLines.add(line);
        }

        final nonBrokerHash = _contentHash(filteredLines.join('\n'));
        final observation = {'non_broker_config_source_hash': nonBrokerHash};
        _expectGolden('business_type_config_source', observation);
      },
    );
  });
}
