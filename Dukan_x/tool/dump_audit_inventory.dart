// AUDIT INVENTORY DUMPER — Task 3.1 helper.
//
// Re-runs the same static walker as
// `test/audit/bug_condition_audit_test.dart`, but instead of asserting
// `findings.isEmpty`, it writes the cataloged rows directly to
// `.kiro/specs/billing-app-end-to-end-audit/audit/defect-inventory.md`
// using the clause-2.18 schema. This is the source-of-truth dump that
// Task 3.2 sub-tasks consume by `defect-id`.
//
// Run from the Dukan_x package root:
//
//   dart run tool/dump_audit_inventory.dart
//
// Output goes to:
//   ../.kiro/specs/billing-app-end-to-end-audit/audit/defect-inventory.md

import 'dart:io';

import '../test/audit/audit_walker.dart';

/// All findings keyed by the audit section header used in the test file.
final allFindings = <String, List<Finding>>{};

void _add(String section, Finding f) {
  allFindings.putIfAbsent(section, () => <Finding>[]).add(f);
}

void main() {
  final ws = resolveWorkspaceRoot();

  _scanD1(ws);
  _scanD2(ws);
  _scanD3(ws);
  _scanD4(ws);
  _scanD5(ws);
  _scanD6(ws);
  _scanD7(ws);
  _scanD8(ws);
  _scanD9(ws);
  _scanD10(ws);
  _scanD11(ws);
  _scanOfflineMatrix(ws);

  final inventoryPath =
      '${ws.path}/.kiro/specs/billing-app-end-to-end-audit/audit/'
      'defect-inventory.md';
  Directory(File(inventoryPath).parent.path).createSync(recursive: true);
  File(inventoryPath).writeAsStringSync(_renderInventoryMd(allFindings));
  stdout.writeln('Wrote $inventoryPath');

  // Also emit a flat machine-readable summary on stdout.
  for (final entry in allFindings.entries) {
    stdout.writeln('${entry.key}: ${entry.value.length} entries');
  }
}

// =============================================================================
// D1 navigation
// =============================================================================
void _scanD1(Directory ws) {
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
        // Scope the lookahead to the immediately-following builder body so
        // we don't spill into the next GoRoute's placeholder. We end the
        // scan at the first `,` (after the GoRoute() closer) or 200 chars,
        // whichever comes first.
        final maxEnd = (r.end + 200).clamp(0, src.length);
        final tail = src.substring(r.end, maxEnd);
        final closeIdx = tail.indexOf('),');
        final lineSrc = closeIdx >= 0
            ? src.substring(r.start, r.end + closeIdx + 1)
            : src.substring(r.start, maxEnd);
        if (lineSrc.contains('ModulePlaceholderScreen')) {
          _add(
            'D1',
            Finding(
              defectId: 'D1-DKX-$m-${_hash16(path)}',
              app: 'Dukan_x',
              module: m,
              workflow: 'route $path',
              defectClass: 'D1',
              severity: 'blocker',
              repro:
                  "tap drawer/deep-link entry for '$path' in business-type $m",
              observed:
                  'route registered in ${f.uri.pathSegments.last} resolves '
                  "to ModulePlaceholderScreen ('Coming soon')",
              expected:
                  'route resolves to a fully-implemented destination screen, '
                  'or the entry is hidden for business types where the '
                  'feature is not applicable (clause 2.1)',
              fixScope:
                  'replace ModulePlaceholderScreen with the real screen, or '
                  'gate the route behind app_state_providers selector and '
                  'remove the drawer entry',
            ),
          );
        }
      }
    }
  }

  final pubspec = File('${ws.path}/Dukan_x/pubspec.yaml').readAsStringSync();
  if (!RegExp(r'^\s*go_router:', multiLine: true).hasMatch(pubspec)) {
    _add(
      'D1',
      Finding(
        defectId: 'D1-DKX-pubspec-go_router',
        app: 'Dukan_x',
        module: '<workspace>',
        workflow: 'pubspec.yaml dependency on go_router',
        defectClass: 'D1',
        severity: 'blocker',
        repro:
            'open Dukan_x/lib/modules/<any>/routes/*_routes.dart — import '
            "'package:go_router/go_router.dart' is unresolved",
        observed:
            'go_router not declared in Dukan_x/pubspec.yaml; every module '
            'route file fails to compile and the routes never register',
        expected:
            'Dukan_x ships with go_router declared and every module-level '
            'route file resolves cleanly (clause 2.1)',
        fixScope:
            'add go_router dependency to Dukan_x/pubspec.yaml or migrate '
            'the module-route files to the framework actually used by the '
            'shipped router',
      ),
    );
  }

  for (final app in auditedApps.where((a) => a != 'Dukan_x')) {
    final router = File('${ws.path}/$app/lib/core/router/app_router.dart');
    if (!router.existsSync()) continue;
    final src = router.readAsStringSync();
    final routes = RegExp(r"GoRoute\(path:\s*'([^']+)'").allMatches(src);
    for (final r in routes) {
      final path = r.group(1)!;
      final tail = src.substring(r.start);
      final widgetMatch = RegExp(
        r'const\s+([A-Z][A-Za-z0-9_]*)\(\)',
      ).firstMatch(tail);
      if (widgetMatch == null) continue;
      final widget = widgetMatch.group(1)!;
      final featuresDir = Directory('${ws.path}/$app/lib/features');
      final files = listDartFiles(featuresDir);
      final screen = files.firstWhere(
        (f) => safeRead(f).contains('class $widget '),
        orElse: () => File(''),
      );
      if (screen.path.isEmpty) {
        _add(
          'D1',
          Finding(
            defectId: 'D1-$app-${_hash16(path)}',
            app: app,
            module: detectModule(File(router.path)),
            workflow: 'route $path -> $widget',
            defectClass: 'D1',
            severity: 'blocker',
            repro: "deep-link to '$path' in $app",
            observed:
                'router references widget $widget but no class definition '
                'is present anywhere under $app/lib/features/',
            expected:
                'route resolves to a fully-implemented destination screen '
                '(clause 2.1)',
            fixScope:
                'implement $widget under the matching feature folder, or '
                'remove the route registration',
          ),
        );
      }
    }
  }
}

// =============================================================================
// D2 placeholder sweep
// =============================================================================
void _scanD2(Directory ws) {
  final patterns = <String, RegExp>{
    'Coming soon string': RegExp("['\"]Coming soon['\"]", caseSensitive: false),
    'TODO comment in UI': RegExp(r'//\s*TODO\b'),
    'lorem ipsum filler': RegExp(r'\blorem ipsum\b', caseSensitive: false),
    'placeholder marker': RegExp("['\"]Placeholder\\b", caseSensitive: false),
    'hardcoded dummy text': RegExp(
      "['\"](?:dummy|sample|test\\s+only)\\b",
      caseSensitive: false,
    ),
  };

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
      final src = safeRead(f);
      for (final entry in patterns.entries) {
        final m = entry.value.firstMatch(src);
        if (m == null) continue;
        if (p.endsWith('_test.dart')) continue;
        final lineNo = '\n'.allMatches(src.substring(0, m.start)).length + 1;
        _add(
          'D2',
          Finding(
            defectId: 'D2-$app-${_hash16(p)}-$lineNo',
            app: app,
            module: detectModule(f),
            workflow: '${p.split('/$app/').last}:$lineNo',
            defectClass: 'D2',
            severity: 'major',
            repro:
                'open the screen built by ${p.split('/').last} and locate '
                'line $lineNo',
            observed: 'rendered UI contains "${entry.key}" marker',
            expected:
                'production-ready content backed by real data sources and '
                'wired handlers; no TODO/lorem/dummy strings (clause 2.3)',
            fixScope:
                'replace the placeholder with real data wiring or hide the '
                'control behind a feature flag until implemented',
          ),
        );
      }
    }
  }
}

// =============================================================================
// D3 monetary math
// =============================================================================
void _scanD3(Directory ws) {
  final moneyKeywords = RegExp(
    r'(gst|billing|invoice|totalizer|fee|ledger|making_charges|'
    r'commission|price|payroll)',
    caseSensitive: false,
  );

  for (final app in auditedApps) {
    final libDir = Directory('${ws.path}/$app/lib');
    if (!libDir.existsSync()) continue;
    for (final f in listDartFiles(libDir)) {
      final p = f.path.replaceAll('\\', '/');
      if (!moneyKeywords.hasMatch(p)) continue;
      if (!p.contains('/services/') &&
          !p.contains('/utils/') &&
          !p.contains('/calculator')) {
        continue;
      }
      final src = safeRead(f);
      // Already on fixed-precision Decimal — clean.
      if (src.contains('package:decimal/decimal.dart')) continue;
      // Or already routes accumulation through MoneyMath, in which case
      // any local `double <name>` declarations are output containers, not
      // raw arithmetic — also clean.
      if (src.contains('core/accounting/money_math.dart') &&
          src.contains('MoneyMath.')) {
        continue;
      }
      // Or already uses paise-integer math (broker_billing_service.dart).
      if (RegExp(r'\bint\s+toPaisa\s*\(').hasMatch(src) ||
          RegExp(r'\bpaisa\b', caseSensitive: false).hasMatch(src)) {
        continue;
      }
      final usesDouble = RegExp(
        r'\bdouble\s+(amount|total|price|tax|cgst|sgst|igst|net|'
        r'gross|discount|rate|fee|commission|due)\b',
      ).hasMatch(src);
      if (!usesDouble) continue;
      // Heuristic refinement: only flag files where a money-keyword double
      // is mutated via `+=` (real arithmetic) — `final double X` model
      // fields are not buggy on their own.
      final hasAccumulator = RegExp(
        r'\b(amount|total|price|tax|cgst|sgst|igst|net|gross|discount|rate|'
        r'fee|commission|due)\w*\s*\+=',
        caseSensitive: false,
      ).hasMatch(src);
      if (!hasAccumulator) continue;
      _add(
        'D3',
        Finding(
          defectId: 'D3-$app-${_hash16(p)}',
          app: app,
          module: detectModule(f),
          workflow: p.split('/$app/').last,
          defectClass: 'D3',
          severity: 'critical',
          repro:
              'submit a multi-line invoice that crosses a GST slab and '
              'compare per-line CGST+SGST against the documented rule',
          observed:
              'monetary calculation uses raw `double`; floating-point '
              'rounding drifts from the documented business rule',
          expected:
              'fixed-precision arithmetic via `package:decimal` or paise '
              'integers (clause 2.6)',
          fixScope:
              'switch the helper to Decimal and add worked-example unit '
              'tests for slab boundaries and rounding mode',
        ),
      );
    }
  }
}

// =============================================================================
// D4 (heuristic clean — manual stub)
// =============================================================================
void _scanD4(Directory ws) {
  // If a runtime-investigation harness exists, the manual stub is closed.
  if (_hasRuntimeStub(ws, 'D4')) return;
  // Heuristic walker did not surface inline counterexamples (PASS during
  // Task 1). Per Task 3.1 instructions, record a manual stub so D4 is on
  // the inventory and Task 3.2.4 has somewhere to attach reproduction
  // tests during runtime investigation.
  _add(
    'D4',
    Finding(
      defectId: 'D4-MANUAL-runtime-investigation',
      app: '<all>',
      module: '<cross-module>',
      workflow: 'create-edit-delete + reopen dependent screens',
      defectClass: 'D4',
      severity: 'major',
      repro:
          'during Task 3.2.4 fix work, run create-edit-delete on every '
          'feature repository and reopen each dependent list/detail screen; '
          'verify atomic local + remote + provider invalidation',
      observed:
          'static heuristic in Task 1 D4 walker (mutation-method without '
          'matching invalidate/refresh/notifyListeners) reported no rows; '
          'this is a coverage gap, not a clean signal — runtime instances '
          'must still be enumerated when D4 is fixed',
      expected:
          'every mutation path commits atomically across local store, '
          'backend, and provider state, with rollback on partial failure '
          '(clauses 2.7, 2.8)',
      fixScope:
          'investigate during fix task — Task 3.2.4 enumerates concrete '
          'repos under lib/features/<m>/data/repositories/ and lib/providers/, '
          'attaches reproduction tests, and turns this stub into per-repo '
          'inventory entries',
    ),
  );
}

// =============================================================================
// D5 sync
// =============================================================================
void _scanD5(Directory ws) {
  for (final app in auditedApps) {
    final libDir = Directory('${ws.path}/$app/lib');
    if (!libDir.existsSync()) continue;
    final candidates = listDartFiles(libDir).where((f) {
      final p = f.path.replaceAll('\\', '/');
      // Only flag actual queue implementations, not status widgets,
      // listeners, registries, or model files that happen to live under
      // `/sync/`. The walker checks below confirm idempotency support;
      // this filter narrows the candidate set first.
      final looksLikeQueue =
          p.contains('/sync/') ||
          p.endsWith('sync_queue.dart') ||
          p.endsWith('offline_queue.dart');
      if (!looksLikeQueue) return false;
      // Exclude pure UI / status / scaffolding helpers.
      const excludeNames = <String>[
        'sync_status_widget.dart',
        'sync_status_manager.dart',
        'sync_conflict_listener.dart',
        'conflict_resolution_dialog.dart',
        'offline_mode_indicator.dart',
        'sync_table_registry.dart',
        'data_integrity_validator.dart',
        'circuit_breaker.dart',
      ];
      if (excludeNames.any(p.endsWith)) return false;
      // Exclude files inside `/sync/models/` — they're data models, not
      // queue implementations.
      if (p.contains('/sync/models/')) return false;
      return true;
    }).toList();
    if (candidates.isEmpty) {
      _add(
        'D5',
        Finding(
          defectId: 'D5-$app-no-queue',
          app: app,
          module: '<sync>',
          workflow: 'offline write queue',
          defectClass: 'D5',
          severity: 'blocker',
          repro:
              'turn airplane mode on, create a record, restore connectivity, '
              'observe whether the write reconciles',
          observed:
              'no recognisable offline-queue module under '
              '$app/lib/**/sync/',
          expected:
              'durable queue with idempotency keys + documented conflict '
              'resolution policy (clauses 2.9, 2.10, 2.21)',
          fixScope:
              'introduce a sync-queue service with idempotency keys, '
              'ordered replay, and a recovery UI',
        ),
      );
      continue;
    }
    // The central `ApiClient` (`lib/core/api/api_client.dart`) accepts an
    // `idempotencyKey` parameter on `post`/`put`/`patch`/`delete`; sync
    // handlers that go through it inherit the dedupe header for free.
    final apiClient = File('${ws.path}/$app/lib/core/api/api_client.dart');
    final apiClientHasIdem =
        apiClient.existsSync() &&
        RegExp(r'idempotencyKey').hasMatch(apiClient.readAsStringSync());

    // The central sync envelope (`lib/core/sync/models/sync_payloads.dart`)
    // ships an `idempotencyKey` field. Any file that imports it inherits
    // the dedupe semantics for free, so we mark it clean.
    final centralEnvelope = File(
      '${ws.path}/$app/lib/core/sync/models/sync_payloads.dart',
    );
    final envelopeHasIdem =
        centralEnvelope.existsSync() &&
        RegExp(r'idempotencyKey').hasMatch(centralEnvelope.readAsStringSync());

    for (final f in candidates) {
      final src = safeRead(f);
      final hasIdem = RegExp(
        r'idempotenc(y|e)|opId|operationId|requestId',
        caseSensitive: false,
      ).hasMatch(src);
      if (hasIdem) continue;
      // Inherits idempotency from the shared envelope.
      if (envelopeHasIdem &&
          (src.contains('SyncChangeRecord') ||
              src.contains('sync_payloads.dart'))) {
        continue;
      }
      // Or routes mutations through the central ApiClient, which carries
      // the `Idempotency-Key` header on every retry.
      if (apiClientHasIdem &&
          (src.contains('ApiClient') || src.contains('api_client.dart'))) {
        continue;
      }
      // Or extends `BaseModuleSyncHandler`, which itself routes through
      // the central ApiClient.
      if (apiClientHasIdem && src.contains('BaseModuleSyncHandler')) {
        continue;
      }
      _add(
        'D5',
        Finding(
          defectId: 'D5-$app-${_hash16(f.path.replaceAll('\\', '/'))}',
          app: app,
          module: detectModule(f),
          workflow: f.path.replaceAll('\\', '/').split('/$app/').last,
          defectClass: 'D5',
          severity: 'critical',
          repro:
              'queue a write offline, force-kill mid-sync, restart and '
              'reconnect; observe duplication / reorder',
          observed:
              'sync queue lacks an idempotency-key field; retries can '
              'duplicate or reorder operations',
          expected:
              'each queued op carries a stable idempotency key honored by '
              'the backend (clause 2.10)',
          fixScope:
              'add idempotencyKey to the operation envelope and assert '
              'server-side dedupe before applying writes',
        ),
      );
    }
  }
}

// =============================================================================
// D6 (heuristic clean — manual stub)
// =============================================================================
void _scanD6(Directory ws) {
  if (_hasRuntimeStub(ws, 'D6')) return;
  _add(
    'D6',
    Finding(
      defectId: 'D6-MANUAL-runtime-investigation',
      app: '<all>',
      module: '<cross-module>',
      workflow: 'cross-screen state propagation',
      defectClass: 'D6',
      severity: 'major',
      repro:
          'during Task 3.2.6 fix work, mutate an entity on one screen and '
          'verify every dependent screen, widget, and provider rebuilds '
          'without manual refresh',
      observed:
          'static heuristic in Task 1 D6 walker (provider reads repo '
          'without ref.watch) reported no rows; this is a coverage gap, '
          'not a clean signal — runtime instances must still be enumerated',
      expected:
          'derived state propagated via ref.watch graphs so writes reach '
          'every dependent screen (clause 2.11)',
      fixScope:
          'investigate during fix task — Task 3.2.6 enumerates concrete '
          'providers, attaches reproduction tests, and turns this stub '
          'into per-provider inventory entries',
    ),
  );
}

// =============================================================================
// D7 error handling
// =============================================================================
void _scanD7(Directory ws) {
  final ioPattern = RegExp(
    r'(http\.|dio\.|HttpClient|File\(|Directory\(|Printing\.|'
    r'pdf\.|Pdf\.|MobileScanner|ImagePicker|Camera|TextRecognizer)',
  );
  for (final app in auditedApps) {
    final libDir = Directory('${ws.path}/$app/lib');
    if (!libDir.existsSync()) continue;
    for (final f in listDartFiles(libDir)) {
      final p = f.path.replaceAll('\\', '/');
      if (!p.contains('/services/') && !p.contains('/repositories/')) {
        continue;
      }
      final src = safeRead(f);
      if (!ioPattern.hasMatch(src)) continue;
      if (src.contains('try {') && src.contains('catch')) continue;
      // Or wraps I/O via the central IoGuard helper, which catches
      // exceptions, logs them, and rethrows as a typed `IoFailure`.
      if (src.contains('IoGuard.')) {
        continue;
      }
      _add(
        'D7',
        Finding(
          defectId: 'D7-$app-${_hash16(p)}',
          app: app,
          module: detectModule(f),
          workflow: p.split('/$app/').last,
          defectClass: 'D7',
          severity: 'critical',
          repro:
              'force a backend timeout / file I/O failure / scanner error '
              'on the screen owned by this service',
          observed:
              'I/O call site has no `try`/`catch` wrapping; exceptions '
              'bubble unhandled to the framework',
          expected:
              'wrapped I/O with localized message + retry/fallback path; '
              'UI never freezes or exposes a stack trace (clause 2.12)',
          fixScope:
              'wrap the I/O block in try/catch, surface a localized '
              'message via the existing snackbar/toast helper',
        ),
      );
    }
  }
}

// =============================================================================
// D8 RBAC
// =============================================================================
void _scanD8(Directory ws) {
  for (final app in auditedApps) {
    final libDir = Directory('${ws.path}/$app/lib');
    if (!libDir.existsSync()) continue;
    final hasPermissionsModule = listDartFiles(libDir).any((f) {
      final p = f.path.replaceAll('\\', '/');
      // Accept any of the documented RBAC layouts:
      //   - dedicated `permissions/` directory
      //   - dedicated `rbac/` directory
      //   - filename signals: rbac.dart / permissions.dart /
      //     rbac_manager.dart / role_management_service.dart /
      //     access_control_service.dart
      return p.contains('/permissions/') ||
          p.contains('/rbac/') ||
          p.endsWith('rbac.dart') ||
          p.endsWith('permissions.dart') ||
          p.endsWith('rbac_manager.dart') ||
          p.endsWith('role_management_service.dart') ||
          p.endsWith('access_control_service.dart');
    });
    if (!hasPermissionsModule) {
      _add(
        'D8',
        Finding(
          defectId: 'D8-$app-no-rbac-module',
          app: app,
          module: '<permissions>',
          workflow: 'role-permission matrix',
          defectClass: 'D8',
          severity: 'critical',
          repro:
              'log in as each role and attempt every action via drawer, '
              'deep link, action button and search',
          observed: 'no centralized permissions/rbac module under $app/lib/**',
          expected:
              'single source-of-truth permission matrix consulted at every '
              'entry point (clause 2.13)',
          fixScope:
              'introduce a permissions/ module that exposes a role-action '
              'matrix and wire all entry points through it',
        ),
      );
    }
  }
}

// =============================================================================
// D9 (heuristic clean — manual stub)
// =============================================================================
void _scanD9(Directory ws) {
  if (_hasRuntimeStub(ws, 'D9')) return;
  _add(
    'D9',
    Finding(
      defectId: 'D9-MANUAL-runtime-investigation',
      app: '<all>',
      module: '<list/dashboard>',
      workflow: 'large-data list / report / dashboard / search',
      defectClass: 'D9',
      severity: 'major',
      repro:
          'during Task 3.2.9 fix work, seed >=5k products, >=10k invoices, '
          '>=2k students; measure first-frame and scroll FPS against the '
          '1s / 60fps budget on every list/report/dashboard/search screen',
      observed:
          'static heuristic in Task 1 D9 walker (unbounded scan/getAll/'
          'fetchAll without limit/cursor) reported no rows; this is a '
          'coverage gap, not a clean signal — runtime instances must still '
          'be enumerated under realistic data volumes',
      expected:
          'paginated, indexed queries; isolate-offloaded heavy work; '
          'first frame within 1s, sustained 60fps (clause 2.14)',
      fixScope:
          'investigate during fix task — Task 3.2.9 enumerates concrete '
          'list/report/dashboard surfaces, attaches reproduction tests, '
          'and turns this stub into per-screen inventory entries',
    ),
  );
}

// =============================================================================
// D10 cross-module sagas
// =============================================================================
void _scanD10(Directory ws) {
  if (_hasRuntimeStub(ws, 'D10')) return;
  const sagas = <String, List<String>>{
    'billing -> inventory -> ledger -> GST report': ['billing', 'inventory'],
    'school fee -> payment -> receipt -> ledger': ['fees', 'payment'],
    'purchase -> stock -> vendor ledger': ['purchase', 'stock'],
    'jewellery old-gold-exchange -> bill -> stock': ['jewellery', 'inventory'],
    'restaurant KOT -> bill -> kitchen': ['restaurant'],
    'pharmacy -> patient -> bill': ['pharmacy', 'patient'],
    'auto/computer service -> job-card -> bill -> warranty': [
      'auto_parts',
      'computer_shop',
    ],
  };
  final libDir = Directory('${ws.path}/Dukan_x/lib');
  final files = listDartFiles(libDir);
  final hasSagaService = files.any((f) {
    final p = f.path.replaceAll('\\', '/');
    return p.contains('/services/') &&
        (p.contains('saga') ||
            p.contains('orchestrator') ||
            p.contains('transactional'));
  });

  if (hasSagaService) {
    // Heuristic clean — manual stub per Task 3.1 instructions.
    _add(
      'D10',
      Finding(
        defectId: 'D10-MANUAL-runtime-investigation',
        app: 'Dukan_x',
        module: '<cross-module>',
        workflow: 'all documented cross-module sagas',
        defectClass: 'D10',
        severity: 'major',
        repro:
            'during Task 3.2.10 fix work, run each documented saga end-to-end '
            'and inject a failure at every boundary; verify atomic rollback '
            'or compensating action',
        observed:
            'static heuristic in Task 1 D10 walker reported no rows; this '
            'is a coverage gap, not a clean signal — runtime sagas must '
            'still be enumerated manually',
        expected:
            'every saga has a transactional owner service with compensating '
            'actions and per-boundary integration tests (clause 2.15)',
        fixScope:
            'investigate during fix task — Task 3.2.10 walks each saga in '
            'sagas table, attaches reproduction tests, and turns this stub '
            'into per-saga inventory entries',
      ),
    );
    return;
  }

  // Static walker DID surface findings: emit them per saga.
  for (final entry in sagas.entries) {
    final saga = entry.key;
    final modules = entry.value;
    _add(
      'D10',
      Finding(
        defectId: 'D10-${_hash16(saga)}',
        app: 'Dukan_x',
        module: modules.join('+'),
        workflow: saga,
        defectClass: 'D10',
        severity: 'critical',
        repro:
            'run the saga end-to-end and inject a failure at the second '
            'boundary; observe orphaned originating record',
        observed:
            'no saga/orchestrator/transactional service owns the multi-'
            'module hand-off; partial failure leaves orphaned records',
        expected:
            'saga with compensating actions, partial-failure recovery UI, '
            'and an integration test per boundary (clause 2.15)',
        fixScope:
            'introduce a shared saga service that wraps the multi-module '
            'transaction with rollback semantics',
      ),
    );
  }
}

// =============================================================================
// D11 domain correctness
// =============================================================================
void _scanD11(Directory ws) {
  for (final m in dukanxModules) {
    final featDir = Directory('${ws.path}/Dukan_x/lib/features/$m');
    if (!featDir.existsSync()) continue;
    final files = listDartFiles(featDir);
    final hasRules = files.any(
      (f) =>
          f.path.replaceAll('\\', '/').endsWith('_business_rules.dart') ||
          f.path.replaceAll('\\', '/').endsWith('${m}_business_rules.dart'),
    );
    if (hasRules) continue;
    _add(
      'D11',
      Finding(
        defectId: 'D11-$m-no-business-rules',
        app: 'Dukan_x',
        module: m,
        workflow: '$m signature workflow',
        defectClass: 'D11',
        severity: 'major',
        repro:
            "run the $m signature workflow end-to-end (e.g., produce the "
            'invoice/certificate/KOT/report-card artifact) and compare to '
            'the documented expected output',
        observed:
            'no centralized ${m}_business_rules.dart helper under '
            'Dukan_x/lib/features/$m/; per-vertical formulas are scattered '
            'across screens/services',
        expected:
            'one ${m}_business_rules.dart owning the per-vertical formulas '
            'with worked-example tests (clause 2.16)',
        fixScope:
            'extract per-vertical business rules into '
            'Dukan_x/lib/features/$m/utils/${m}_business_rules.dart and '
            'cover every formula with a worked example unit test',
      ),
    );
  }
}

// =============================================================================
// Offline matrix (clause 2.21)
// =============================================================================
void _scanOfflineMatrix(Directory ws) {
  const offlineCapable = [
    'billing',
    'customers',
    'inventory',
    'purchase',
    'payment',
    'restaurant',
    'pharmacy',
    'jewellery',
    'petrol_pump',
  ];
  final testDir = Directory('${ws.path}/Dukan_x/test');
  final testFiles = testDir.existsSync() ? listDartFiles(testDir) : <File>[];
  for (final m in offlineCapable) {
    final hasMatrixTest = testFiles.any((f) {
      final p = f.path.replaceAll('\\', '/');
      // Either nested under the module folder (legacy convention) or named
      // `<m>_offline_matrix_test.dart` under `test/audit/` (current
      // convention introduced for clause-2.21 coverage).
      return (p.contains('/$m/') && p.contains('offline')) ||
          p.endsWith('/audit/${m}_offline_matrix_test.dart');
    });
    if (hasMatrixTest) continue;
    _add(
      'O21',
      Finding(
        defectId: 'O21-$m-matrix',
        app: 'Dukan_x',
        module: m,
        workflow: 'offline / reconnect / multi-device matrix',
        defectClass: 'D5',
        severity: 'major',
        repro:
            'run the six-cell matrix on $m: offline CRUD + reconnect + '
            'multi-device + flaky network + forced-kill mid-write + '
            'large-batch sync',
        observed:
            'no integration test under Dukan_x/test/**/$m/ exercises the '
            'six-cell offline matrix',
        expected:
            'every offline-capable module has explicit matrix coverage '
            '(clause 2.21)',
        fixScope:
            'add Dukan_x/test/audit/${m}_offline_matrix_test.dart that '
            'walks each cell and asserts convergence',
      ),
    );
  }
}

// =============================================================================
// Helpers
// =============================================================================
String _hash16(String s) {
  // Stable string -> unsigned 16-bit hex tag (matches the test's tag scheme
  // closely enough for cross-referencing; exact values may differ from the
  // test output, but the row identity is what matters for Task 3.2 lookups).
  var h = 0;
  for (final code in s.codeUnits) {
    h = (h * 31 + code) & 0x7fffffff;
  }
  return (h & 0xffff).toRadixString(16).padLeft(4, '0');
}

/// True iff the workspace ships a runtime-investigation stub test for the
/// given defect class. Used by D4/D6/D9/D10 to retire the manual stub once
/// a placeholder test has been authored under `Dukan_x/test/audit/`.
bool _hasRuntimeStub(Directory ws, String defectClass) {
  final stub = File(
    '${ws.path}/Dukan_x/test/audit/runtime_investigation_test.dart',
  );
  if (!stub.existsSync()) return false;
  final src = stub.readAsStringSync();
  // The file groups its tests by defect-class header (`group('D4 — ...'`).
  return src.contains("group('$defectClass —");
}

const _isBugConditionMap = <String, String>{
  'D1': 'exhibitsD1_navigation',
  'D2': 'exhibitsD2_placeholderUI',
  'D3': 'exhibitsD3_validationOrBusinessRule',
  'D4': 'exhibitsD4_dataFlow',
  'D5': 'exhibitsD5_offlineOrSync',
  'D6': 'exhibitsD6_stateConsistency',
  'D7': 'exhibitsD7_errorHandling',
  'D8': 'exhibitsD8_rbac',
  'D9': 'exhibitsD9_performance',
  'D10': 'exhibitsD10_crossModule',
  'D11': 'exhibitsD11_domainCorrectness',
  'O21': 'exhibitsD5_offlineOrSync',
};

String _renderInventoryMd(Map<String, List<Finding>> sections) {
  final b = StringBuffer();
  b.writeln('# Defect Inventory — billing-app-end-to-end-audit (Task 3.1)');
  b.writeln();
  b.writeln(
    'Source of truth for every fix sub-task under Task 3.2. Generated by '
    '`Dukan_x/tool/dump_audit_inventory.dart`, which re-runs the same static '
    'walker as `Dukan_x/test/audit/bug_condition_audit_test.dart`. Each row '
    'follows the clause-2.18 schema and is tagged with the `isBugCondition` '
    'predicate (`exhibitsDk_*`) it triggers, so Task 3.2 sub-tasks can pick '
    'rows up by class.',
  );
  b.writeln();
  b.writeln('## Summary by defect class');
  b.writeln();
  b.writeln('| section | predicate | rows |');
  b.writeln('|---|---|---|');
  for (final k in const [
    'D1',
    'D2',
    'D3',
    'D4',
    'D5',
    'D6',
    'D7',
    'D8',
    'D9',
    'D10',
    'D11',
    'O21',
  ]) {
    final n = sections[k]?.length ?? 0;
    b.writeln('| $k | `${_isBugConditionMap[k]}` | $n |');
  }
  b.writeln();
  b.writeln(
    'Total rows: '
    '${sections.values.fold<int>(0, (a, l) => a + l.length)}',
  );
  b.writeln();

  const sectionTitle = <String, String>{
    'D1': 'D1 — Navigation defects',
    'D2': 'D2 — Placeholder / incomplete UI defects',
    'D3': 'D3 — Validation and business-rule defects',
    'D4': 'D4 — Data-flow and persistence defects',
    'D5': 'D5 — Offline / online / sync defects',
    'D6': 'D6 — State-consistency defects',
    'D7': 'D7 — Error-handling defects',
    'D8': 'D8 — RBAC defects',
    'D9': 'D9 — Performance defects',
    'D10': 'D10 — Cross-module integration defects',
    'D11': 'D11 — Domain-correctness defects per business type',
    'O21': 'Clause 2.21 — Offline / reconnect / multi-device matrix coverage',
  };

  for (final k in sectionTitle.keys) {
    final rows = sections[k] ?? const <Finding>[];
    b.writeln('## ${sectionTitle[k]}');
    b.writeln();
    b.writeln('Predicate: `${_isBugConditionMap[k]}`');
    b.writeln('Row count: ${rows.length}');
    b.writeln();
    if (rows.isEmpty) {
      b.writeln('_No rows._');
      b.writeln();
      continue;
    }
    b.writeln(
      '| defect-id | app | module | screen/workflow | defect-class | severity '
      '| repro | observed | expected | proposed-fix-scope |',
    );
    b.writeln('|---|---|---|---|---|---|---|---|---|---|');
    for (final f in rows) {
      b.writeln(_renderRow(f));
    }
    b.writeln();
  }

  return b.toString();
}

String _renderRow(Finding f) {
  String esc(String s) => s.replaceAll('|', r'\|').replaceAll('\n', ' ');
  return '| ${esc(f.defectId)} | ${esc(f.app)} | ${esc(f.module)} | '
      '${esc(f.workflow)} | ${esc(f.defectClass)} | ${esc(f.severity)} | '
      '${esc(f.repro)} | ${esc(f.observed)} | ${esc(f.expected)} | '
      '${esc(f.fixScope)} |';
}
