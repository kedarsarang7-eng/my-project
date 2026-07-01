// PROPERTY 1: BUG CONDITION — End-to-End Audit Surfaces Defects D1..D11.
//
// This test MUST FAIL on unfixed code; each failure is one inventory row
// in the clause-2.18 schema. The orchestrator records the failures as the
// defect inventory and proceeds to Task 2 — the test is NOT fixed here.
//
// Methodology: a deterministic per-module static walk (clause 1.* of
// `bugfix.md`) over the four Flutter apps (`Dukan_x`,
// `school_admin_app`, `school_teacher_app`, `school_student_app`), one
// `test()` per defect class D1..D11 plus one for the
// offline/reconnect/multi-device matrix (clause 2.21). When a sub-test
// fails the printed payload is already shaped as the inventory rows that
// Task 3.1 lifts into `.kiro/specs/.../audit/defect-inventory.md`.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'audit_walker.dart';

void main() {
  late final Directory ws;

  setUpAll(() {
    ws = resolveWorkspaceRoot();
  });

  // -------------------------------------------------------------------------
  // D1 — Navigation walk (negation of clauses 1.1, 1.2)
  // -------------------------------------------------------------------------
  test('D1 navigation: every registered route resolves to a built screen', () {
    final findings = <Finding>[];

    // Dukan_x: every module's `*_routes.dart` is currently a list of
    // GoRoutes pointing to `ModulePlaceholderScreen` ("Coming soon").
    // That is a dead-end destination by definition (clause 1.1).
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
          // Scope the lookahead to the immediately-following builder body
          // so we don't spill into the next GoRoute's placeholder.
          final maxEnd = (r.end + 200).clamp(0, src.length);
          final tail = src.substring(r.end, maxEnd);
          final closeIdx = tail.indexOf('),');
          final lineSrc = closeIdx >= 0
              ? src.substring(r.start, r.end + closeIdx + 1)
              : src.substring(r.start, maxEnd);
          if (lineSrc.contains('ModulePlaceholderScreen')) {
            findings.add(
              Finding(
                defectId: 'D1-DKX-$m-${path.hashCode.toUnsigned(16)}',
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

    // Dukan_x: `go_router` is not declared in `Dukan_x/pubspec.yaml` yet
    // every `lib/modules/<m>/routes/*_routes.dart` imports it — these
    // route files cannot compile, so every registered route is unreachable.
    final pubspec = File('${ws.path}/Dukan_x/pubspec.yaml').readAsStringSync();
    if (!RegExp(r'^\s*go_router:', multiLine: true).hasMatch(pubspec)) {
      findings.add(
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

    // school_admin / teacher / student: every GoRoute(path: '/x') target
    // must resolve to a screen file under `lib/features/<m>/screens/`.
    for (final app in auditedApps.where((a) => a != 'Dukan_x')) {
      final router = File('${ws.path}/$app/lib/core/router/app_router.dart');
      if (!router.existsSync()) continue;
      final src = router.readAsStringSync();
      final routes = RegExp(r"GoRoute\(path:\s*'([^']+)'").allMatches(src);
      for (final r in routes) {
        final path = r.group(1)!;
        // Map path to the screen widget invoked on the same line.
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
          findings.add(
            Finding(
              defectId: 'D1-$app-${path.hashCode.toUnsigned(16)}',
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

    expect(findings, isEmpty, reason: renderInventory('D1', findings));
  });

  // -------------------------------------------------------------------------
  // D2 — Placeholder / incomplete UI sweep (negation of 1.3, 1.4)
  // -------------------------------------------------------------------------
  test('D2 placeholder sweep: no TODO/Coming-soon/lorem in shipped UI', () {
    final findings = <Finding>[];

    // Pattern set covering each clause-1.3 manifestation.
    final patterns = <String, RegExp>{
      'Coming soon string': RegExp(
        r"['"
        "\"]Coming soon['"
        "\"]",
        caseSensitive: false,
      ),
      'TODO comment in UI': RegExp(r'//\s*TODO\b'),
      'lorem ipsum filler': RegExp(r'\blorem ipsum\b', caseSensitive: false),
      'placeholder marker': RegExp(
        r"['"
        "\"]Placeholder\b",
        caseSensitive: false,
      ),
      'hardcoded dummy text': RegExp(
        r"['"
        "\"](?:dummy|sample|tests+only)\b",
        caseSensitive: false,
      ),
    };

    for (final app in auditedApps) {
      final libDir = Directory('${ws.path}/$app/lib');
      if (!libDir.existsSync()) continue;
      for (final f in listDartFiles(libDir)) {
        final p = f.path.replaceAll('\\', '/');
        // Limit to UI surface — screens, widgets, modals, dialogs.
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
          // Skip strings inside `_test.dart` files and translation tables.
          if (p.endsWith('_test.dart')) continue;
          final lineNo = '\n'.allMatches(src.substring(0, m.start)).length + 1;
          findings.add(
            Finding(
              defectId: 'D2-$app-${p.hashCode.toUnsigned(16)}-$lineNo',
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
          // One row per file per pattern is enough for inventory purposes.
        }
      }
    }

    expect(findings, isEmpty, reason: renderInventory('D2', findings));
  });

  // -------------------------------------------------------------------------
  // D3 — Validation & business-rule sweep (negation of 1.5, 1.6)
  // -------------------------------------------------------------------------
  test('D3 validation: monetary math does not use raw double arithmetic', () {
    final findings = <Finding>[];

    // Heuristic: any service / utils file whose name suggests money math
    // (gst, billing, invoice, totalizer, fee, ledger) MUST use the
    // `decimal` package or paise integers — never raw `double`.
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
        if (src.contains('package:decimal/decimal.dart')) continue;
        // Already routes accumulation through MoneyMath — output `double`
        // declarations are containers, not raw arithmetic.
        if (src.contains('core/accounting/money_math.dart') &&
            src.contains('MoneyMath.')) {
          continue;
        }
        // Or already uses paise-integer math.
        if (RegExp(r'\bint\s+toPaisa\s*\(').hasMatch(src) ||
            RegExp(r'\bpaisa\b', caseSensitive: false).hasMatch(src)) {
          continue;
        }
        // Look for raw double arithmetic on identifiers that look monetary.
        final usesDouble = RegExp(
          r'\bdouble\s+(amount|total|price|tax|cgst|sgst|igst|net|'
          r'gross|discount|rate|fee|commission|due)\b',
        ).hasMatch(src);
        if (!usesDouble) continue;
        // Heuristic refinement: only flag files where a money-keyword
        // double is mutated via `+=` (real arithmetic) — `final double X`
        // model fields are not buggy on their own.
        final hasAccumulator = RegExp(
          r'\b(amount|total|price|tax|cgst|sgst|igst|net|gross|discount|rate|'
          r'fee|commission|due)\w*\s*\+=',
          caseSensitive: false,
        ).hasMatch(src);
        if (!hasAccumulator) continue;
        findings.add(
          Finding(
            defectId: 'D3-$app-${p.hashCode.toUnsigned(16)}',
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

    expect(findings, isEmpty, reason: renderInventory('D3', findings));
  });

  // -------------------------------------------------------------------------
  // D4–D6 — Data-flow / sync / state sweep (negation of 1.7..1.11)
  // -------------------------------------------------------------------------
  test('D4 data flow: repositories invalidate provider state on mutations', () {
    final findings = <Finding>[];

    for (final app in auditedApps) {
      final repos = Directory('${ws.path}/$app/lib').existsSync()
          ? listDartFiles(Directory('${ws.path}/$app/lib'))
                .where(
                  (f) =>
                      f.path.replaceAll('\\', '/').contains('/repositories/'),
                )
                .toList()
          : <File>[];
      for (final f in repos) {
        final src = safeRead(f);
        // A mutation method (create/update/delete/save) without an
        // accompanying invalidate / refresh / notifyListeners call is the
        // canonical D4 failure (clause 1.8).
        final mutates = RegExp(
          r'\b(?:Future|void)\s+(?:create|update|delete|save|insert|remove)\w*\(',
        ).hasMatch(src);
        if (!mutates) continue;
        final invalidates =
            src.contains('invalidate(') ||
            src.contains('refresh(') ||
            src.contains('notifyListeners') ||
            src.contains('ref.invalidate') ||
            src.contains('emit(');
        if (invalidates) continue;
        findings.add(
          Finding(
            defectId: 'D4-$app-${f.path.hashCode.toUnsigned(16)}',
            app: app,
            module: detectModule(f),
            workflow: f.path.replaceAll('\\', '/').split('/$app/').last,
            defectClass: 'D4',
            severity: 'critical',
            repro:
                'create a record on the screen owned by this repository, then '
                'navigate to a dependent list and pull-to-refresh',
            observed:
                'mutation methods write to the data store but do not trigger '
                'provider invalidation; dependent screens show stale data',
            expected:
                'atomic write across local + remote + provider state with '
                'invalidation so dependent screens see fresh data (clause '
                '2.7, 2.8)',
            fixScope:
                'wrap mutations in a service that calls `ref.invalidate` for '
                'every dependent provider, with rollback on partial failure',
          ),
        );
      }
    }

    expect(findings, isEmpty, reason: renderInventory('D4', findings));
  });

  test('D5 sync: offline queue ships with idempotency keys', () {
    final findings = <Finding>[];

    for (final app in auditedApps) {
      final libDir = Directory('${ws.path}/$app/lib');
      if (!libDir.existsSync()) continue;
      final candidates = listDartFiles(libDir).where((f) {
        final p = f.path.replaceAll('\\', '/');
        return p.contains('/sync/') ||
            p.endsWith('sync_queue.dart') ||
            p.endsWith('offline_queue.dart');
      }).toList();
      if (candidates.isEmpty) {
        findings.add(
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
                'resolution policy (clause 2.9, 2.10, 2.21)',
            fixScope:
                'introduce a sync-queue service with idempotency keys, '
                'ordered replay, and a recovery UI',
          ),
        );
        continue;
      }
      for (final f in candidates) {
        final src = safeRead(f);
        final hasIdem = RegExp(
          r'idempotenc(y|e)|opId|operationId|requestId',
          caseSensitive: false,
        ).hasMatch(src);
        if (hasIdem) continue;
        findings.add(
          Finding(
            defectId: 'D5-$app-${f.path.hashCode.toUnsigned(16)}',
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

    expect(findings, isEmpty, reason: renderInventory('D5', findings));
  });

  test('D6 state consistency: cross-module providers use ref.watch graphs', () {
    final findings = <Finding>[];
    // Heuristic: any provider file that calls a repository directly inside
    // its body without watching another provider for the same entity is a
    // candidate for stale cross-module reads.
    for (final app in auditedApps) {
      final libDir = Directory('${ws.path}/$app/lib');
      if (!libDir.existsSync()) continue;
      final providers = listDartFiles(libDir).where((f) {
        final p = f.path.replaceAll('\\', '/');
        return p.contains('/providers/') || p.endsWith('_providers.dart');
      }).toList();
      for (final f in providers) {
        final src = safeRead(f);
        // Provider creates state from repository read but never watches
        // any source-of-truth provider — propagation is manual.
        final readsRepo = RegExp(
          r'\.read\(\s*[a-zA-Z_]+(?:Repository|Repo)Provider',
        ).hasMatch(src);
        final watchesNone = !src.contains('ref.watch(');
        if (readsRepo && watchesNone) {
          findings.add(
            Finding(
              defectId: 'D6-$app-${f.path.hashCode.toUnsigned(16)}',
              app: app,
              module: detectModule(f),
              workflow: f.path.replaceAll('\\', '/').split('/$app/').last,
              defectClass: 'D6',
              severity: 'major',
              repro:
                  'open two screens owned by this provider; mutate the entity '
                  'in one and verify the other does not refresh',
              observed:
                  'provider reads from a repository but does not `ref.watch` '
                  'a source-of-truth provider; dependent UIs do not rebuild',
              expected:
                  'derived state propagated via `ref.watch` graphs so writes '
                  'reach every dependent screen (clause 2.11)',
              fixScope:
                  'replace `ref.read` of repository with `ref.watch` of the '
                  'owning notifier provider',
            ),
          );
        }
      }
    }

    expect(findings, isEmpty, reason: renderInventory('D6', findings));
  });

  // -------------------------------------------------------------------------
  // D7 — Error sweep (negation of 1.12)
  // -------------------------------------------------------------------------
  test(
    'D7 error handling: I/O paths catch exceptions and surface messages',
    () {
      final findings = <Finding>[];
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
          // Or wraps I/O via the central IoGuard helper.
          if (src.contains('IoGuard.')) {
            continue;
          }
          findings.add(
            Finding(
              defectId: 'D7-$app-${p.hashCode.toUnsigned(16)}',
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

      expect(findings, isEmpty, reason: renderInventory('D7', findings));
    },
  );

  // -------------------------------------------------------------------------
  // D8 — RBAC sweep (negation of 1.13)
  // -------------------------------------------------------------------------
  test('D8 RBAC: a centralized permission matrix exists and is consulted', () {
    final findings = <Finding>[];
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
        findings.add(
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
            observed:
                'no centralized permissions/rbac module under $app/lib/**',
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
    expect(findings, isEmpty, reason: renderInventory('D8', findings));
  });

  // -------------------------------------------------------------------------
  // D9 — Performance sweep (negation of 1.14)
  // -------------------------------------------------------------------------
  test('D9 performance: list/report screens paginate or page-cursor', () {
    final findings = <Finding>[];
    final scanPattern = RegExp(r'\.scan\(|getAll\(\)|fetchAll\(\)');
    for (final app in auditedApps) {
      final libDir = Directory('${ws.path}/$app/lib');
      if (!libDir.existsSync()) continue;
      for (final f in listDartFiles(libDir)) {
        final p = f.path.replaceAll('\\', '/');
        if (!p.contains('/repositories/') && !p.contains('/services/')) {
          continue;
        }
        final src = safeRead(f);
        if (!scanPattern.hasMatch(src)) continue;
        if (src.contains('limit:') ||
            src.contains('cursor') ||
            src.contains('pagination')) {
          continue;
        }
        findings.add(
          Finding(
            defectId: 'D9-$app-${p.hashCode.toUnsigned(16)}',
            app: app,
            module: detectModule(f),
            workflow: p.split('/$app/').last,
            defectClass: 'D9',
            severity: 'major',
            repro:
                'seed >=5k records and open the list/report screen owned by '
                'this service',
            observed:
                'unbounded scan/fetchAll without limit+cursor; UI blocks '
                'while the full set is materialized',
            expected:
                'paginated, indexed query with documented budgets — first '
                'frame within 1s, sustained 60fps (clause 2.14)',
            fixScope:
                'introduce limit + cursor (or DynamoDB ExclusiveStartKey) '
                'and offload heavy work to compute()/isolate',
          ),
        );
      }
    }
    expect(findings, isEmpty, reason: renderInventory('D9', findings));
  });

  // -------------------------------------------------------------------------
  // D10 — Cross-module sweep (negation of 1.15)
  // -------------------------------------------------------------------------
  test('D10 cross-module: every saga has a transactional owner service', () {
    final findings = <Finding>[];
    // Required cross-module sagas (design.md § Testing Strategy / D10).
    const sagas = <String, List<String>>{
      'billing -> inventory -> ledger -> GST report': ['billing', 'inventory'],
      'school fee -> payment -> receipt -> ledger': ['fees', 'payment'],
      'purchase -> stock -> vendor ledger': ['purchase', 'stock'],
      'jewellery old-gold-exchange -> bill -> stock': [
        'jewellery',
        'inventory',
      ],
      'restaurant KOT -> bill -> kitchen': ['restaurant'],
      'pharmacy -> patient -> bill': ['pharmacy', 'patient'],
      'auto/computer service -> job-card -> bill -> warranty': [
        'auto_parts',
        'computer_shop',
      ],
    };
    for (final entry in sagas.entries) {
      final saga = entry.key;
      final modules = entry.value;
      final libDir = Directory('${ws.path}/Dukan_x/lib');
      final files = listDartFiles(libDir);
      final hasSagaService = files.any((f) {
        final p = f.path.replaceAll('\\', '/');
        return p.contains('/services/') &&
            (p.contains('saga') ||
                p.contains('orchestrator') ||
                p.contains('transactional'));
      });
      if (hasSagaService) continue;
      findings.add(
        Finding(
          defectId: 'D10-${saga.hashCode.toUnsigned(16)}',
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
    expect(findings, isEmpty, reason: renderInventory('D10', findings));
  });

  // -------------------------------------------------------------------------
  // D11 — Domain correctness per business type (negation of 1.16)
  // -------------------------------------------------------------------------
  test(
    'D11 domain correctness: every vertical has a *_business_rules file',
    () {
      final findings = <Finding>[];
      // Per-vertical signature workflow checks: a centralized business-rule
      // helper is required so per-vertical formulas (jewellery purity,
      // petrol totalizer, KOT split, fee pro-rata, batch/expiry, etc.) live
      // in one auditable place.
      for (final m in dukanxModules) {
        final featDir = Directory('${ws.path}/Dukan_x/lib/features/$m');
        if (!featDir.existsSync()) {
          // some module names differ between modules/ and features/
          continue;
        }
        final files = listDartFiles(featDir);
        final hasRules = files.any(
          (f) =>
              f.path.replaceAll('\\', '/').endsWith('_business_rules.dart') ||
              f.path.replaceAll('\\', '/').endsWith('${m}_business_rules.dart'),
        );
        if (hasRules) continue;
        findings.add(
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
      expect(findings, isEmpty, reason: renderInventory('D11', findings));
    },
  );

  // -------------------------------------------------------------------------
  // Offline / reconnect / multi-device matrix (clause 2.21)
  // -------------------------------------------------------------------------
  test(
    'clause 2.21 offline matrix: every offline-capable module is covered',
    () {
      final findings = <Finding>[];
      // Offline-capable modules per design.md — anything with a customer-
      // facing CRUD surface qualifies.
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
      final libDir = Directory('${ws.path}/Dukan_x/lib');
      final files = listDartFiles(libDir);
      for (final m in offlineCapable) {
        // Look for any test file under Dukan_x/test/ that targets this
        // module's offline matrix (offline create/edit/delete + reconnect +
        // multi-device + flaky-network + forced-kill + large-batch).
        final testDir = Directory('${ws.path}/Dukan_x/test');
        final testFiles = testDir.existsSync()
            ? listDartFiles(testDir)
            : <File>[];
        final hasMatrixTest = testFiles.any((f) {
          final p = f.path.replaceAll('\\', '/');
          return p.contains('/$m/') && p.contains('offline');
        });
        if (hasMatrixTest) continue;
        // Also consider the lib-side: if no /sync/ harness covers the module,
        // record the gap.
        final hasSyncHarness = files.any((f) {
          final p = f.path.replaceAll('\\', '/');
          return p.contains('/$m/') && p.contains('sync');
        });
        if (hasSyncHarness && false) continue; // never skip for now
        findings.add(
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
      expect(
        findings,
        isEmpty,
        reason: renderInventory('clause 2.21', findings),
      );
    },
  );
}

extension on int {
  /// Compact signed-int hash to a fixed-width hex tag for inventory IDs.
  String toUnsigned(int width) {
    final v = this & ((1 << width) - 1);
    return v.toRadixString(16).padLeft((width / 4).ceil(), '0');
  }
}
