import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_service.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/shell/main_shell.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/timetable/screens/timetable_screen.dart';
import '../../features/attendance/screens/attendance_screen.dart';
import '../../features/exams/screens/exams_screen.dart';
import '../../features/fees/screens/fees_screen.dart';
import '../../features/materials/screens/materials_screen.dart';
import '../../features/homework/screens/homework_screen.dart';
import '../../features/leave/screens/leave_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/library/screens/library_screen.dart';
import '../../features/transport/screens/transport_screen.dart';
import '../../features/results/screens/results_screen.dart';
import '../../features/fees/screens/fee_payment_screen.dart';
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
          GoRoute(path: '/timetable', builder: (_, __) => const TimetableScreen()),
          GoRoute(path: '/attendance', builder: (_, __) => const AttendanceScreen()),
          GoRoute(path: '/exams', builder: (_, __) => const ExamsScreen()),
          GoRoute(path: '/fees', builder: (_, __) => const FeesScreen()),
          GoRoute(path: '/materials', builder: (_, __) => const MaterialsScreen()),
          GoRoute(path: '/homework', builder: (_, __) => const HomeworkScreen()),
          GoRoute(path: '/leave', builder: (_, __) => const LeaveScreen()),
          GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
          GoRoute(path: '/library', builder: (_, __) => const LibraryScreen()),
          GoRoute(path: '/transport', builder: (_, __) => const TransportScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
          GoRoute(path: '/results', builder: (_, __) => const ResultsScreen()),
          GoRoute(path: '/fee-payment', builder: (_, __) => const FeePaymentScreen()),
        ],
      ),
    ],
  );
});
