import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_service.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/shell/main_shell.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/attendance/screens/attendance_screen.dart';
import '../../features/timetable/screens/timetable_screen.dart';
import '../../features/students/screens/students_screen.dart';
import '../../features/homework/screens/homework_screen.dart';
import '../../features/lesson_plans/screens/lesson_plans_screen.dart';
import '../../features/exams/screens/exams_screen.dart';
import '../../features/materials/screens/materials_screen.dart';
import '../../features/leave/screens/leave_screen.dart';
import '../../features/announcements/screens/announcements_screen.dart';
import '../../features/payslip/screens/payslip_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
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
          GoRoute(path: '/attendance', builder: (_, __) => const AttendanceScreen()),
          GoRoute(path: '/timetable', builder: (_, __) => const TimetableScreen()),
          GoRoute(path: '/students', builder: (_, __) => const StudentsScreen()),
          GoRoute(path: '/homework', builder: (_, __) => const HomeworkScreen()),
          GoRoute(path: '/lesson-plans', builder: (_, __) => const LessonPlansScreen()),
          GoRoute(path: '/exams', builder: (_, __) => const ExamsScreen()),
          GoRoute(path: '/materials', builder: (_, __) => const MaterialsScreen()),
          GoRoute(path: '/leave', builder: (_, __) => const LeaveScreen()),
          GoRoute(path: '/announcements', builder: (_, __) => const AnnouncementsScreen()),
          GoRoute(path: '/payslip', builder: (_, __) => const PayslipScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        ],
      ),
    ],
  );
});
