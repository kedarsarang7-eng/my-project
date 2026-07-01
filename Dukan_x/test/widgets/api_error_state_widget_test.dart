import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/widgets/api_error_state_widget.dart';

void main() {
  group('ApiErrorType enum', () {
    test('has all expected values', () {
      expect(
        ApiErrorType.values,
        containsAll([
          ApiErrorType.auth,
          ApiErrorType.network,
          ApiErrorType.server,
          ApiErrorType.unknown,
        ]),
      );
      expect(ApiErrorType.values.length, 4);
    });
  });

  group('classifyError()', () {
    test('classifies 401 as auth error', () {
      expect(
        classifyError('ApiException(401): Unknown error'),
        ApiErrorType.auth,
      );
    });

    test('classifies 403 as auth error', () {
      expect(classifyError('ApiException(403): Forbidden'), ApiErrorType.auth);
    });

    test('classifies SocketException as network error', () {
      expect(
        classifyError('SocketException: Connection refused'),
        ApiErrorType.network,
      );
    });

    test('classifies timeout as network error', () {
      expect(
        classifyError('Connection timeout after 30000ms'),
        ApiErrorType.network,
      );
    });

    test('classifies 500 as server error', () {
      expect(
        classifyError('ApiException(500): Internal server error'),
        ApiErrorType.server,
      );
    });

    test('classifies 502 as server error', () {
      expect(
        classifyError('ApiException(502): Bad Gateway'),
        ApiErrorType.server,
      );
    });

    test('classifies unknown errors as unknown', () {
      expect(
        classifyError('Something unexpected happened'),
        ApiErrorType.unknown,
      );
    });

    test('classifies null-like error as unknown', () {
      expect(classifyError('null'), ApiErrorType.unknown);
    });

    test('handles Exception objects via toString()', () {
      final exception = Exception('SocketException: failed');
      expect(classifyError(exception), ApiErrorType.network);
    });

    test('handles FormatException as unknown', () {
      expect(
        classifyError(const FormatException('bad format')),
        ApiErrorType.unknown,
      );
    });
  });

  group('userMessageFor()', () {
    test('returns session expired message for auth errors', () {
      expect(
        userMessageFor(ApiErrorType.auth),
        'Session expired. Please try again or re-login.',
      );
    });

    test('returns network error message for network errors', () {
      expect(
        userMessageFor(ApiErrorType.network),
        'Network error. Check your connection and retry.',
      );
    });

    test('returns server error message for server errors', () {
      expect(
        userMessageFor(ApiErrorType.server),
        'Server error. Please try again later.',
      );
    });

    test('returns generic message for unknown errors', () {
      expect(
        userMessageFor(ApiErrorType.unknown),
        'Something went wrong. Please try again.',
      );
    });

    test('never returns raw exception text', () {
      for (final type in ApiErrorType.values) {
        final msg = userMessageFor(type);
        expect(msg.contains('ApiException'), isFalse);
        expect(msg.contains('SocketException'), isFalse);
        expect(msg.contains('Exception'), isFalse);
        expect(msg.contains('500'), isFalse);
        expect(msg.contains('401'), isFalse);
      }
    });
  });

  group('ApiErrorStateWidget', () {
    Widget buildTestWidget({
      String? userMessage,
      VoidCallback? onRetry,
      VoidCallback? onReLogin,
      bool showReLogin = false,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: ApiErrorStateWidget(
            userMessage: userMessage,
            onRetry: onRetry,
            onReLogin: onReLogin,
            showReLogin: showReLogin,
          ),
        ),
      );
    }

    testWidgets('renders error icon', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('renders user message when provided', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(userMessage: 'Unable to load payment settings.'),
      );

      expect(find.text('Unable to load payment settings.'), findsOneWidget);
    });

    testWidgets('renders fallback message when userMessage is null', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
    });

    testWidgets('renders retry button when onRetry is provided', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(onRetry: () {}));

      expect(find.text('Retry'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('does not render retry button when onRetry is null', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('retry button invokes onRetry callback', (tester) async {
      var retryCount = 0;
      await tester.pumpWidget(buildTestWidget(onRetry: () => retryCount++));

      await tester.tap(find.text('Retry'));
      expect(retryCount, 1);
    });

    testWidgets(
      'renders re-login button when showReLogin is true and onReLogin provided',
      (tester) async {
        await tester.pumpWidget(
          buildTestWidget(showReLogin: true, onReLogin: () {}),
        );

        expect(find.text('Re-login'), findsOneWidget);
        expect(find.byIcon(Icons.login), findsOneWidget);
      },
    );

    testWidgets('does not render re-login button when showReLogin is false', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(showReLogin: false, onReLogin: () {}),
      );

      expect(find.text('Re-login'), findsNothing);
    });

    testWidgets('does not render re-login button when onReLogin is null', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(showReLogin: true));

      expect(find.text('Re-login'), findsNothing);
    });

    testWidgets('re-login button invokes onReLogin callback', (tester) async {
      var loginCount = 0;
      await tester.pumpWidget(
        buildTestWidget(showReLogin: true, onReLogin: () => loginCount++),
      );

      await tester.tap(find.text('Re-login'));
      expect(loginCount, 1);
    });

    testWidgets('never shows raw exception text in the widget tree', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          userMessage: userMessageFor(
            classifyError(
              'ApiException(401): Unknown error [getGatewayConfigs]',
            ),
          ),
          onRetry: () {},
          showReLogin: true,
          onReLogin: () {},
        ),
      );

      // Ensure no raw exception details are visible
      expect(find.textContaining('ApiException'), findsNothing);
      expect(find.textContaining('getGatewayConfigs'), findsNothing);
      expect(find.textContaining('401'), findsNothing);
      // Ensure user-friendly message IS visible
      expect(
        find.text('Session expired. Please try again or re-login.'),
        findsOneWidget,
      );
    });

    testWidgets('renders both retry and re-login buttons together', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          userMessage: 'Session expired.',
          onRetry: () {},
          showReLogin: true,
          onReLogin: () {},
        ),
      );

      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Re-login'), findsOneWidget);
    });

    testWidgets('uses theme error color for icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: const ColorScheme.light(error: Colors.red),
          ),
          home: Scaffold(body: ApiErrorStateWidget(onRetry: () {})),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.error_outline));
      expect(icon.color, Colors.red);
    });
  });
}
