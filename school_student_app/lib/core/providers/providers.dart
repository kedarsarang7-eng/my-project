import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';
import '../data/school_repository.dart';

final sharedPrefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError());

final themeModeProvider = StateNotifierProvider<_ThemeNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return _ThemeNotifier(prefs);
});

class _ThemeNotifier extends StateNotifier<bool> {
  final SharedPreferences _prefs;
  _ThemeNotifier(this._prefs) : super(_prefs.getBool('dark_mode') ?? false);
  void toggle() { state = !state; _prefs.setBool('dark_mode', state); }
  void set(bool dark) { state = dark; _prefs.setBool('dark_mode', dark); }
}

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
final schoolRepoProvider = Provider<SchoolRepository>((ref) => SchoolRepository(ref.read(apiClientProvider)));

// ── Dashboard ─────────────────────────────────────────────────────────────
final dashboardProvider = FutureProvider<Map<String, dynamic>>((ref) =>
    ref.read(schoolRepoProvider).getDashboard());

// ── Timetable ─────────────────────────────────────────────────────────────
final timetableProvider = FutureProvider<List<dynamic>>((ref) =>
    ref.read(schoolRepoProvider).getTimetable());

// ── Attendance ────────────────────────────────────────────────────────────
final attendanceProvider = FutureProvider<Map<String, dynamic>>((ref) =>
    ref.read(schoolRepoProvider).getMyAttendance());

// ── Exams ─────────────────────────────────────────────────────────────────
final examsProvider = FutureProvider<List<dynamic>>((ref) =>
    ref.read(schoolRepoProvider).getMyExams());

// ── Fees ──────────────────────────────────────────────────────────────────
final feesProvider = FutureProvider<Map<String, dynamic>>((ref) =>
    ref.read(schoolRepoProvider).getMyFees());

// ── Materials ─────────────────────────────────────────────────────────────
final materialsProvider = FutureProvider<List<dynamic>>((ref) =>
    ref.read(schoolRepoProvider).getMaterials());

// ── Homework ──────────────────────────────────────────────────────────────
final homeworkProvider = FutureProvider<List<dynamic>>((ref) =>
    ref.read(schoolRepoProvider).getMyHomework());

// ── Leave ─────────────────────────────────────────────────────────────────
final leaveProvider = FutureProvider<List<dynamic>>((ref) =>
    ref.read(schoolRepoProvider).getMyLeave());

final leaveBalanceProvider = FutureProvider<Map<String, dynamic>>((ref) =>
    ref.read(schoolRepoProvider).getLeaveBalance());

// ── Notifications ─────────────────────────────────────────────────────────
final notificationsProvider = FutureProvider<List<dynamic>>((ref) =>
    ref.read(schoolRepoProvider).getNotifications());

// ── Profile ───────────────────────────────────────────────────────────────
final profileProvider = FutureProvider<Map<String, dynamic>>((ref) =>
    ref.read(schoolRepoProvider).getMyProfile());
