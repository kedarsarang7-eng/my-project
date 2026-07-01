// ignore_for_file: unreachable_switch_default
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: invalid_use_of_visible_for_testing_member
// ============================================================================
// DESKTOP USB BARCODE SCANNER WIDGET
// ============================================================================
// Hidden TextField that captures USB/Bluetooth barcode scanner input
// Optimized for Flutter Desktop (Windows/macOS/Linux)
//
// Features:
// - 50ms debounce to prevent duplicate scans
// - Auto-refocus for continuous scanning
// - Keyboard shortcut (Ctrl+B) to focus scanner
// - Visual indicator showing scanner ready state
// - Multi-tenant isolation (tenantId in API calls)
// - Offline support with Hive cache
//
// Phase 1: Grocery, Pharmacy, Hardware support
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/logger_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';

import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/session/session_manager.dart';
import '../services/barcode_lookup_service.dart';
import '../models/barcode_scan_result.dart';

// ============================================================================
// PROVIDERS
// ============================================================================

/// Scanner state provider
class _UsbScannerStateNotifier extends Notifier<UsbScannerState> {
  @override
  UsbScannerState build() => const UsbScannerState();
  void update(UsbScannerState s) => state = s;
}
final usbScannerStateProvider = NotifierProvider<_UsbScannerStateNotifier, UsbScannerState>(_UsbScannerStateNotifier.new);

/// Scanner configuration provider
final usbScannerConfigProvider = Provider<UsbScannerConfig>((ref) {
  return const UsbScannerConfig();
});

// ============================================================================
// STATE & CONFIG
// ============================================================================

enum ScannerStatus {
  idle,       // Ready for input
  scanning,   // Processing input
  lookingUp,  // API call in progress
  offline,    // Using local cache
  success,    // Product found
  notFound,   // Product not found
  error,      // Error occurred
}

class UsbScannerState {
  final ScannerStatus status;
  final String? lastBarcode;
  final ScannedProduct? product;
  final String? errorMessage;
  final bool isOnline;
  final DateTime? lastScanTime;

  const UsbScannerState({
    this.status = ScannerStatus.idle,
    this.lastBarcode,
    this.product,
    this.errorMessage,
    this.isOnline = true,
    this.lastScanTime,
  });

  UsbScannerState copyWith({
    ScannerStatus? status,
    String? lastBarcode,
    ScannedProduct? product,
    String? errorMessage,
    bool? isOnline,
    DateTime? lastScanTime,
    bool clearProduct = false,
  }) {
    return UsbScannerState(
      status: status ?? this.status,
      lastBarcode: lastBarcode ?? this.lastBarcode,
      product: clearProduct ? null : (product ?? this.product),
      errorMessage: errorMessage ?? this.errorMessage,
      isOnline: isOnline ?? this.isOnline,
      lastScanTime: lastScanTime ?? this.lastScanTime,
    );
  }

  bool get isLoading =>
      status == ScannerStatus.scanning ||
      status == ScannerStatus.lookingUp ||
      status == ScannerStatus.offline;
}

class UsbScannerConfig {
  final int debounceMs;
  final int minScanIntervalMs;
  final bool playBeepOnSuccess;
  final bool showOfflineIndicator;
  final bool autoRefocus;

  const UsbScannerConfig({
    this.debounceMs = 50,
    this.minScanIntervalMs = 100,
    this.playBeepOnSuccess = true,
    this.showOfflineIndicator = true,
    this.autoRefocus = true,
  });
}

// ============================================================================
// DESKTOP USB SCANNER WIDGET
// ============================================================================

class DesktopUsbScanner extends ConsumerStatefulWidget {
  /// Callback when a product is found
  final void Function(ScannedProduct)? onProductScanned;
  
  /// Callback when product not found
  final void Function(String barcode)? onProductNotFound;
  
  /// Callback for any error
  final void Function(String error)? onError;
  
  /// Optional child widget to display alongside scanner
  final Widget? child;
  
  /// Whether to show the scanner indicator
  final bool showIndicator;
  
  /// Whether to auto-focus on mount
  final bool autoFocus;
  
  /// Business type for feature gating
  final String? businessType;

  const DesktopUsbScanner({
    super.key,
    this.onProductScanned,
    this.onProductNotFound,
    this.onError,
    this.child,
    this.showIndicator = true,
    this.autoFocus = true,
    this.businessType,
  });

  @override
  ConsumerState<DesktopUsbScanner> createState() =>
      _DesktopUsbScannerState();
}

class _DesktopUsbScannerState extends ConsumerState<DesktopUsbScanner> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  late final BarcodeLookupService _lookupService;
  late final SessionManager _session;
  
  Timer? _debounceTimer;
  String _buffer = '';
  DateTime? _lastScanTimestamp;
  
  // BUG-022: In-flight request tracking to prevent duplicate scans
  bool _isLookupInProgress = false;
  String? _pendingBarcode;
  int _lookupRequestId = 0; // For request deduplication

  @override
  void initState() {
    super.initState();
    _lookupService = sl<BarcodeLookupService>();
    _session = sl<SessionManager>();
    
    // Listen to connectivity changes
    Connectivity().onConnectivityChanged.listen((results) {
      final isOnline = !results.contains(ConnectivityResult.none);
      ref.read(usbScannerStateProvider.notifier).state =
          ref.read(usbScannerStateProvider).copyWith(isOnline: isOnline);
    });
    
    // Auto-focus after build
    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  /// Handle barcode submission
  void _onBarcodeSubmitted(String value) {
    final config = ref.read(usbScannerConfigProvider);
    final trimmed = value.trim();
    
    if (trimmed.isEmpty) return;

    // Check for duplicate scans
    final now = DateTime.now();
    if (_lastScanTimestamp != null) {
      final diff = now.difference(_lastScanTimestamp!).inMilliseconds;
      if (diff < config.minScanIntervalMs && trimmed == _buffer) {
        // Duplicate scan - ignore
        _controller.clear();
        return;
      }
    }
    _lastScanTimestamp = now;
    _buffer = trimmed;

    // BUG-022: Check if lookup is already in progress
    if (_isLookupInProgress) {
      LoggerService.d('BarcodeScanner', '[BARCODE_SCANNER] Lookup in progress, queuing new scan: $trimmed');
      _pendingBarcode = trimmed;
      
      // Clear field but don't start new lookup yet
      _controller.clear();
      
      // Refocus if enabled
      if (config.autoRefocus) {
        _focusNode.requestFocus();
      }
      return;
    }

    // Cancel any pending debounce
    _debounceTimer?.cancel();

    // Set scanning state
    ref.read(usbScannerStateProvider.notifier).state =
        ref.read(usbScannerStateProvider).copyWith(
          status: ScannerStatus.scanning,
          lastBarcode: trimmed,
          clearProduct: true,
        );

    // Debounce processing
    _debounceTimer = Timer(Duration(milliseconds: config.debounceMs), () {
      _processBarcode(trimmed);
    });

    // Clear field for next scan
    _controller.clear();
    
    // Refocus if enabled
    if (config.autoRefocus) {
      _focusNode.requestFocus();
    }
  }

  /// Process the barcode (validation + lookup)
  Future<void> _processBarcode(String barcode) async {
    // BUG-022: Mark lookup as in progress
    _isLookupInProgress = true;
    _pendingBarcode = null; // Clear any previously queued
    
    // Generate unique request ID for deduplication
    final currentRequestId = ++_lookupRequestId;
    
    final config = ref.read(usbScannerConfigProvider);
    
    // Validate barcode format
    final validation = _validateBarcode(barcode);
    if (!validation.valid) {
      _setError('Invalid barcode: ${validation.error}');
      _isLookupInProgress = false;
      _processPendingBarcode(); // Check for queued scans
      return;
    }

    // Check connectivity
    final results = await Connectivity().checkConnectivity();
    final isOnline = !results.contains(ConnectivityResult.none);
    
    if (!isOnline) {
      ref.read(usbScannerStateProvider.notifier).state =
          ref.read(usbScannerStateProvider).copyWith(
            status: ScannerStatus.offline,
            isOnline: false,
          );
    } else {
      ref.read(usbScannerStateProvider.notifier).state =
          ref.read(usbScannerStateProvider).copyWith(
            status: ScannerStatus.lookingUp,
            isOnline: true,
          );
    }

    try {
      // Lookup product
      final result = await _lookupService.lookupBarcode(
        barcode: barcode,
        businessId: _session.ownerId,
      );

      // BUG-022: Check if this is still the current request (deduplication)
      // If a newer scan came in, discard this result
      if (currentRequestId != _lookupRequestId) {
        LoggerService.d('BarcodeScanner', '[BARCODE_SCANNER] Discarding stale lookup result for: $barcode');
        return;
      }

      if (result.success && result.product != null) {
        // Product found
        ref.read(usbScannerStateProvider.notifier).state =
            ref.read(usbScannerStateProvider).copyWith(
              status: ScannerStatus.success,
              product: result.product,
              lastScanTime: DateTime.now(),
            );

        // Play success beep
        if (config.playBeepOnSuccess) {
          _playBeep();
        }

        // Notify callback
        widget.onProductScanned?.call(result.product!);
      } else {
        // Product not found
        ref.read(usbScannerStateProvider.notifier).state =
            ref.read(usbScannerStateProvider).copyWith(
              status: ScannerStatus.notFound,
              errorMessage: result.errorMessage ?? 'Product not found',
            );

        widget.onProductNotFound?.call(barcode);
      }
    } catch (e) {
      _setError('Lookup failed: $e');
    } finally {
      // BUG-022: Mark lookup as complete and process any pending barcode
      _isLookupInProgress = false;
      _processPendingBarcode();
    }
  }

  /// BUG-022: Process any barcode that was scanned while lookup was in progress
  void _processPendingBarcode() {
    if (_pendingBarcode != null && _pendingBarcode!.isNotEmpty) {
      LoggerService.d('BarcodeScanner', '[BARCODE_SCANNER] Processing queued barcode: $_pendingBarcode');
      final barcode = _pendingBarcode!;
      _pendingBarcode = null;
      
      // Small delay to allow UI to settle
      Future.delayed(const Duration(milliseconds: 50), () {
        _processBarcode(barcode);
      });
    }
  }

  void _setError(String message) {
    ref.read(usbScannerStateProvider.notifier).state =
        ref.read(usbScannerStateProvider).copyWith(
          status: ScannerStatus.error,
          errorMessage: message,
        );

    widget.onError?.call(message);
  }

  ({bool valid, String? error, String? format}) _validateBarcode(String barcode) {
    if (barcode.isEmpty) {
      return (valid: false, error: 'Empty barcode', format: null);
    }

    if (barcode.length > 48) {
      return (valid: false, error: 'Barcode too long', format: null);
    }

    // EAN-13: 13 digits
    if (RegExp(r'^\d{13}$').hasMatch(barcode)) {
      if (!_verifyEan13CheckDigit(barcode)) {
        return (valid: false, error: 'Invalid EAN-13 check digit', format: 'EAN13');
      }
      return (valid: true, error: null, format: 'EAN13');
    }

    // EAN-8: 8 digits
    if (RegExp(r'^\d{8}$').hasMatch(barcode)) {
      if (!_verifyEan8CheckDigit(barcode)) {
        return (valid: false, error: 'Invalid EAN-8 check digit', format: 'EAN8');
      }
      return (valid: true, error: null, format: 'EAN8');
    }

    // UPC-A: 12 digits
    if (RegExp(r'^\d{12}$').hasMatch(barcode)) {
      return (valid: true, error: null, format: 'UPCA');
    }

    // Code-128 / Generic: Alphanumeric
    if (RegExp(r'^[A-Za-z0-9\-_]{6,48}$').hasMatch(barcode)) {
      return (valid: true, error: null, format: 'CODE128');
    }

    return (valid: false, error: 'Invalid format', format: null);
  }

  bool _verifyEan13CheckDigit(String ean) {
    int sum = 0;
    for (int i = 0; i < 12; i++) {
      final digit = int.parse(ean[i]);
      sum += (i % 2 == 0) ? digit : digit * 3;
    }
    final checkDigit = (10 - (sum % 10)) % 10;
    return checkDigit == int.parse(ean[12]);
  }

  bool _verifyEan8CheckDigit(String ean) {
    int sum = 0;
    for (int i = 0; i < 7; i++) {
      final digit = int.parse(ean[i]);
      sum += (i % 2 == 0) ? digit * 3 : digit;
    }
    final checkDigit = (10 - (sum % 10)) % 10;
    return checkDigit == int.parse(ean[7]);
  }

  Future<void> _playBeep() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/beep.mp3'), volume: 0.3);
    } catch (e) {
      // Sound not critical
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(usbScannerStateProvider);
    
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (event) {
        // Ctrl+B to focus scanner
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.keyB &&
              HardwareKeyboard.instance.isControlPressed) {
            _focusNode.requestFocus();
          }
        }
      },
      child: Stack(
        children: [
          // Main content
          if (widget.child != null) widget.child!,
          
          // Hidden scanner input
          Positioned(
            top: 0,
            left: 0,
            width: 1,
            height: 1,
            child: Opacity(
              opacity: 0.01,
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                onSubmitted: _onBarcodeSubmitted,
                onChanged: (value) {
                  // Handle scanners that don't send Enter
                  if (value.contains('\n') || value.contains('\r')) {
                    final clean = value.replaceAll('\n', '').replaceAll('\r', '');
                    _onBarcodeSubmitted(clean);
                  }
                },
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                style: const TextStyle(fontSize: 1),
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.none,
                enableSuggestions: false,
                autocorrect: false,
                autofocus: widget.autoFocus,
              ),
            ),
          ),
          
          // Scanner indicator
          if (widget.showIndicator)
            Positioned(
              top: 8,
              right: 8,
              child: _ScannerIndicator(
                state: state,
                onTap: () => _focusNode.requestFocus(),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// SCANNER INDICATOR WIDGET
// ============================================================================

class _ScannerIndicator extends StatelessWidget {
  final UsbScannerState state;
  final VoidCallback onTap;

  const _ScannerIndicator({
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    Color indicatorColor;
    IconData icon;
    String tooltip;
    Widget? trailing;

    switch (state.status) {
      case ScannerStatus.scanning:
      case ScannerStatus.lookingUp:
      case ScannerStatus.offline:
        indicatorColor = theme.colorScheme.primary;
        icon = Icons.qr_code_scanner;
        tooltip = state.isOnline ? 'Scanning...' : 'Offline mode';
        trailing = SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: indicatorColor,
          ),
        );
        break;
      case ScannerStatus.success:
        indicatorColor = Colors.green;
        icon = Icons.check_circle;
        tooltip = 'Product found: ${state.product?.name ?? ''}';
        break;
      case ScannerStatus.notFound:
        indicatorColor = Colors.orange;
        icon = Icons.help_outline;
        tooltip = 'Product not found';
        break;
      case ScannerStatus.error:
        indicatorColor = Colors.red;
        icon = Icons.error_outline;
        tooltip = state.errorMessage ?? 'Error';
        break;
      case ScannerStatus.idle:
      default:
        if (!state.isOnline) {
          indicatorColor = Colors.orange;
          icon = Icons.offline_bolt;
          tooltip = 'Offline mode';
        } else {
          indicatorColor = Colors.green;
          icon = Icons.qr_code_scanner;
          tooltip = 'Scanner ready (Ctrl+B)';
        }
    }

    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: indicatorColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: indicatorColor.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: state.status == ScannerStatus.idle && state.isOnline
                ? [
                    BoxShadow(
                      color: indicatorColor.withValues(alpha: 0.2),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: indicatorColor),
              const SizedBox(width: 6),
              Text(
                _getStatusText(state),
                style: TextStyle(
                  fontSize: 11,
                  color: indicatorColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 6),
                trailing,
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _getStatusText(UsbScannerState state) {
    switch (state.status) {
      case ScannerStatus.scanning:
      case ScannerStatus.lookingUp:
        return 'Scanning...';
      case ScannerStatus.offline:
        return 'Offline';
      case ScannerStatus.success:
        return 'Found';
      case ScannerStatus.notFound:
        return 'Not Found';
      case ScannerStatus.error:
        return 'Error';
      case ScannerStatus.idle:
      default:
        return state.isOnline ? 'Scanner Ready' : 'Offline';
    }
  }
}
