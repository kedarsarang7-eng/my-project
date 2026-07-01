import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dukanx/features/staff/presentation/screens/staff_management_screen.dart';
import 'package:dukanx/features/staff/presentation/providers/staff_management_provider.dart';
import 'package:dukanx/features/staff/presentation/widgets/create_staff_dialog.dart';
import 'package:dukanx/features/staff/data/models/staff_profile_model.dart';

class MockStaffManagementNotifier extends StaffManagementNotifier {
  MockStaffManagementNotifier([StaffManagementState? initialState]) {
    if (initialState != null) {
      state = initialState;
    }
  }

  @override
  Future<void> loadStaff({bool refresh = false}) async {
    // No-op to prevent real API calls in tests
  }

  @override
  Future<void> loadStats() async {
    // No-op
  }
}

void main() {
  Future<void> setLargeViewport(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1920, 1080));
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
  }

  Future<void> resetViewport(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(null);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }

  group('StaffManagementScreen Widget Tests', () {
    
    testWidgets('shows loading indicator when loading', (tester) async {
      await setLargeViewport(tester);
      // Arrange
      final container = ProviderContainer(
        overrides: [
          staffManagementProvider.overrideWith((ref) => MockStaffManagementNotifier(
            const StaffManagementState(isLoading: true),
          )),
        ],
      );

      // Act
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: StaffManagementScreen(),
          ),
        ),
      );

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Staff Members'), findsOneWidget);
      await resetViewport(tester);
    });

    testWidgets('shows empty state when no staff', (tester) async {
      await setLargeViewport(tester);
      // Arrange
      final container = ProviderContainer(
        overrides: [
          staffManagementProvider.overrideWith((ref) => MockStaffManagementNotifier(
            const StaffManagementState(
              isLoading: false,
              staff: [],
              filteredStaff: [],
            ),
          )),
        ],
      );

      // Act
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: StaffManagementScreen(),
          ),
        ),
      );

      // Assert
      expect(find.text('No staff members found'), findsOneWidget);
      expect(find.text('Add your first staff member to get started'), findsOneWidget);
      await resetViewport(tester);
    });

    testWidgets('shows error state with retry button', (tester) async {
      await setLargeViewport(tester);
      // Arrange
      final container = ProviderContainer(
        overrides: [
          staffManagementProvider.overrideWith((ref) => MockStaffManagementNotifier(
            const StaffManagementState(
              isLoading: false,
              error: 'Network error: Failed to load staff',
            ),
          )),
        ],
      );

      // Act
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: StaffManagementScreen(),
          ),
        ),
      );

      // Assert
      expect(find.text('Unable to Load Staff'), findsOneWidget);
      expect(find.text('Network error: Failed to load staff'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Try Again'), findsOneWidget);
      await resetViewport(tester);
    });

    testWidgets('displays staff list correctly', (tester) async {
      await setLargeViewport(tester);
      // Arrange
      final mockStaff = <StaffListItemModel>[
        StaffListItemModel(
          staffId: 'staff-1',
          fullName: 'John Doe',
          phoneNumber: '9876543210',
          email: 'john@example.com',
          role: StaffRole.manager,
          isActive: true,
          joiningDate: '2024-01-01',
        ),
        StaffListItemModel(
          staffId: 'staff-2',
          fullName: 'Jane Smith',
          phoneNumber: '9876543211',
          email: 'jane@example.com',
          role: StaffRole.cashier,
          isActive: true,
          joiningDate: '2024-02-01',
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          staffManagementProvider.overrideWith((ref) => MockStaffManagementNotifier(
            StaffManagementState(
              isLoading: false,
              staff: mockStaff,
              filteredStaff: mockStaff,
            ),
          )),
        ],
      );

      // Act
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: StaffManagementScreen(),
          ),
        ),
      );

      // Assert
      expect(find.text('John Doe'), findsOneWidget);
      expect(find.text('Jane Smith'), findsOneWidget);
      expect(find.text('Showing 2 of 2 staff members'), findsOneWidget);
      await resetViewport(tester);
    });

    testWidgets('tapping create button opens dialog', (tester) async {
      await setLargeViewport(tester);
      // Arrange
      final container = ProviderContainer(
        overrides: [
          staffManagementProvider.overrideWith((ref) => MockStaffManagementNotifier(
            const StaffManagementState(
              isLoading: false,
              staff: [],
              filteredStaff: [],
            ),
          )),
        ],
      );

      // Act
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: StaffManagementScreen(),
          ),
        ),
      );

      // Tap create button
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create New Staff Account'));
      await tester.pump(const Duration(milliseconds: 500));

      // Assert - Dialog should open
      expect(find.byType(CreateStaffDialog), findsOneWidget);
      await resetViewport(tester);
    });

    testWidgets('search filters staff list', (tester) async {
      await setLargeViewport(tester);
      // Arrange
      final mockStaff = <StaffListItemModel>[
        StaffListItemModel(
          staffId: 'staff-1',
          fullName: 'John Doe',
          phoneNumber: '9876543210',
          role: StaffRole.manager,
          isActive: true,
          joiningDate: '2024-01-01',
        ),
        StaffListItemModel(
          staffId: 'staff-2',
          fullName: 'Jane Smith',
          phoneNumber: '9876543211',
          role: StaffRole.cashier,
          isActive: true,
          joiningDate: '2024-02-01',
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          staffManagementProvider.overrideWith((ref) => MockStaffManagementNotifier(
            StaffManagementState(
              isLoading: false,
              staff: mockStaff,
              filteredStaff: mockStaff,
            ),
          )),
        ],
      );

      // Act
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: StaffManagementScreen(),
          ),
        ),
      );

      // Enter search text
      await tester.enterText(find.widgetWithText(TextField, 'Search'), 'John');
      await tester.pump();

      // Assert - Should filter to show only John
      expect(find.text('John Doe'), findsOneWidget);
      await resetViewport(tester);
    });

    testWidgets('shows correct pagination', (tester) async {
      await setLargeViewport(tester);
      // Arrange - Create 25 staff to trigger pagination
      final mockStaff = List.generate(25, (i) => StaffListItemModel(
        staffId: 'staff-$i',
        fullName: 'Staff Member $i',
        phoneNumber: '98765432${i.toString().padLeft(2, '0')}',
        role: StaffRole.cashier,
        isActive: true,
        joiningDate: '2024-01-01',
      ));

      final container = ProviderContainer(
        overrides: [
          staffManagementProvider.overrideWith((ref) => MockStaffManagementNotifier(
            StaffManagementState(
              isLoading: false,
              staff: mockStaff,
              filteredStaff: mockStaff,
              currentPage: 1,
            ),
          )),
        ],
      );

      // Act
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: StaffManagementScreen(),
          ),
        ),
      );

      // Assert
      expect(find.text('Showing 1-10 of 25 staff members'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.widgetWithIcon(IconButton, Icons.chevron_left), findsOneWidget);
      expect(find.widgetWithIcon(IconButton, Icons.chevron_right), findsOneWidget);
      await resetViewport(tester);
    });
  });
}
