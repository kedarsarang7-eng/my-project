// ============================================================================
// MODE ISOLATION — unit + architecture-review tests (Task 1.7)
// ============================================================================
// Feature: offline-license-activation
//
// This file proves two design invariants of the Mode_Manager switch point:
//
//   1. UNIT (Requirement 1.1): the application supports EXACTLY two
//      Operating_Mode values — Offline_Lifetime_Mode and
//      Cloud_Subscription_Mode. There is no third mode.
//
//   2. ARCHITECTURE REVIEW (Requirements 1.6, 1.7): the Flutter UI layer
//      (screens / widgets / feature-presentation code) NEVER references the
//      active operating mode or the active backend target. All online/offline
//      switching is confined to the service layer (`lib/core/mode/**` and the
//      single switch point `lib/core/api/api_client.dart`). The UI therefore
//      operates identically in either mode (zero Flutter UI changes).
//
//      This is enforced as an import/dependency lint: the test reads the
//      lib/ UI-layer source files from disk and asserts none of them import
//      `core/mode/mode_manager.dart` or reference the mode/target symbols
//      (`OperatingMode`, `ModeManager`, `activeBackendBaseUri`, or the
//      Local_Backend loopback `127.0.0.1:8765`).
//
// Not a property-based test — this is a deterministic unit + static
// architecture review per the task list and the design's prework
// classification.
// ============================================================================

import 'dart:io';

import 'package:dukanx/core/mode/mode_manager.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../audit/audit_walker.dart'
    show resolveWorkspaceRoot, listDartFiles, safeRead;

void main() {
  // ──────────────────────────────────────────────────────────────────────
  // 1. UNIT — exactly two Operating_Mode values (Requirement 1.1)
  // ──────────────────────────────────────────────────────────────────────
  group('OperatingMode value set (Req 1.1)', () {
    test('declares exactly two operating modes', () {
      expect(
        OperatingMode.values.length,
        2,
        reason:
            'Requirement 1.1: the application SHALL support exactly two '
            'Operating_Mode values. A third mode breaks the single '
            'switch-point invariant.',
      );
    });

    test(
      'the two modes are Offline_Lifetime_Mode and Cloud_Subscription_Mode',
      () {
        expect(
          OperatingMode.values.toSet(),
          {OperatingMode.offlineLifetime, OperatingMode.cloudSubscription},
          reason:
              'Requirement 1.1: the only valid modes are Offline_Lifetime_Mode '
              'and Cloud_Subscription_Mode.',
        );
      },
    );
  });

  // ──────────────────────────────────────────────────────────────────────
  // 2. ARCHITECTURE REVIEW — UI layer is mode/target agnostic (Req 1.6, 1.7)
  // ──────────────────────────────────────────────────────────────────────
  group('UI layer cannot reference the active mode/target (Req 1.6, 1.7)', () {
    late Directory libDir;
    late List<File> uiLayerFiles;

    setUpAll(() {
      final ws = resolveWorkspaceRoot();
      libDir = Directory('${ws.path}/Dukan_x/lib');
      expect(
        libDir.existsSync(),
        isTrue,
        reason: 'Expected Dukan_x/lib at ${libDir.path}',
      );

      uiLayerFiles = listDartFiles(
        libDir,
      ).where((f) => _isUiLayerFile(_libRelative(libDir, f))).toList();
    });

    test('the UI-layer scan is non-vacuous (finds real screens/widgets)', () {
      // Guards against a refactor that silently empties the scan set and turns
      // the architecture review into a no-op.
      expect(
        uiLayerFiles.length,
        greaterThan(50),
        reason:
            'Expected to scan a substantial set of UI-layer files '
            '(screens/widgets/feature presentation). Found '
            '${uiLayerFiles.length}; the heuristic may have stopped matching.',
      );
    });

    test('no UI-layer file imports core/mode/mode_manager.dart', () {
      final violations = <String>[];

      for (final file in uiLayerFiles) {
        final src = safeRead(file);
        final lines = src.split('\n');
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (_modeManagerImport.hasMatch(line)) {
            violations.add(
              '${_libRelative(libDir, file)}:${i + 1}  ${line.trim()}',
            );
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Requirement 1.6/1.7: the Flutter UI layer must not depend on '
            'Mode_Manager. The mode switch lives in the service layer '
            '(lib/core/mode/** and lib/core/api/api_client.dart). Offending '
            'import(s):\n  ${violations.join('\n  ')}',
      );
    });

    test('no UI-layer file references the active mode or backend target', () {
      // Each entry: human-readable name -> matcher for a forbidden reference.
      final forbidden = <String, RegExp>{
        'OperatingMode': RegExp(r'\bOperatingMode\b'),
        'ModeManager': RegExp(r'\bModeManager\b'),
        'activeBackendBaseUri': RegExp(r'\bactiveBackendBaseUri\b'),
        'loopback target 127.0.0.1:8765': RegExp(r'127\.0\.0\.1:8765'),
      };

      final violations = <String>[];

      for (final file in uiLayerFiles) {
        final src = safeRead(file);
        final lines = src.split('\n');
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          for (final entry in forbidden.entries) {
            if (entry.value.hasMatch(line)) {
              violations.add(
                '${_libRelative(libDir, file)}:${i + 1}  '
                '[${entry.key}]  ${line.trim()}',
              );
            }
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Requirement 1.6/1.7: the active Operating_Mode and the active '
            'backend target must be confined to the service/repository layer '
            'and never reach the UI. Offending reference(s):\n  '
            '${violations.join('\n  ')}',
      );
    });

    test('the mode/target symbols DO live in the service layer (sanity)', () {
      // Confirms the scan is meaningful: the symbols the UI must not use are
      // genuinely defined in the service layer, so a clean UI scan is a real
      // isolation guarantee rather than the symbols simply not existing.
      final modeManagerSrc = safeRead(
        File('${libDir.path}/core/mode/mode_manager.dart'),
      );
      expect(
        modeManagerSrc.contains('enum OperatingMode'),
        isTrue,
        reason:
            'Expected OperatingMode to be defined in core/mode/mode_manager.dart',
      );
      expect(
        modeManagerSrc.contains('activeBackendBaseUri'),
        isTrue,
        reason:
            'Expected the backend-target resolver activeBackendBaseUri in the '
            'service layer.',
      );
    });
  });
}

/// Matches a Dart `import`/`export` directive that pulls in the Mode_Manager
/// source — whether referenced as a package import
/// (`package:dukanx/core/mode/mode_manager.dart`), a relative import
/// (`../mode/mode_manager.dart`), or any path ending in
/// `core/mode/mode_manager.dart`. The UI layer must never match this.
final RegExp _modeManagerImport = RegExp(
  r'''^\s*(?:import|export)\s+['"][^'"]*mode/mode_manager\.dart['"]''',
);

/// Path of [file] relative to `Dukan_x/lib`, using forward slashes so the
/// classification heuristic is platform independent.
String _libRelative(Directory libDir, File file) {
  final p = file.path.replaceAll('\\', '/');
  final root = libDir.path.replaceAll('\\', '/');
  return p.startsWith('$root/') ? p.substring(root.length + 1) : p;
}

/// True when a lib-relative path belongs to the Flutter UI layer
/// (screens / widgets / components / feature-presentation code).
///
/// Service-layer locations (`core/`, `services/`, `data/`, `providers/`,
/// `security/`, `guards/`, `config/`) are intentionally excluded — those are
/// allowed to resolve and route the active mode/target. In particular the
/// single switch point `core/api/api_client.dart` and `core/mode/**` are NOT
/// part of the UI layer.
bool _isUiLayerFile(String relPath) {
  // Never treat service-layer roots as UI, even if a file happens to be named
  // like a widget.
  const serviceRoots = <String>[
    'core/',
    'services/',
    'data/',
    'providers/',
    'security/',
    'guards/',
    'config/',
    'models/',
  ];
  for (final root in serviceRoots) {
    if (relPath.startsWith(root)) return false;
  }

  // Presentation/UI directories anywhere under lib (incl. feature presentation
  // such as `features/<x>/presentation/screens/...`).
  if (relPath.contains('/presentation/')) return true;
  if (relPath.startsWith('screens/') || relPath.contains('/screens/')) {
    return true;
  }
  if (relPath.startsWith('widgets/') || relPath.contains('/widgets/')) {
    return true;
  }
  if (relPath.startsWith('components/') || relPath.contains('/components/')) {
    return true;
  }

  // Conventionally named UI files anywhere (e.g. onboarding screens that are
  // not under a presentation/ folder).
  if (relPath.endsWith('_screen.dart')) return true;
  if (relPath.endsWith('_page.dart')) return true;
  if (relPath.endsWith('_widget.dart')) return true;
  if (relPath.endsWith('_view.dart')) return true;

  return false;
}
