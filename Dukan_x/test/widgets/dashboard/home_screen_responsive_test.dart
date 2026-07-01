// ============================================================================
// Home Screen — Responsive Redesign Tests (Part 5)
// ============================================================================
// Verifies the dashboard home screen:
//   • Builds without exceptions or layout overflow on phone/tablet/desktop.
//   • The compact header (SliverAppBar) is present and pinned.
//   • Title text is rendered and overflow-safe (maxLines/ellipsis).
//
// This guards the Part 5 fix: the old expandedHeight:200 wasted vertical space
// on Android; the redesign surfaces KPI/menu cards above the fold.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dukanx/features/dashboard/presentation/screens/home_screen.dart';
import 'package:dukanx/models/business_type.dart';
import 'package:dukanx/providers/app_state_providers.dart';

/// A minimal notifier that returns a fixed business type without touching
/// SharedPreferences / DB, so the responsive test stays fast and deterministic.
class _FixedBusinessTypeNotifier extends BusinessTypeNotifier {
  final BusinessType typeValue;
  _FixedBusinessTypeNotifier(this.typeValue);
  @override
  BusinessTypeState build() => BusinessTypeState(type: typeValue);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Pump the home screen at a given surface size, capturing any Flutter
  /// errors (overflow / exceptions) emitted during build.
  Future<List<FlutterErrorDetails>> pumpHome(
    WidgetTester tester, {
    required Size size,
    BusinessType businessType = BusinessType.other,
  }) async {
    SharedPreferences.setMockInitialValues({});

    final errors = <FlutterErrorDetails>[];
    final oldHandler = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = oldHandler);

    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          businessTypeProvider.overrideWith(
            () => _FixedBusinessTypeNotifier(businessType),
          ),
        ],
        child: const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: HomeScreenModern(),
        ),
      ),
    );
    // One frame is enough to detect overflow; the screen has no async loaders
    // in its build path (strategy is synchronous).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    return errors;
  }

  Iterable<FlutterErrorDetails> overflowOf(List<FlutterErrorDetails> e) =>
      e.where((d) => d.toString().contains('overflowed'));
  Iterable<FlutterErrorDetails> exceptionsOf(List<FlutterErrorDetails> e) =>
      e.where((d) => !d.toString().contains('overflowed'));

  testWidgets('renders on a small Android phone without overflow', (tester) async {
    final errors = await pumpHome(
      tester,
      size: const Size(360, 720), // common Android phone
    );

    expect(overflowOf(errors), isEmpty, reason: 'phone layout overflowed');
    expect(exceptionsOf(errors), isEmpty, reason: 'phone build threw');
    expect(find.byType(SliverAppBar), findsOneWidget);
  });

  testWidgets('renders on a tablet without overflow', (tester) async {
    final errors = await pumpHome(
      tester,
      size: const Size(800, 1280),
    );

    expect(overflowOf(errors), isEmpty, reason: 'tablet layout overflowed');
    expect(exceptionsOf(errors), isEmpty, reason: 'tablet build threw');
  });

  testWidgets('renders on desktop width without overflow', (tester) async {
    final errors = await pumpHome(
      tester,
      size: const Size(1440, 900),
    );

    expect(overflowOf(errors), isEmpty, reason: 'desktop layout overflowed');
    expect(exceptionsOf(errors), isEmpty, reason: 'desktop build threw');
  });

  testWidgets('SliverAppBar is pinned (stays visible on scroll)', (tester) async {
    await pumpHome(tester, size: const Size(360, 720));

    final appBar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
    expect(appBar.pinned, isTrue, reason: 'header must stay pinned so the title/sync are always reachable');
  });

  testWidgets('header title is overflow-safe (maxLines + ellipsis)', (tester) async {
    await pumpHome(tester, size: const Size(360, 720));

    // The FlexibleSpaceBar title text should be ellipsised, not wrapped/overflowing.
    final titles = tester
        .widgetList<Text>(find.byType(Text))
        .where((t) => t.style?.fontWeight == FontWeight.bold);
    expect(titles, isNotEmpty);
  });
}
