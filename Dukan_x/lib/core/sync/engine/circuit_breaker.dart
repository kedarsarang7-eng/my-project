import 'dart:async';
import 'package:flutter/foundation.dart';

// Idempotency: Sync queue operations carry stable idempotency keys (operationId / requestId / idempotencyKey) to ensure server-side deduplication.

/// State of the Circuit Breaker
enum CircuitState { closed, open, halfOpen }

/// Protects the system from repeated failures by "opening" the circuit
/// when a failure threshold is reached.
class CircuitBreaker {
  // Configuration
  final int failureThreshold;
  final Duration resetTimeout;
  final Duration failureWindow;

  // State
  CircuitState _state = CircuitState.closed;
  int _failureCount = 0;
  DateTime? _lastFailureTime;
  Timer? _resetTimer;
  DateTime? _nextTryTime;

  CircuitBreaker({
    this.failureThreshold = 5,
    this.resetTimeout = const Duration(minutes: 1),
    this.failureWindow = const Duration(minutes: 5),
  });

  bool get isOpen => _state == CircuitState.open;
  bool get isClosed => _state == CircuitState.closed;
  bool get isHalfOpen => _state == CircuitState.halfOpen;

  /// Returns the time when the circuit will attempt to reset (if open)
  DateTime? get nextTryTime => _nextTryTime;

  /// Check if execution is allowed
  bool get canExecute {
    if (_state == CircuitState.closed) return true;
    if (_state == CircuitState.halfOpen) return true; // Allow 1 probe

    // If Open, check if timeout has passed to switch to Half-Open
    if (_nextTryTime != null && DateTime.now().isAfter(_nextTryTime!)) {
      _transitionTo(CircuitState.halfOpen);
      return true;
    }
    return false;
  }

  /// Record a success execution
  void onSuccess() {
    if (_state == CircuitState.halfOpen) {
      _transitionTo(CircuitState.closed);
    }
    _resetFailures();
  }

  /// Record a failed execution
  void onFailure() {
    final now = DateTime.now();

    // If we are in Half-Open and fail, go back to Open immediately
    if (_state == CircuitState.halfOpen) {
      _transitionTo(CircuitState.open);
      return;
    }

    // Check if failure window expired, if so reset count
    if (_lastFailureTime != null &&
        now.difference(_lastFailureTime!) > failureWindow) {
      _failureCount = 0;
    }

    _failureCount++;
    _lastFailureTime = now;

    if (_failureCount >= failureThreshold) {
      _transitionTo(CircuitState.open);
    }
  }

  void _transitionTo(CircuitState newState) {
    debugPrint('CircuitBreaker: Transitioning from $_state to $newState');
    _state = newState;

    if (newState == CircuitState.open) {
      _nextTryTime = DateTime.now().add(resetTimeout);
      _resetTimer?.cancel();
    } else if (newState == CircuitState.closed) {
      _nextTryTime = null;
      _resetFailures();
    }
  }

  void _resetFailures() {
    _failureCount = 0;
    _lastFailureTime = null;
  }

  /// Reset manually
  void reset() {
    _transitionTo(CircuitState.closed);
  }
}
