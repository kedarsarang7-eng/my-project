// PROPERTY 2: PRESERVATION — Already-Correct Workflows Are Untouched.
//
// This suite implements clauses 2.20 and 3.1..3.7 from `bugfix.md` and the
// "Preservation Checking" pseudocode from `design.md`:
//
//   FOR ALL X WHERE NOT isBugCondition(X) DO
//     ASSERT F(X) = F_prime(X)
//   END FOR
//
// Methodology (observation-first):
//   1. PBT generators enumerate candidate workflows X over the full
//      (app, module, screen, workflow) surface.
//   2. We filter to `NOT isBugCondition(X)` using the SAME predicates the
//      Task 1 audit asserts (`bug_condition_audit_test.dart`), negated in
//      `preservation_walker.dart`. This keeps Property 1 and Property 2
//      sampling exactly the disjoint partitions of the input space.
//   3. For each non-buggy X we compute a deterministic fingerprint and
//      compare it to a recorded golden under
//      `Dukan_x/test/preservation/__goldens__/`. On UNFIXED code the
//      golden is written and the test passes — that is the EXPECTED
//      OUTCOME (per `tasks.md` Task 2). On F' (Task 3.4) the golden is
//      read and equality realises `F'(X) == F(X)`.
//
// Coverage rows (each `test()` below maps to one Preservation Requirement
// from the task spec):
//
//   - already-correct navigation -> route graph snapshot (3.1, 3.4)
//   - already-correct GST / domain math -> decimal-helper file snapshot
//     (3.1)
//   - already-correct offline queue / sync -> idempotent-queue snapshot
//     (3.7)
//   - already-correct RBAC -> permissions-module snapshot (3.6)
//   - already-correct cross-module hand-offs -> dependent-record wiring
//     snapshot (3.1)
//   - persisted-data round-trip -> Hive box-name + persisted SharedPrefs
//     key snapshot (3.3, 3.4)
//   - per-business-type theming / iconography / terminology -> non-buggy
//     UI file fingerprint snapshot (3.5)
//   - existing test corpus -> count + path snapshot (3.2)
//   - D-class predicate slices -> per-class non-buggy fingerprint
//     snapshot (3.1 over each defect surface)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../audit/audit_walker.dart' show Finding; // unused but pins import
import 'preservation_walker.dart';

void main() {
  late final Directory ws;

  setUpAll(() {
    ws = resolveWorkspaceRoot();
  });

  // -------------------------------------------------------------------------
  // 3.1 + 3.4 — already-correct navigation snapshot
  //
  // For every registered route X, `notBugConditionD1Route(X)` selects the
  // routes that already resolve to a built screen in F. The resulting
  // (app, route, widget) triples are the public navigation surface that
  // F' MUST honour byte-for-byte (clauses 3.1 and 3.4).
  // -------------------------------------------------------------------------
  test(
    'preservation: route graph for non-buggy routes is byte-stable across F -> F\'',
    () {
      final observations = <Map<String, String>>[];

      // school_admin / teacher / student — every GoRoute in app_router.dart
      // whose target widget exists is a non-buggy navigation entry.
      for (final app in auditedApps.where((a) => a != 'Dukan_x')) {
        final router = File('${ws.path}/$app/lib/core/router/app_router.dart');
        if (!router.existsSync()) continue;
        final src = router.readAsStringSync();
        final featuresDir = Directory('${ws.path}/$app/lib/features');
        final appFiles = listDartFiles(featuresDir);
        final matches = RegExp(
          r"GoRoute\(path:\s*'([^']+)'[^)]*?const\s+([A-Z][A-Za-z0-9_]*)\(\)",
          dotAll: true,
        ).allMatches(src);
        for (final m in matches) {
          final path = m.group(1)!;
          final widget = m.group(2)!;
          if (!notBugConditionD1Route(
            app: app,
            routePath: path,
            widgetName: widget,
            routeFileSrc: src,
            appLibFiles: appFiles,
          )) {
            continue;
          }
          observations.add({'app': app, 'route': path, 'widget': widget});
        }
      }

      // Dukan_x — module routes that point at a real screen (not the
      // shared placeholder) are the non-buggy slice. Today every module
      // route compiles to ModulePlaceholderScreen, so this list is
      // expected to be empty; recording it locks in that invariant.
      for (final m in dukanxModules) {
        final routesDir = Directory('${ws.path}/Dukan_x/lib/modules/$m/routes');
        if (!routesDir.existsSync()) continue;
        for (final f in listDartFiles(routesDir)) {
          final src = safeRead(f);
          final routeMatches = RegExp(
            r"GoRoute\(\s*path:\s*'([^']+)'",
          ).allMatches(src);
          for (final r in routeMatches) {
            final path = r.group(1)!;
            final end = (r.end + 200).clamp(0, src.length);
            final lineSrc = src.substring(r.start, end);
            if (!notBugConditionD1Route(
              app: 'Dukan_x',
              routePath: path,
              widgetName: '',
              routeFileSrc: lineSrc,
              appLibFiles: const [],
            )) {
              continue;
            }
            observations.add({
              'app': 'Dukan_x',
              'module': m,
              'route': path,
              'file': relPath(ws, f),
            });
          }
        }
      }

      observations.sort((a, b) {
        final ka = '${a['app']}|${a['route']}|${a['widget'] ?? a['module']}';
        final kb = '${b['app']}|${b['route']}|${b['widget'] ?? b['module']}';
        return ka.compareTo(kb);
      });

      expectMatchesGolden(ws, 'd1_route_graph', observations);
    },
  );

  // -------------------------------------------------------------------------
  // 3.5 — placeholder-free UI files (per-business-type theming preserved)
  // -------------------------------------------------------------------------
  test(
    'preservation: UI files free of D2 markers keep their content digest',
    () {
      final observations = <Map<String, dynamic>>[];
      for (final app in auditedApps) {
        final libDir = Directory('${ws.path}/$app/lib');
        if (!libDir.existsSync()) continue;
        for (final f in listDartFiles(libDir)) {
          final p = f.path.replaceAll('\\', '/');
          if (!p.contains('/screens/') &&
              !p.contains('/widgets/') &&
              !p.contains('/presentation/') &&
              !p.contains('/modules/')) {
            continue;
          }
          if (!notBugConditionD2UiFile(f)) continue;
          observations.add({
            'app': app,
            'path': relPath(ws, f),
            'digest': contentDigest(safeRead(f)),
          });
        }
      }
      observations.sort(
        (a, b) => (a['path'] as String).compareTo(b['path'] as String),
      );
      expectMatchesGolden(ws, 'd2_clean_ui_files', observations);
    },
  );

  // -------------------------------------------------------------------------
  // 3.1 — already-correct GST / domain math
  // -------------------------------------------------------------------------
  test(
    'preservation: monetary helpers using Decimal keep their content digest',
    () {
      final moneyKeywords = RegExp(
        r'(gst|billing|invoice|totalizer|fee|ledger|making_charges|'
        r'commission|price|payroll)',
        caseSensitive: false,
      );
      final observations = <Map<String, dynamic>>[];
      for (final app in auditedApps) {
        final libDir = Directory('${ws.path}/$app/lib');
        if (!libDir.existsSync()) continue;
        for (final f in listDartFiles(libDir)) {
          final p = f.path.replaceAll('\\', '/');
          if (!moneyKeywords.hasMatch(p)) continue;
          if (!p.contains('/services/') &&
              !p.contains('/utils/') &&
              !p.contains('/calculator') &&
              !p.contains('/accounting/')) {
            continue;
          }
          if (!notBugConditionD3MoneyHelper(f)) continue;
          observations.add({
            'app': app,
            'path': relPath(ws, f),
            'digest': contentDigest(safeRead(f)),
          });
        }
      }
      observations.sort(
        (a, b) => (a['path'] as String).compareTo(b['path'] as String),
      );
      expectMatchesGolden(ws, 'd3_decimal_money_helpers', observations);
    },
  );

  // -------------------------------------------------------------------------
  // 3.1 — already-correct data flow: repositories that invalidate state
  // -------------------------------------------------------------------------
  test(
    'preservation: repositories that invalidate state keep their wiring',
    () {
      final observations = <Map<String, dynamic>>[];
      for (final app in auditedApps) {
        final libDir = Directory('${ws.path}/$app/lib');
        if (!libDir.existsSync()) continue;
        for (final f in listDartFiles(libDir)) {
          if (!f.path.replaceAll('\\', '/').contains('/repositories/')) {
            continue;
          }
          if (!notBugConditionD4Repo(f)) continue;
          observations.add({
            'app': app,
            'path': relPath(ws, f),
            'digest': contentDigest(safeRead(f)),
          });
        }
      }
      observations.sort(
        (a, b) => (a['path'] as String).compareTo(b['path'] as String),
      );
      expectMatchesGolden(ws, 'd4_invalidating_repositories', observations);
    },
  );

  // -------------------------------------------------------------------------
  // 3.7 — already-correct offline queue / sync (idempotency keys preserved)
  // -------------------------------------------------------------------------
  test(
    'preservation: sync queues with idempotency keys keep queue semantics',
    () {
      final observations = <Map<String, dynamic>>[];
      for (final app in auditedApps) {
        final libDir = Directory('${ws.path}/$app/lib');
        if (!libDir.existsSync()) continue;
        final candidates = listDartFiles(libDir).where((f) {
          final p = f.path.replaceAll('\\', '/');
          return p.contains('/sync/') ||
              p.endsWith('sync_queue.dart') ||
              p.endsWith('offline_queue.dart');
        });
        for (final f in candidates) {
          if (!notBugConditionD5Queue(f)) continue;
          observations.add({
            'app': app,
            'path': relPath(ws, f),
            'digest': contentDigest(safeRead(f)),
          });
        }
      }
      observations.sort(
        (a, b) => (a['path'] as String).compareTo(b['path'] as String),
      );
      expectMatchesGolden(ws, 'd5_idempotent_sync_queues', observations);
    },
  );

  // -------------------------------------------------------------------------
  // 3.1 — already-correct cross-module state propagation (D6)
  // -------------------------------------------------------------------------
  test(
    'preservation: providers using ref.watch graphs keep dependency wiring',
    () {
      final observations = <Map<String, dynamic>>[];
      for (final app in auditedApps) {
        final libDir = Directory('${ws.path}/$app/lib');
        if (!libDir.existsSync()) continue;
        final providers = listDartFiles(libDir).where((f) {
          final p = f.path.replaceAll('\\', '/');
          return p.contains('/providers/') || p.endsWith('_providers.dart');
        });
        for (final f in providers) {
          if (!notBugConditionD6Provider(f)) continue;
          observations.add({
            'app': app,
            'path': relPath(ws, f),
            'digest': contentDigest(safeRead(f)),
          });
        }
      }
      observations.sort(
        (a, b) => (a['path'] as String).compareTo(b['path'] as String),
      );
      expectMatchesGolden(ws, 'd6_ref_watch_providers', observations);
    },
  );

  // -------------------------------------------------------------------------
  // 3.1 — already-correct error handling (D7)
  // -------------------------------------------------------------------------
  test('preservation: I/O services with try/catch keep their error wiring', () {
    final observations = <Map<String, dynamic>>[];
    for (final app in auditedApps) {
      final libDir = Directory('${ws.path}/$app/lib');
      if (!libDir.existsSync()) continue;
      for (final f in listDartFiles(libDir)) {
        final p = f.path.replaceAll('\\', '/');
        if (!p.contains('/services/') && !p.contains('/repositories/')) {
          continue;
        }
        if (!notBugConditionD7IoService(f)) continue;
        observations.add({
          'app': app,
          'path': relPath(ws, f),
          'digest': contentDigest(safeRead(f)),
        });
      }
    }
    observations.sort(
      (a, b) => (a['path'] as String).compareTo(b['path'] as String),
    );
    expectMatchesGolden(ws, 'd7_io_try_catch', observations);
  });

  // -------------------------------------------------------------------------
  // 3.6 — already-correct RBAC enforcement
  // -------------------------------------------------------------------------
  test('preservation: existing permissions modules keep their grant set', () {
    final observations = <Map<String, dynamic>>[];
    for (final app in auditedApps) {
      final libDir = Directory('${ws.path}/$app/lib');
      if (!libDir.existsSync()) continue;
      final files = listDartFiles(libDir);
      if (!notBugConditionD8PermissionsModule(files)) continue;
      final permFiles = files.where((f) {
        final p = f.path.replaceAll('\\', '/');
        return p.contains('/permissions/') ||
            p.endsWith('rbac.dart') ||
            p.endsWith('permissions.dart');
      });
      for (final f in permFiles) {
        observations.add({
          'app': app,
          'path': relPath(ws, f),
          'digest': contentDigest(safeRead(f)),
        });
      }
    }
    observations.sort(
      (a, b) => (a['path'] as String).compareTo(b['path'] as String),
    );
    expectMatchesGolden(ws, 'd8_existing_permissions_modules', observations);
  });

  // -------------------------------------------------------------------------
  // 3.1 — already-correct performance (paginated queries)
  // -------------------------------------------------------------------------
  test('preservation: paginated queries keep their limit/cursor wiring', () {
    final observations = <Map<String, dynamic>>[];
    for (final app in auditedApps) {
      final libDir = Directory('${ws.path}/$app/lib');
      if (!libDir.existsSync()) continue;
      for (final f in listDartFiles(libDir)) {
        final p = f.path.replaceAll('\\', '/');
        if (!p.contains('/repositories/') && !p.contains('/services/')) {
          continue;
        }
        if (!notBugConditionD9Query(f)) continue;
        observations.add({
          'app': app,
          'path': relPath(ws, f),
          'digest': contentDigest(safeRead(f)),
        });
      }
    }
    observations.sort(
      (a, b) => (a['path'] as String).compareTo(b['path'] as String),
    );
    expectMatchesGolden(ws, 'd9_paginated_queries', observations);
  });

  // -------------------------------------------------------------------------
  // 3.1 + 3.5 — already-correct domain rules per vertical (D11)
  // -------------------------------------------------------------------------
  test(
    'preservation: existing *_business_rules.dart files keep their content',
    () {
      final observations = <Map<String, dynamic>>[];
      for (final m in dukanxModules) {
        final featDir = Directory('${ws.path}/Dukan_x/lib/features/$m');
        if (!notBugConditionD11Vertical(featDir: featDir, module: m)) continue;
        if (!featDir.existsSync()) continue;
        final rulesFiles = listDartFiles(featDir).where(
          (f) => f.path.replaceAll('\\', '/').endsWith('_business_rules.dart'),
        );
        for (final f in rulesFiles) {
          observations.add({
            'module': m,
            'path': relPath(ws, f),
            'digest': contentDigest(safeRead(f)),
          });
        }
      }
      observations.sort(
        (a, b) => (a['path'] as String).compareTo(b['path'] as String),
      );
      expectMatchesGolden(ws, 'd11_existing_business_rules', observations);
    },
  );

  // -------------------------------------------------------------------------
  // 3.3 + 3.4 — persisted-storage keys (Hive box names + SharedPrefs keys)
  //
  // These are the persistence-shape inputs where `NOT isBugCondition(X)`
  // holds vacuously: they are persisted-storage keys F has used to write
  // real user data. F' MUST read them back identically (clauses 3.3, 3.4).
  // -------------------------------------------------------------------------
  test('preservation: persisted Hive box names are stable across F -> F\'', () {
    final names = <String>{};
    // Match Hive.openBox('name') / Hive.box<T>('name') with either quote
    // style. `\x27` is the apostrophe and `\x22` is the double-quote so we
    // can keep this as a raw string and avoid escape-quoting issues.
    final hivePattern = RegExp(
      r'Hive\.(?:openBox|box)(?:<[^>]+>)?\(\s*[\x27\x22]([A-Za-z_][A-Za-z0-9_]*)[\x27\x22]',
    );
    for (final app in auditedApps) {
      final libDir = Directory('${ws.path}/$app/lib');
      if (!libDir.existsSync()) continue;
      for (final f in listDartFiles(libDir)) {
        for (final m in hivePattern.allMatches(safeRead(f))) {
          names.add(m.group(1)!);
        }
      }
    }
    expectMatchesGolden(ws, 'persisted_hive_box_names', sortedCopy(names));
  });

  test(
    'preservation: persisted SharedPreferences keys are stable across F -> F\'',
    () {
      final keys = <String>{};
      // Match `prefs.getString('foo')`, `prefs.setBool('bar', ...)`, etc.,
      // and any constant declared as `static const _prefKey = 'foo';`.
      final callPattern = RegExp(
        r'prefs\.(?:get|set|contains|remove)[A-Z][A-Za-z]*\(\s*[\x27\x22]([A-Za-z_][A-Za-z0-9_]*)[\x27\x22]',
      );
      final constPattern = RegExp(
        r'_pref(?:Key|erenceKey)\s*=\s*[\x27\x22]([A-Za-z_][A-Za-z0-9_]*)[\x27\x22]',
      );
      for (final app in auditedApps) {
        final libDir = Directory('${ws.path}/$app/lib');
        if (!libDir.existsSync()) continue;
        for (final f in listDartFiles(libDir)) {
          final src = safeRead(f);
          for (final m in callPattern.allMatches(src)) {
            keys.add(m.group(1)!);
          }
          for (final m in constPattern.allMatches(src)) {
            keys.add(m.group(1)!);
          }
        }
      }
      expectMatchesGolden(ws, 'persisted_shared_prefs_keys', sortedCopy(keys));
    },
  );

  // -------------------------------------------------------------------------
  // 3.2 — existing test corpus is a fixed regression baseline
  //
  // Every test that currently passes on F MUST continue to pass on F'
  // unchanged. We snapshot the path list so additions are intentional and
  // deletions are explicit (a removed test is a preservation regression
  // unless it appears in the inventory under D-class fix tests).
  // -------------------------------------------------------------------------
  test(
    'preservation: existing test corpus path list is stable across F -> F\'',
    () {
      final paths = <String>[];
      for (final app in auditedApps) {
        final testDir = Directory('${ws.path}/$app/test');
        if (!testDir.existsSync()) continue;
        for (final f in listDartFiles(testDir)) {
          if (!f.path.endsWith('_test.dart')) continue;
          // Exclude this preservation suite and the audit suite — those are
          // new artefacts of this spec and not part of the baseline corpus.
          final rel = relPath(ws, f);
          if (rel.contains('/test/audit/') ||
              rel.contains('/test/preservation/')) {
            continue;
          }
          paths.add(rel);
        }
      }
      paths.sort();
      expectMatchesGolden(ws, 'existing_test_corpus_paths', paths);
    },
  );
}

// `Finding` is intentionally imported above so the audit_walker dependency
// is explicit at the top — preservation tests do not produce inventory
// rows themselves but they share the same workspace-resolution helpers.
// This unused-import sentinel keeps the link visible to readers.
// ignore: unused_element
void _keepFindingImportLive() {
  Finding(
    defectId: '',
    app: '',
    module: '',
    workflow: '',
    defectClass: '',
    severity: '',
    repro: '',
    observed: '',
    expected: '',
    fixScope: '',
  );
}
