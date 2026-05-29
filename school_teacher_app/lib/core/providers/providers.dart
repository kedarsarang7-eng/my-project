import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';
import '../data/teacher_repository.dart';

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
final teacherRepoProvider = Provider<TeacherRepository>((ref) => TeacherRepository(ref.read(apiClientProvider)));

final dashboardProvider = FutureProvider<Map<String, dynamic>>((ref) => ref.read(teacherRepoProvider).getDashboard());
final timetableProvider = FutureProvider<List<dynamic>>((ref) => ref.read(teacherRepoProvider).getMyTimetable());
final batchesProvider = FutureProvider<List<dynamic>>((ref) => ref.read(teacherRepoProvider).getBatches());
final homeworkProvider = FutureProvider<List<dynamic>>((ref) => ref.read(teacherRepoProvider).getHomework());
final lessonPlansProvider = FutureProvider<List<dynamic>>((ref) => ref.read(teacherRepoProvider).getLessonPlans());
final materialsProvider = FutureProvider<List<dynamic>>((ref) => ref.read(teacherRepoProvider).getMaterials());
final myLeaveProvider = FutureProvider<List<dynamic>>((ref) => ref.read(teacherRepoProvider).getMyLeave());
final pendingLeavesProvider = FutureProvider<List<dynamic>>((ref) => ref.read(teacherRepoProvider).getPendingLeaves());
final payslipsProvider = FutureProvider<List<dynamic>>((ref) => ref.read(teacherRepoProvider).getMyPayslips());
final profileProvider = FutureProvider<Map<String, dynamic>>((ref) => ref.read(teacherRepoProvider).getMyProfile());

// Selected batch state for attendance marking
final selectedBatchProvider = StateProvider<String?>((ref) => null);
