import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_service.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/shell/main_shell.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/students/screens/students_screen.dart';
import '../../features/faculty/screens/faculty_screen.dart';
import '../../features/classes/screens/classes_screen.dart';
import '../../features/admissions/screens/admissions_screen.dart';
import '../../features/fees/screens/fees_screen.dart';
import '../../features/attendance/screens/attendance_screen.dart';
import '../../features/leave/screens/leave_screen.dart';
import '../../features/transport/screens/transport_screen.dart';
import '../../features/library/screens/library_screen.dart';
import '../../features/hostel/screens/hostel_screen.dart';
import '../../features/payroll/screens/payroll_screen.dart';
import '../../features/reports/screens/reports_screen.dart';
import '../../features/announcements/screens/announcements_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../widgets/ws_notification_listener.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  return GoRouter(
    initialLocation: '/dashboard',
    redirect: (context, state) {
      if (authState.isLoading) return null;
      final isAuth = authState.isAuthenticated;
      final isLogin = state.matchedLocation == '/login';
      if (!isAuth && !isLogin) return '/login';
      if (isAuth && isLogin) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) => WsNotificationListener(child: MainShell(child: child)),
        routes: [
          GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
          GoRoute(path: '/students', builder: (_, __) => const StudentsScreen()),
          GoRoute(path: '/faculty', builder: (_, __) => const FacultyScreen()),
          GoRoute(path: '/classes', builder: (_, __) => const ClassesScreen()),
          GoRoute(path: '/admissions', builder: (_, __) => const AdmissionsScreen()),
          GoRoute(path: '/fees', builder: (_, __) => const FeesScreen()),
          GoRoute(path: '/attendance', builder: (_, __) => const AttendanceScreen()),
          GoRoute(path: '/leave', builder: (_, __) => const LeaveScreen()),
          GoRoute(path: '/transport', builder: (_, __) => const TransportScreen()),
          GoRoute(path: '/library', builder: (_, __) => const LibraryScreen()),
          GoRoute(path: '/hostel', builder: (_, __) => const HostelScreen()),
          GoRoute(path: '/payroll', builder: (_, __) => const PayrollScreen()),
          GoRoute(path: '/reports', builder: (_, __) => const ReportsScreen()),
          GoRoute(path: '/announcements', builder: (_, __) => const AnnouncementsScreen()),
          GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
        ],
      ),
    ],
  );
});
