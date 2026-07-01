/// Global Keyboard Handler - Tally-Style Keyboard Architecture
///
/// This is the central keyboard event processor that provides:
/// - Function Keys F1-F12 (Tally standard)
/// - Global navigation (ESC, ENTER, TAB)
/// - Role-based shortcut enforcement
/// - Shortcut hint injection
///
/// Usage: Wrap your root widget with GlobalKeyboardHandler
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../di/service_locator.dart';
import '../../services/auth_service.dart';
import '../../services/role_management_service.dart';

// ============================================================================
// KEYBOARD INTENT DEFINITIONS
// ============================================================================

/// Intent for Function Key actions
class FunctionKeyIntent extends Intent {
  final int functionKeyNumber; // 1-12
  const FunctionKeyIntent(this.functionKeyNumber);
}

/// Intent for global navigation
class NavigationIntent extends Intent {
  final NavigationType type;
  const NavigationIntent(this.type);
}

enum NavigationType {
  escape, // ESC - Back/Cancel/Close
  confirm, // ENTER - Accept/Submit
  nextField, // TAB - Next field
  prevField, // SHIFT+TAB - Previous field
  up, // Arrow Up
  down, // Arrow Down
  left, // Arrow Left
  right, // Arrow Right
}

/// Intent for common shortcuts
class CommonShortcutIntent extends Intent {
  final CommonShortcut shortcut;
  const CommonShortcutIntent(this.shortcut);
}

enum CommonShortcut {
  newRecord, // Ctrl+N
  save, // Ctrl+S
  delete, // Ctrl+D
  print, // Ctrl+P
  search, // Ctrl+F
  edit, // Ctrl+E
  ledger, // Ctrl+L
  backup, // Ctrl+B
  quit, // Ctrl+Q
  addItem, // Ctrl+A (in billing context)
  focusMenu, // Alt+M
}

// ============================================================================
// KEYBOARD STATE PROVIDER
// ============================================================================

/// Tracks global keyboard state for the application
class KeyboardState {
  final bool isHelpOverlayVisible;
  final String? activeScreen;
  final String? focusedFieldId;

  const KeyboardState({
    this.isHelpOverlayVisible = false,
    this.activeScreen,
    this.focusedFieldId,
  });

  KeyboardState copyWith({
    bool? isHelpOverlayVisible,
    String? activeScreen,
    String? focusedFieldId,
  }) {
    return KeyboardState(
      isHelpOverlayVisible: isHelpOverlayVisible ?? this.isHelpOverlayVisible,
      activeScreen: activeScreen ?? this.activeScreen,
      focusedFieldId: focusedFieldId ?? this.focusedFieldId,
    );
  }
}

class KeyboardStateNotifier extends Notifier<KeyboardState> {
  @override
  KeyboardState build() => const KeyboardState();

  void showHelpOverlay() {
    state = state.copyWith(isHelpOverlayVisible: true);
  }

  void hideHelpOverlay() {
    state = state.copyWith(isHelpOverlayVisible: false);
  }

  void toggleHelpOverlay() {
    state = state.copyWith(isHelpOverlayVisible: !state.isHelpOverlayVisible);
  }

  void setActiveScreen(String screenId) {
    state = state.copyWith(activeScreen: screenId);
  }

  void setFocusedField(String? fieldId) {
    state = state.copyWith(focusedFieldId: fieldId);
  }
}

final keyboardStateProvider =
    NotifierProvider<KeyboardStateNotifier, KeyboardState>(
      () => KeyboardStateNotifier(),
    );

// ============================================================================
// GLOBAL SHORTCUTS MAP
// ============================================================================

/// Builds the global shortcuts map for the entire application
Map<ShortcutActivator, Intent> buildGlobalShortcuts() {
  return {
    // ========== FUNCTION KEYS (F1-F12) ==========
    const SingleActivator(LogicalKeyboardKey.f1): const FunctionKeyIntent(1),
    const SingleActivator(LogicalKeyboardKey.f2): const FunctionKeyIntent(2),
    const SingleActivator(LogicalKeyboardKey.f3): const FunctionKeyIntent(3),
    const SingleActivator(LogicalKeyboardKey.f4): const FunctionKeyIntent(4),
    const SingleActivator(LogicalKeyboardKey.f5): const FunctionKeyIntent(5),
    const SingleActivator(LogicalKeyboardKey.f6): const FunctionKeyIntent(6),
    const SingleActivator(LogicalKeyboardKey.f7): const FunctionKeyIntent(7),
    const SingleActivator(LogicalKeyboardKey.f8): const FunctionKeyIntent(8),
    const SingleActivator(LogicalKeyboardKey.f9): const FunctionKeyIntent(9),
    const SingleActivator(LogicalKeyboardKey.f10): const FunctionKeyIntent(10),
    const SingleActivator(LogicalKeyboardKey.f11): const FunctionKeyIntent(11),
    const SingleActivator(LogicalKeyboardKey.f12): const FunctionKeyIntent(12),

    // ========== NAVIGATION KEYS ==========
    const SingleActivator(LogicalKeyboardKey.escape): const NavigationIntent(
      NavigationType.escape,
    ),

    // ========== COMMON SHORTCUTS (CTRL+KEY) ==========
    const SingleActivator(LogicalKeyboardKey.keyN, control: true):
        const CommonShortcutIntent(CommonShortcut.newRecord),
    const SingleActivator(LogicalKeyboardKey.keyS, control: true):
        const CommonShortcutIntent(CommonShortcut.save),
    const SingleActivator(LogicalKeyboardKey.keyD, control: true):
        const CommonShortcutIntent(CommonShortcut.delete),
    const SingleActivator(LogicalKeyboardKey.keyP, control: true):
        const CommonShortcutIntent(CommonShortcut.print),
    const SingleActivator(LogicalKeyboardKey.keyF, control: true):
        const CommonShortcutIntent(CommonShortcut.search),
    const SingleActivator(LogicalKeyboardKey.keyE, control: true):
        const CommonShortcutIntent(CommonShortcut.edit),
    const SingleActivator(LogicalKeyboardKey.keyL, control: true):
        const CommonShortcutIntent(CommonShortcut.ledger),
    const SingleActivator(LogicalKeyboardKey.keyB, control: true):
        const CommonShortcutIntent(CommonShortcut.backup),
    const SingleActivator(LogicalKeyboardKey.keyQ, control: true):
        const CommonShortcutIntent(CommonShortcut.quit),
    const SingleActivator(LogicalKeyboardKey.keyA, control: true):
        const CommonShortcutIntent(CommonShortcut.addItem),

    // ========== MENU ACCESS ==========
    const SingleActivator(LogicalKeyboardKey.keyM, alt: true):
        const CommonShortcutIntent(CommonShortcut.focusMenu),
  };
}

// ============================================================================
// GLOBAL KEYBOARD HANDLER WIDGET
// ============================================================================

/// The root keyboard handler that wraps the entire application
/// This provides Tally-style keyboard shortcuts globally
class GlobalKeyboardHandler extends ConsumerStatefulWidget {
  final Widget child;
  final VoidCallback? onHelpRequested;
  final VoidCallback? onQuitRequested;

  const GlobalKeyboardHandler({
    super.key,
    required this.child,
    this.onHelpRequested,
    this.onQuitRequested,
  });

  @override
  ConsumerState<GlobalKeyboardHandler> createState() =>
      _GlobalKeyboardHandlerState();
}

class _GlobalKeyboardHandlerState extends ConsumerState<GlobalKeyboardHandler> {
  @override
  Widget build(BuildContext context) {
    final userRoleAsync = ref.watch(currentUserRoleProvider);
    // Default to 'unknown' (safe mode) while loading or on error
    final userRole = userRoleAsync.value ?? UserRole.unknown;

    return Shortcuts(
      shortcuts: buildGlobalShortcuts(),
      child: Actions(
        actions: {
          FunctionKeyIntent: CallbackAction<FunctionKeyIntent>(
            onInvoke: (intent) =>
                _handleFunctionKey(context, intent.functionKeyNumber, userRole),
          ),
          NavigationIntent: CallbackAction<NavigationIntent>(
            onInvoke: (intent) => _handleNavigation(context, intent.type),
          ),
          CommonShortcutIntent: CallbackAction<CommonShortcutIntent>(
            onInvoke: (intent) =>
                _handleCommonShortcut(context, intent.shortcut, userRole),
          ),
        },
        child: Focus(autofocus: true, child: widget.child),
      ),
    );
  }

  /// Handle Function Keys F1-F12
  Object? _handleFunctionKey(
    BuildContext context,
    int keyNumber,
    UserRole role,
  ) {
    switch (keyNumber) {
      case 1: // F1 → Help / Keyboard Shortcut Overlay
        ref.read(keyboardStateProvider.notifier).toggleHelpOverlay();
        widget.onHelpRequested?.call();
        break;

      case 2: // F2 → Edit selected record
        _navigateIfPermitted(
          context,
          role,
          Permission.editBill,
          '/edit_selected',
        );
        break;

      case 3: // F3 → Change Company / Business
        _navigateIfPermitted(
          context,
          role,
          Permission.manageSettings,
          '/change_business',
        );
        break;

      case 4: // F4 → Inventory / Stock
        _navigateIfPermitted(context, role, Permission.viewStock, '/inventory');
        break;

      case 5: // F5 → Payments
        _navigateIfPermitted(
          context,
          role,
          Permission.receivePayment,
          '/payment-history',
        );
        break;

      case 6: // F6 → Receipts
        _navigateIfPermitted(
          context,
          role,
          Permission.viewReports,
          '/receipts',
        );
        break;

      case 7: // F7 → Journal
        _navigateIfPermitted(
          context,
          role,
          Permission.viewCashBook,
          '/daybook',
        );
        break;

      case 8: // F8 → Sales (Invoice) - PRIMARY BILLING KEY
        _navigateIfPermitted(
          context,
          role,
          Permission.createBill,
          '/billing_flow',
        );
        break;

      case 9: // F9 → Purchase
        _navigateIfPermitted(
          context,
          role,
          Permission.createPurchase,
          '/purchase',
        );
        break;

      case 10: // F10 → Reports
        _navigateIfPermitted(context, role, Permission.viewReports, '/reports');
        break;

      case 11: // F11 → Settings
        _navigateIfPermitted(
          context,
          role,
          Permission.manageSettings,
          '/settings',
        );
        break;

      case 12: // F12 → Configuration
        _navigateIfPermitted(
          context,
          role,
          Permission.manageSettings,
          '/configuration',
        );
        break;
    }
    return null;
  }

  /// Handle Navigation Keys (ESC, etc.)
  Object? _handleNavigation(BuildContext context, NavigationType type) {
    switch (type) {
      case NavigationType.escape:
        // ESC → Back / Cancel / Close dialog
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        break;
      default:
        // Other navigation handled by widgets themselves
        break;
    }
    return null;
  }

  /// Handle Common Shortcuts (Ctrl+Key)
  Object? _handleCommonShortcut(
    BuildContext context,
    CommonShortcut shortcut,
    UserRole role,
  ) {
    switch (shortcut) {
      case CommonShortcut.newRecord:
        _navigateIfPermitted(
          context,
          role,
          Permission.createBill,
          '/billing_flow',
        );
        break;

      case CommonShortcut.save:
        // Broadcast save intent - individual screens handle this
        _broadcastIntent('SAVE');
        break;

      case CommonShortcut.delete:
        if (RolePermissions.hasPermission(role, Permission.deleteBill)) {
          _broadcastIntent('DELETE');
        } else {
          _showPermissionDenied(context);
        }
        break;

      case CommonShortcut.print:
        _broadcastIntent('PRINT');
        break;

      case CommonShortcut.search:
        _broadcastIntent('SEARCH');
        break;

      case CommonShortcut.edit:
        if (RolePermissions.hasPermission(role, Permission.editBill)) {
          _broadcastIntent('EDIT');
        } else {
          _showPermissionDenied(context);
        }
        break;

      case CommonShortcut.ledger:
        _navigateIfPermitted(
          context,
          role,
          Permission.viewLedger,
          '/party_ledger',
        );
        break;

      case CommonShortcut.backup:
        _navigateIfPermitted(
          context,
          role,
          Permission.manageSettings,
          '/backup',
        );
        break;

      case CommonShortcut.quit:
        widget.onQuitRequested?.call();
        break;

      case CommonShortcut.addItem:
        _broadcastIntent('ADD_ITEM');
        break;

      case CommonShortcut.focusMenu:
        _broadcastIntent('FOCUS_MENU');
        break;
    }
    return null;
  }

  /// Navigate only if user has permission
  void _navigateIfPermitted(
    BuildContext context,
    UserRole role,
    Permission permission,
    String route,
  ) {
    if (RolePermissions.hasPermission(role, permission)) {
      // Migrated to GoRouter; permission-gating preserved. Unknown route strings
      // degrade gracefully to the not-found screen via AppRouter.errorBuilder.
      context.push(route);
    } else {
      _showPermissionDenied(context);
    }
  }

  /// Show permission denied message
  void _showPermissionDenied(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Permission required'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Broadcast intent to active screen (screens listen via Provider)
  void _broadcastIntent(String intent) {
    ref.read(keyboardIntentProvider.notifier).broadcast(intent);
  }
}

// ============================================================================
// KEYBOARD INTENT BROADCASTER
// ============================================================================

/// Broadcasts keyboard intents so screens can react
class KeyboardIntentState {
  final String? lastIntent;
  final int timestamp;

  const KeyboardIntentState({this.lastIntent, this.timestamp = 0});
}

class KeyboardIntentNotifier extends Notifier<KeyboardIntentState> {
  @override
  KeyboardIntentState build() => const KeyboardIntentState();

  void broadcast(String intent) {
    state = KeyboardIntentState(
      lastIntent: intent,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  void clear() {
    state = const KeyboardIntentState();
  }
}

final keyboardIntentProvider =
    NotifierProvider<KeyboardIntentNotifier, KeyboardIntentState>(
      () => KeyboardIntentNotifier(),
    );

// ============================================================================
// USER ROLE PROVIDER (for keyboard permission checks)
// ============================================================================

/// Provider that returns current user's role
/// Async Notifier that returns current user's role from session
final currentUserRoleProvider =
    AsyncNotifierProvider<UserRoleNotifier, UserRole>(() => UserRoleNotifier());

class UserRoleNotifier extends AsyncNotifier<UserRole> {
  @override
  Future<UserRole> build() async {
    final session = await sl<AuthService>().getSavedSession();
    if (session != null && session['role'] != null) {
      final roleStr = session['role']!;
      return UserRole.values.firstWhere(
        (e) => e.name == roleStr,
        orElse: () => UserRole.unknown,
      );
    }
    return UserRole.unknown;
  }
}

// ============================================================================
// SHORTCUT HINT HELPERS
// ============================================================================

/// Format shortcut for display in UI
String formatShortcut(String binding) {
  return binding
      .replaceAll('Ctrl+', '⌃')
      .replaceAll('Alt+', '⌥')
      .replaceAll('Shift+', '⇧');
}

/// Get all active shortcuts for display
List<ShortcutInfo> getAllShortcuts() {
  return [
    // Function Keys
    const ShortcutInfo('F1', 'Help / Keyboard Shortcuts', 'System'),
    const ShortcutInfo('F2', 'Edit Selected Record', 'System'),
    const ShortcutInfo('F3', 'Change Company / Business', 'System'),
    const ShortcutInfo('F4', 'Inventory / Stock', 'Navigation'),
    const ShortcutInfo('F5', 'Payments', 'Navigation'),
    const ShortcutInfo('F6', 'Receipts', 'Navigation'),
    const ShortcutInfo('F7', 'Journal / Day Book', 'Navigation'),
    const ShortcutInfo('F8', 'Sales Invoice', 'Billing'),
    const ShortcutInfo('F9', 'Purchase', 'Navigation'),
    const ShortcutInfo('F10', 'Reports', 'Navigation'),
    const ShortcutInfo('F11', 'Settings', 'System'),
    const ShortcutInfo('F12', 'Configuration', 'System'),

    // Common Shortcuts
    const ShortcutInfo('Ctrl+N', 'New Record', 'Common'),
    const ShortcutInfo('Ctrl+S', 'Save', 'Common'),
    const ShortcutInfo('Ctrl+D', 'Delete', 'Common'),
    const ShortcutInfo('Ctrl+P', 'Print', 'Common'),
    const ShortcutInfo('Ctrl+F', 'Search', 'Common'),
    const ShortcutInfo('Ctrl+E', 'Edit', 'Common'),
    const ShortcutInfo('Ctrl+L', 'Ledger', 'Common'),
    const ShortcutInfo('Ctrl+B', 'Backup', 'System'),
    const ShortcutInfo('Ctrl+Q', 'Quit App', 'System'),
    const ShortcutInfo('Ctrl+A', 'Add Item (in billing)', 'Billing'),

    // Navigation
    const ShortcutInfo('ESC', 'Back / Cancel / Close', 'Navigation'),
    const ShortcutInfo('ENTER', 'Accept / Next Field', 'Navigation'),
    const ShortcutInfo('TAB', 'Next Field', 'Navigation'),
    const ShortcutInfo('Shift+TAB', 'Previous Field', 'Navigation'),
    const ShortcutInfo('↑↓', 'Navigate Lists/Tables', 'Navigation'),
    const ShortcutInfo('←→', 'Switch Tabs/Columns', 'Navigation'),
    const ShortcutInfo('Alt+M', 'Focus Menu', 'Navigation'),
  ];
}

class ShortcutInfo {
  final String key;
  final String description;
  final String category;

  const ShortcutInfo(this.key, this.description, this.category);
}
