// ============================================================================
// AppScaffold — Back Navigation Behavior Tests (Part 6)
// ============================================================================
// Verifies the centralized navigation shell:
//   • Normal pop: back button pops when there is nothing to guard.
//   • Unsaved-changes guard: "Discard?" dialog appears; Cancel keeps the user,
//     Discard pops.
//   • Root double-back-to-exit: first back shows a toast and blocks; a second
//     back within the grace window would allow exit.
//   • AppBar back button is shown only when the route can pop.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/widgets/app_scaffold.dart';

void main() {
  /// Wrap [child] in a Navigator so AppScaffold can push/pop and we can detect
  /// whether a pop actually happened via a sentinel result.
  Widget harness(Widget child) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Builder(
        builder: (context) => ElevatedButton(
          key: const Key('push'),
          onPressed: () {
            Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => child,
                fullscreenDialog: false,
              ),
            );
          },
          child: const Text('push'),
        ),
      ),
    );
  }

  testWidgets('back button pops when there are no guards', (tester) async {
    await tester.pumpWidget(harness(
      const AppScaffold(title: 'Child', body: Center(child: Text('body'))),
    ));

    // Push the child screen.
    await tester.tap(find.byKey(const Key('push')));
    await tester.pumpAndSettle();
    expect(find.text('body'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

    // Tap the AppBar back button → should pop back to the push button.
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    expect(find.text('body'), findsNothing);
    expect(find.byKey(const Key('push')), findsOneWidget);
  });

  testWidgets('unsaved-changes guard: Cancel keeps the user on screen',
      (tester) async {
    await tester.pumpWidget(harness(
      const AppScaffold(
        title: 'Edit',
        body: Center(child: Text('editing')),
        hasUnsavedChanges: true,
      ),
    ));

    await tester.tap(find.byKey(const Key('push')));
    await tester.pumpAndSettle();

    // Press back → discard dialog appears.
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsOneWidget);

    // Choose "Keep Editing" → stay on screen.
    await tester.tap(find.text('Keep Editing'));
    await tester.pumpAndSettle();

    expect(find.text('editing'), findsOneWidget);
    expect(find.byKey(const Key('push')), findsNothing);
  });

  testWidgets('unsaved-changes guard: Discard pops the screen', (tester) async {
    await tester.pumpWidget(harness(
      const AppScaffold(
        title: 'Edit',
        body: Center(child: Text('editing')),
        hasUnsavedChanges: true,
      ),
    ));

    await tester.tap(find.byKey(const Key('push')));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    // Confirm discard.
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(find.text('editing'), findsNothing);
    expect(find.byKey(const Key('push')), findsOneWidget);
  });

  testWidgets('root screen: first back shows exit toast and does NOT pop',
      (tester) async {
    // A root screen rendered directly in MaterialApp (no push) cannot pop.
    await tester.pumpWidget(const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AppScaffold(
        title: 'Home',
        body: Center(child: Text('home')),
        isRoot: true,
      ),
    ));

    // No back button on a root route (canPop == false).
    expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);

    // Simulate the Android system back button.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    // First press → toast shown, still on screen.
    expect(find.text('Press back again to exit'), findsOneWidget);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('renders title with overflow protection', (tester) async {
    const longTitle =
        'A Very Long Screen Title That Should Truncate Nicely Instead Of Overflowing';
    await tester.pumpWidget(harness(
      const AppScaffold(title: longTitle, body: SizedBox.shrink()),
    ));

    await tester.tap(find.byKey(const Key('push')));
    await tester.pumpAndSettle();

    final text = tester.widgetList<Text>(find.byType(Text)).firstWhere(
      (t) => t.data == longTitle,
    );
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
  });
}
