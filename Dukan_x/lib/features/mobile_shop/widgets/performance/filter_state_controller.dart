/// FilterStateController — Manages filter state without triggering rescans on no-change.
///
/// Tracks filter state transitions and only notifies listeners when the
/// effective filter actually changes, preventing full-list rescans when
/// the user reselects the same filter value.
///
/// Requirements: 11.11
library;

import 'package:flutter/foundation.dart';

/// Represents a set of filter criteria that can be compared for equality.
///
/// Implementations must override [==] and [hashCode] to enable
/// change detection.
@immutable
abstract class FilterState {
  const FilterState();

  /// Whether any filter is actively applied (not at default values).
  bool get hasActiveFilters;
}

/// A concrete filter state backed by a map of key-value pairs.
@immutable
class MapFilterState extends FilterState {
  final Map<String, Object?> _filters;

  const MapFilterState(this._filters);

  /// Creates an empty filter state (no active filters).
  const MapFilterState.empty() : _filters = const {};

  /// The underlying filter map.
  Map<String, Object?> get filters => Map.unmodifiable(_filters);

  /// Get a filter value by key.
  T? get<T>(String key) => _filters[key] as T?;

  /// Create a new state with one filter updated.
  MapFilterState copyWith(String key, Object? value) {
    final updated = Map<String, Object?>.from(_filters);
    if (value == null) {
      updated.remove(key);
    } else {
      updated[key] = value;
    }
    return MapFilterState(updated);
  }

  /// Create a new state with a filter removed.
  MapFilterState without(String key) {
    final updated = Map<String, Object?>.from(_filters);
    updated.remove(key);
    return MapFilterState(updated);
  }

  @override
  bool get hasActiveFilters => _filters.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapFilterState &&
          runtimeType == other.runtimeType &&
          mapEquals(_filters, other._filters);

  @override
  int get hashCode =>
      Object.hashAll(_filters.entries.map((e) => Object.hash(e.key, e.value)));
}

/// Controller that manages filter state and only triggers callbacks
/// when the filter actually changes.
///
/// This prevents unnecessary full-list rescans when:
/// - The user reselects the same tab/status filter
/// - A filter chip is toggled back to its current state
/// - Filter parameters are set to values identical to current state
class FilterStateController<T extends FilterState> extends ChangeNotifier {
  T _currentState;

  /// Callback invoked only when the filter state actually changes.
  final ValueChanged<T>? onFilterChanged;

  FilterStateController({required T initialState, this.onFilterChanged})
    : _currentState = initialState;

  /// Current filter state.
  T get state => _currentState;

  /// Whether any filter is active.
  bool get hasActiveFilters => _currentState.hasActiveFilters;

  /// Update the filter state. Only notifies if the new state differs.
  /// Returns true if the state was actually changed.
  bool updateState(T newState) {
    if (_currentState == newState) return false;
    _currentState = newState;
    onFilterChanged?.call(newState);
    notifyListeners();
    return true;
  }

  /// Reset to the provided default state.
  /// Only notifies if different from current.
  bool reset(T defaultState) {
    return updateState(defaultState);
  }
}
