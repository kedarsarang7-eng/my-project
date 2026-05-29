import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_provider.dart';
import '../../../core/websocket/websocket_manager.dart';
import '../data/qr_payment_repository.dart';
import 'license_provider.dart';

/// QR Payment state
class QRPaymentState {
  final bool isLoading;
  final bool isGenerating;
  final bool isPolling;
  final QRPaymentResponse? qrResponse;
  final PaymentStatusResponse? paymentStatus;
  final String? error;
  final int? remainingSeconds;

  const QRPaymentState({
    this.isLoading = false,
    this.isGenerating = false,
    this.isPolling = false,
    this.qrResponse,
    this.paymentStatus,
    this.error,
    this.remainingSeconds,
  });

  QRPaymentState copyWith({
    bool? isLoading,
    bool? isGenerating,
    bool? isPolling,
    QRPaymentResponse? qrResponse,
    PaymentStatusResponse? paymentStatus,
    String? error,
    int? remainingSeconds,
  }) {
    return QRPaymentState(
      isLoading: isLoading ?? this.isLoading,
      isGenerating: isGenerating ?? this.isGenerating,
      isPolling: isPolling ?? this.isPolling,
      qrResponse: qrResponse ?? this.qrResponse,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      error: error,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
    );
  }

  bool get hasQR => qrResponse != null;
  bool get isPaid => paymentStatus?.isSuccess ?? false;
  bool get isFailed => paymentStatus?.isFailed ?? false;
  bool get isPending => paymentStatus?.isPending ?? true;
}

/// QR Payment notifier - manages QR generation and payment status
class QRPaymentNotifier extends StateNotifier<QRPaymentState> {
  final Ref _ref;
  final QRPaymentRepository _repository = QRPaymentRepository();
  final WebSocketManager _webSocketManager = WebSocketManager();

  Timer? _expiryTimer;
  Timer? _pollingTimer;
  StreamSubscription<WebSocketMessage>? _wsSubscription;

  QRPaymentNotifier(this._ref) : super(const QRPaymentState()) {
    // Connect to WebSocket when initialized
    _connectWebSocket();
  }

  /// Connect to WebSocket for real-time payment notifications
  Future<void> _connectWebSocket() async {
    try {
      await _webSocketManager.connect();
      
      // Listen for payment success messages
      _wsSubscription = _webSocketManager.messages.listen(_onWebSocketMessage);
    } catch (e) {
      debugPrint('WebSocket connection failed: $e');
      // Will fallback to polling
    }
  }

  /// Handle WebSocket messages
  void _onWebSocketMessage(WebSocketMessage message) {
    if (message.isPaymentSuccess || message.isPaymentFailed) {
      // Check if this message is for our current transaction
      final currentTransactionId = state.qrResponse?.transactionId;
      final messageTransactionId = message.transactionId;

      // If no current transaction, or message matches our transaction
      if (currentTransactionId == null || currentTransactionId == messageTransactionId) {
        _handlePaymentComplete(message);
      }
    }
  }

  /// Generate QR code for payment
  Future<void> generateQR({
    required double amountRupees,
    String? description,
  }) async {
    if (state.isGenerating) return;

    // Cancel any existing timers
    _clearTimers();

    state = state.copyWith(
      isGenerating: true,
      error: null,
      qrResponse: null,
      paymentStatus: null,
    );

    try {
      final license = _ref.read(licenseProvider).profile;
      if (license == null) {
        throw Exception('No license profile available');
      }

      final authRepo = _ref.read(authRepositoryProvider);
      final staffId = await authRepo.getCurrentUserId();

      final response = await _repository.generateQR(
        amountRupees: amountRupees,
        stationId: license.stationId,
        staffId: staffId,
        description: description,
      );

      state = state.copyWith(
        isGenerating: false,
        qrResponse: response,
        remainingSeconds: response.remainingSeconds,
      );

      // Start expiry countdown
      _startExpiryTimer();

      // Start polling as fallback
      _startPollingFallback();
    } catch (e) {
      state = state.copyWith(
        isGenerating: false,
        error: e.toString(),
      );
    }
  }

  /// Start countdown timer for QR expiry
  void _startExpiryTimer() {
    _expiryTimer?.cancel();
    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final remaining = state.qrResponse?.remainingSeconds ?? 0;
      
      if (remaining <= 0) {
        _expiryTimer?.cancel();
        state = state.copyWith(
          error: 'QR code has expired. Please generate a new one.',
        );
      } else {
        state = state.copyWith(remainingSeconds: remaining);
      }
    });
  }

  /// Start polling fallback when WebSocket might fail
  void _startPollingFallback() {
    final orderId = state.qrResponse?.orderId;
    if (orderId == null) return;

    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (state.isPaid || state.isFailed) {
        _pollingTimer?.cancel();
        return;
      }

      try {
        final status = await _repository.getPaymentStatus(orderId);
        
        if (status.isSuccess || status.isFailed) {
          state = state.copyWith(paymentStatus: status);
          _pollingTimer?.cancel();
          _expiryTimer?.cancel();
          
          // Trigger navigation based on status
          if (status.isSuccess) {
            _onPaymentSuccess();
          } else {
            _onPaymentFailed();
          }
        }
      } catch (e) {
        debugPrint('Polling error: $e');
      }
    });
  }

  /// Handle payment completion from WebSocket or polling
  void _handlePaymentComplete(WebSocketMessage message) {
    _clearTimers();

    final status = PaymentStatusResponse(
      orderId: message.orderId ?? state.qrResponse?.orderId ?? '',
      transactionId: message.transactionId ?? state.qrResponse?.transactionId ?? '',
      status: message.isPaymentSuccess ? 'SUCCESS' : 'FAILED',
      amountPaise: message.amountPaise ?? state.qrResponse?.amountPaise ?? 0,
      rawResponse: message.payload,
    );

    state = state.copyWith(paymentStatus: status);

    if (message.isPaymentSuccess) {
      _onPaymentSuccess();
    } else {
      _onPaymentFailed();
    }
  }

  /// Called when payment succeeds
  void _onPaymentSuccess() {
    // State is already updated, navigation will be handled by UI
    debugPrint('Payment succeeded!');
  }

  /// Called when payment fails
  void _onPaymentFailed() {
    // State is already updated, navigation will be handled by UI
    debugPrint('Payment failed!');
  }

  /// Cancel the payment
  Future<void> cancelPayment() async {
    final orderId = state.qrResponse?.orderId;
    if (orderId == null) return;

    try {
      await _repository.cancelPayment(orderId);
    } catch (e) {
      debugPrint('Failed to cancel payment: $e');
    }

    _clearTimers();
    state = const QRPaymentState();
  }

  /// Clear all timers and subscriptions
  void _clearTimers() {
    _expiryTimer?.cancel();
    _pollingTimer?.cancel();
    _expiryTimer = null;
    _pollingTimer = null;
  }

  /// Reset state (called when leaving QR screen)
  void reset() {
    _clearTimers();
    state = const QRPaymentState();
  }

  /// Dispose resources
  @override
  void dispose() {
    _clearTimers();
    _wsSubscription?.cancel();
    super.dispose();
  }
}

/// Provider for QR payment state
final qrPaymentProvider = StateNotifierProvider<QRPaymentNotifier, QRPaymentState>((ref) {
  return QRPaymentNotifier(ref);
});

/// Provider for current QR response (convenience)
final currentQRProvider = Provider<QRPaymentResponse?>((ref) {
  return ref.watch(qrPaymentProvider).qrResponse;
});

/// Provider for payment status (convenience)
final paymentStatusProvider = Provider<PaymentStatusResponse?>((ref) {
  return ref.watch(qrPaymentProvider).paymentStatus;
});
