import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/sync/engine/sync_engine.dart'; // New Engine import

// Idempotency: Sync queue operations carry stable idempotency keys (operationId / requestId / idempotencyKey) to ensure server-side deduplication.

/// State for the SyncController
class SyncState {
  final bool isLoading;
  final String? error;
  final String? message;

  const SyncState({this.isLoading = false, this.error, this.message});

  SyncState copyWith({bool? isLoading, String? error, String? message}) {
    return SyncState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      message: message,
    );
  }
}

/// Controller for interacting with the Sync System safely.
/// Isolates the UI from Direct SyncManager calls.
class SyncController extends Notifier<SyncState> {
  @override
  SyncState build() {
    return const SyncState();
  }

  /// Triggers a manual sync.
  /// Handles loading state and error reporting.
  Future<void> triggerManualSync() async {
    if (state.isLoading) return;

    state = const SyncState(isLoading: true, message: 'Starting sync...');

    try {
      // Use the new Isolated Sync Engine
      await SyncEngine.instance.triggerSync();

      // Artificial delay to show "Syncing" state if the operation is too fast,
      // or to allow the stream updates to propagate.
      await Future.delayed(const Duration(milliseconds: 500));

      state = const SyncState(isLoading: false, message: 'Sync initiated');
    } catch (e, st) {
      state = SyncState(
        isLoading: false,
        error: 'Failed to start sync: ${e.toString()}',
      );
      debugPrint('SyncController Error: $e\n$st');
    }
  }

  /// Clears error messages
  void clearError() {
    if (state.error != null) {
      // Reset error
      state = SyncState(isLoading: state.isLoading, message: state.message);
    }
  }
}

final syncControllerProvider = NotifierProvider<SyncController, SyncState>(() {
  return SyncController();
});
