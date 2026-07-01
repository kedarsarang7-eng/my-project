import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dukanx/features/avatar/domain/models/avatar_data.dart';
import 'package:dukanx/features/avatar/data/repository/avatar_repository.dart';
import 'package:dukanx/core/di/service_locator.dart';
import 'package:dukanx/core/database/app_database.dart';
import 'package:dukanx/core/compat/firebase_auth_compat.dart';

// Defines the state of the editor including undo/redo history
class AvatarEditorState {
  final AvatarData currentData;
  final List<AvatarData> history;
  final int historyIndex;
  final bool isSaving;
  final bool isLoading;
  final String? error;

  const AvatarEditorState({
    required this.currentData,
    this.history = const [],
    this.historyIndex = 0,
    this.isSaving = false,
    this.isLoading = false,
    this.error,
  });

  AvatarEditorState copyWith({
    AvatarData? currentData,
    List<AvatarData>? history,
    int? historyIndex,
    bool? isSaving,
    bool? isLoading,
    String? error,
  }) {
    return AvatarEditorState(
      currentData: currentData ?? this.currentData,
      history: history ?? this.history,
      historyIndex: historyIndex ?? this.historyIndex,
      isSaving: isSaving ?? this.isSaving,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// Initial state factory
  factory AvatarEditorState.initial() {
    final initial = AvatarData.initial();
    return AvatarEditorState(
      currentData: initial,
      history: [initial],
      historyIndex: 0,
    );
  }
}

/// Riverpod 3.x Notifier for Avatar Editor
/// Migrated from StateNotifier to Notifier pattern
class AvatarEditorNotifier extends Notifier<AvatarEditorState> {
  late final AvatarRepository _repository;
  late final String _userId;

  @override
  AvatarEditorState build() {
    // Initialize dependencies
    final db = sl<AppDatabase>();
    _repository = AvatarRepository(db);
    _userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    // Trigger async load
    Future.microtask(() => loadAvatar());

    return AvatarEditorState.initial();
  }

  /// Initialize state, optionally loading existing avatar
  Future<void> loadAvatar() async {
    if (_userId.isEmpty) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final existing = await _repository.getAvatar(_userId);
      if (existing != null) {
        state = AvatarEditorState(
          currentData: existing,
          history: [existing],
          historyIndex: 0,
          isLoading: false,
        );
      } else {
        // Start with default
        final initial = AvatarData.initial();
        state = AvatarEditorState(
          currentData: initial,
          history: [initial],
          historyIndex: 0,
          isLoading: false,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: "Failed to load avatar: $e",
      );
    }
  }

  void updateAvatar(AvatarData newData) {
    if (newData == state.currentData) return;

    // Add to history, removing any future history if we were in the middle of undo stack
    final newHistory = state.history
        .sublist(0, state.historyIndex + 1)
        .toList();
    newHistory.add(newData);

    // Limit history size to 20 to prevent memory issues
    if (newHistory.length > 20) {
      newHistory.removeAt(0);
    }

    state = state.copyWith(
      currentData: newData,
      history: newHistory,
      historyIndex: newHistory.length - 1,
    );
  }

  void undo() {
    if (state.historyIndex > 0) {
      final newIndex = state.historyIndex - 1;
      state = state.copyWith(
        currentData: state.history[newIndex],
        historyIndex: newIndex,
      );
    }
  }

  void redo() {
    if (state.historyIndex < state.history.length - 1) {
      final newIndex = state.historyIndex + 1;
      state = state.copyWith(
        currentData: state.history[newIndex],
        historyIndex: newIndex,
      );
    }
  }

  Future<void> save() async {
    if (_userId.isEmpty) {
      state = state.copyWith(error: "User not logged in");
      return;
    }

    state = state.copyWith(isSaving: true, error: null);
    try {
      await _repository.saveAvatar(_userId, state.currentData);
      state = state.copyWith(isSaving: false);
    } catch (e) {
      state = state.copyWith(isSaving: false, error: "Failed to save: $e");
    }
  }

  /// Reset to default avatar
  void resetToDefault() {
    final initial = AvatarData.initial();
    state = AvatarEditorState(
      currentData: initial,
      history: [initial],
      historyIndex: 0,
    );
  }
}

// Provider - Riverpod 3.x syntax
final avatarEditorProvider =
    NotifierProvider<AvatarEditorNotifier, AvatarEditorState>(
      AvatarEditorNotifier.new,
    );
