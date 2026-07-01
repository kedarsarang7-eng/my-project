import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dukanx/providers/app_state_providers.dart';
import '../../data/shortcuts_repository.dart';
import '../../domain/services/shortcut_service.dart';
import '../../domain/services/shortcut_data_provider.dart';
import '../../domain/services/keyboard_shortcut_manager.dart';
import '../../domain/models/user_shortcut_config.dart';
import '../../../../services/role_management_service.dart';

// Repositories & Services
final shortcutsRepositoryProvider = Provider((ref) => ShortcutsRepository());
final shortcutServiceProvider = Provider(
  (ref) => ShortcutService(repository: ref.watch(shortcutsRepositoryProvider)),
);
final shortcutDataProviderProvider = Provider((ref) => ShortcutDataProvider());
final keyboardShortcutManagerProvider = Provider(
  (ref) => KeyboardShortcutManager(),
);

// User's configured shortcuts stream
final userShortcutsStreamProvider = StreamProvider<List<UserShortcutConfig>>((
  ref,
) {
  final userId = ref.watch(currentUserProvider);
  if (userId == null) return const Stream.empty();

  final repo = ref.watch(shortcutsRepositoryProvider);
  return repo.watchUserShortcuts(userId);
});

// Final filtered shortcuts visible to the user
final visibleShortcutsProvider = Provider<AsyncValue<List<UserShortcutConfig>>>((
  ref,
) {
  final shortcutsAsync = ref.watch(userShortcutsStreamProvider);
  final service = ref.watch(shortcutServiceProvider);
  final businessTypeVal = ref.watch(businessTypeProvider);
  final currentUserState = ref.watch(currentUserProvider); // This returns String? (userId)

  return shortcutsAsync.whenData((shortcuts) {
    if (currentUserState == null) return [];

    // Use async data if available, but for stream provider inside provider we need a different approach
    // or just assume we fetch it.
    // Automatically use owner for dev/prototype
    var userRole = UserRole.owner;

    return service.filterShortcuts(shortcuts, userRole, businessTypeVal.type);
  });
});

// Real-time badge data
final shortcutBadgeDataProvider =
    StreamProvider<Map<String, ShortcutBadgeData>>((ref) {
      final userId = ref.watch(currentUserProvider);
      if (userId == null) return const Stream.empty();

      final dataProvider = ref.watch(shortcutDataProviderProvider);
      return dataProvider.watchBadgeData(userId);
    });

// Initialize shortcuts on app start
final shortcutInitializerProvider = FutureProvider<void>((ref) async {
  final userId = ref.watch(currentUserProvider);
  if (userId == null) return;

  final service = ref.watch(shortcutServiceProvider);
  await service.initializeSystem(userId);
});
