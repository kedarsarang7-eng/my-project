// ============================================================================
// PHASE 3 — Task 15.2: CANONICAL NARCOTIC REGISTER SCREEN TEST
// Feature: pharmacy-vertical-remediation
// **Validates: Requirements 18.5**
// ============================================================================
//
// Requirement 18.5 (requirements.md — De-Duplicate NarcoticRegisterScreen):
//   THE System SHALL include an automated test that renders the canonical
//   `NarcoticRegisterScreen` without error and asserts that the resolved screen
//   reference is the canonical definition, and the test SHALL report pass or
//   fail.
//
// CONTEXT (Task 15.1):
//   The duplicate under `features/prescriptions/presentation/screens/` was
//   removed, leaving a single canonical definition at
//   `lib/features/pharmacy/screens/narcotic_register_screen.dart`.
//
// WHAT THIS PROVES:
//   1. The import path `package:dukanx/features/pharmacy/screens/
//      narcotic_register_screen.dart` resolves to exactly one
//      `NarcoticRegisterScreen` class (compile-time canonicity).
//   2. Pumping that screen inside a `MaterialApp` renders without throwing.
//   3. The resolved widget instance is an instance of the canonical
//      `NarcoticRegisterScreen` type.
//
// SEAM / SETUP:
//   - The screen's field initializer resolves `sl<SessionManager>()`, so a
//     `FakeSessionManager` (the repo-wide `extends Mock implements
//     SessionManager` pattern) is registered in GetIt before pumping.
//   - `initState` opens a Hive box (`Hive.openBox`), so Hive is initialized to
//     a temp directory for the test. No Firebase / no real IO beyond the temp
//     box.
//
// Run: flutter test test/features/pharmacy/narcotic_register_screen_canonical_test.dart
// ============================================================================

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mockito/mockito.dart';

import 'package:dukanx/core/session/session_manager.dart';
import 'package:dukanx/widgets/desktop/sidebar_navigation_handler.dart';
// Canonical import path under test (R18.5).
import 'package:dukanx/features/pharmacy/screens/narcotic_register_screen.dart';

/// Lightweight fake [SessionManager]; `NarcoticRegisterScreen` only needs the
/// service to resolve from GetIt in its field initializer. `Mock` provides
/// no-op `noSuchMethod` for every other member.
class _FakeSessionManager extends Mock implements SessionManager {
  @override
  String? get currentBusinessId => 'tenant-test';
}

void main() {
  final GetIt sl = GetIt.instance;
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Hive is opened inside the screen's initState; back it with a temp dir.
    tempDir = await Directory.systemTemp.createTemp('narcotic_register_test');
    Hive.init(tempDir.path);

    if (!sl.isRegistered<SessionManager>()) {
      sl.registerSingleton<SessionManager>(_FakeSessionManager());
    }
  });

  tearDownAll(() async {
    await Hive.close();
    if (sl.isRegistered<SessionManager>()) {
      await sl.unregister<SessionManager>();
    }
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {
      // best-effort cleanup
    }
  });

  group('Feature: pharmacy-vertical-remediation, R18.5: canonical '
      'NarcoticRegisterScreen', () {
    testWidgets('renders without error and resolves to the canonical '
        'definition', (tester) async {
      // Desktop-sized surface so the register's data table/app bar lay out
      // without overflow during the test.
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Render the canonical screen.
      await tester.pumpWidget(
        const MaterialApp(home: NarcoticRegisterScreen()),
      );

      // initState starts an async Hive load; advance frames to let it settle
      // without using pumpAndSettle (the loading spinner animates forever).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // R18.5: rendered without error.
      expect(
        tester.takeException(),
        isNull,
        reason:
            'Canonical NarcoticRegisterScreen must render without throwing.',
      );

      // R18.5: the resolved screen reference is the canonical definition.
      final Finder screenFinder = find.byType(NarcoticRegisterScreen);
      expect(screenFinder, findsOneWidget);

      final Widget resolved = tester.widget(screenFinder);
      expect(resolved, isA<NarcoticRegisterScreen>());
      expect(resolved.runtimeType, NarcoticRegisterScreen);
    });

    testWidgets('the narcotic_register sidebar id resolves to the canonical '
        'NarcoticRegisterScreen', (tester) async {
      // Capture a real BuildContext exactly as the desktop shell drives the
      // sidebar resolver. tryGetScreenForItem synchronously constructs a
      // `const` widget (no build(), no GetIt, no IO).
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              context = ctx;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final Widget? resolved = SidebarNavigationHandler.tryGetScreenForItem(
        'narcotic_register',
        context,
      );

      // R18.5 / Task 15.1: the sidebar reference resolves to the canonical
      // screen, never null and never a placeholder.
      expect(
        resolved,
        isNotNull,
        reason: "'narcotic_register' must resolve to a real screen.",
      );
      expect(resolved, isA<NarcoticRegisterScreen>());
      expect(resolved.runtimeType, NarcoticRegisterScreen);
    });
  });
}
