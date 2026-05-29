import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';
import '../data/admin_repository.dart';

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
final adminRepoProvider = Provider<AdminRepository>((ref) => AdminRepository(ref.read(apiClientProvider)));

final dashboardProvider = FutureProvider<Map<String, dynamic>>((ref) => ref.read(adminRepoProvider).getDashboard());
final batchesProvider = FutureProvider<List<dynamic>>((ref) => ref.read(adminRepoProvider).getBatches());
final feeOverviewProvider = FutureProvider<Map<String, dynamic>>((ref) => ref.read(adminRepoProvider).getFeeOverview());
final pendingLeavesProvider = FutureProvider<List<dynamic>>((ref) => ref.read(adminRepoProvider).getAllPendingLeaves());
final admissionsProvider = FutureProvider<Map<String, dynamic>>((ref) => ref.read(adminRepoProvider).getAdmissions(status: 'pending'));
final transportProvider = FutureProvider<Map<String, dynamic>>((ref) => ref.read(adminRepoProvider).getTransportOverview());
final libraryProvider = FutureProvider<Map<String, dynamic>>((ref) => ref.read(adminRepoProvider).getLibraryStats());
final hostelProvider = FutureProvider<Map<String, dynamic>>((ref) => ref.read(adminRepoProvider).getHostelInfo());
final payrollProvider = FutureProvider<Map<String, dynamic>>((ref) => ref.read(adminRepoProvider).getPayrollSummary());
final institutionConfigProvider = FutureProvider<Map<String, dynamic>>((ref) => ref.read(adminRepoProvider).getInstitutionConfig());
final analyticsProvider = FutureProvider<Map<String, dynamic>>((ref) => ref.read(adminRepoProvider).getAnalytics());
final studentsProvider = FutureProvider<Map<String, dynamic>>((ref) => ref.read(adminRepoProvider).getStudents());
final facultyProvider = FutureProvider<Map<String, dynamic>>((ref) => ref.read(adminRepoProvider).getFaculty());
