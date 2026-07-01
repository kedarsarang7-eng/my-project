// ============================================================================
// Scan Bill Session Provider — Riverpod State Management with Persistence
// ============================================================================
// Manages the entire scan bill flow state:
// - Image capture/upload
// - OCR processing
// - Product matching
// - Review & editing
// - Submission
//
// State is persisted to local storage (Hive) to prevent data loss on app
// backgrounding or crashes.
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/services/logger_service.dart';
import '../models/scan_bill_models.dart';
import '../services/scan_bill_api_client.dart';
import '../services/scan_bill_offline_queue.dart';

/// Session state
class ScanBillSessionState {
  final String rid;
  final File? imageFile;
  final List<File> imageFiles; // Multi-image support
  final String? s3ImageKey;
  final List<String> s3ImageKeys; // Multi-image support
  final String? presignedUrl;
  final List<String> presignedUrls; // Multi-image support
  final String verticalType;
  final bool isExtracting;
  final ExtractionResult? extractionResult;
  final bool isMatching;
  final MatchResultResponse? matchResult;
  final List<ReviewLineItem>? reviewLineItems;
  final SupplierDetails? supplierDetails;
  final bool isSubmitting;
  final String? error;
  final bool isOfflineQueued;
  final bool isMultiPage;
  final DateTime createdAt;
  final DateTime updatedAt;

  ScanBillSessionState({
    required this.rid,
    this.imageFile,
    this.imageFiles = const [],
    this.s3ImageKey,
    this.s3ImageKeys = const [],
    this.presignedUrl,
    this.presignedUrls = const [],
    required this.verticalType,
    this.isExtracting = false,
    this.extractionResult,
    this.isMatching = false,
    this.matchResult,
    this.reviewLineItems,
    this.supplierDetails,
    this.isSubmitting = false,
    this.error,
    this.isOfflineQueued = false,
    this.isMultiPage = false,
    required this.createdAt,
    required this.updatedAt,
  });

  ScanBillSessionState.initial({required this.verticalType, String? rid})
    : rid = rid ?? const Uuid().v4(),
      imageFile = null,
      imageFiles = const [],
      s3ImageKey = null,
      s3ImageKeys = const [],
      presignedUrl = null,
      presignedUrls = const [],
      isExtracting = false,
      extractionResult = null,
      isMatching = false,
      matchResult = null,
      reviewLineItems = null,
      supplierDetails = null,
      isSubmitting = false,
      error = null,
      isOfflineQueued = false,
      isMultiPage = false,
      createdAt = DateTime.now(),
      updatedAt = DateTime.now();

  ScanBillSessionState copyWith({
    String? rid,
    File? imageFile,
    List<File>? imageFiles,
    String? s3ImageKey,
    List<String>? s3ImageKeys,
    String? presignedUrl,
    List<String>? presignedUrls,
    String? verticalType,
    bool? isExtracting,
    ExtractionResult? extractionResult,
    bool? isMatching,
    MatchResultResponse? matchResult,
    List<ReviewLineItem>? reviewLineItems,
    SupplierDetails? supplierDetails,
    bool? isSubmitting,
    String? error,
    bool? isOfflineQueued,
    bool? isMultiPage,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ScanBillSessionState(
      rid: rid ?? this.rid,
      imageFile: imageFile ?? this.imageFile,
      imageFiles: imageFiles ?? this.imageFiles,
      s3ImageKey: s3ImageKey ?? this.s3ImageKey,
      s3ImageKeys: s3ImageKeys ?? this.s3ImageKeys,
      presignedUrl: presignedUrl ?? this.presignedUrl,
      presignedUrls: presignedUrls ?? this.presignedUrls,
      verticalType: verticalType ?? this.verticalType,
      isExtracting: isExtracting ?? this.isExtracting,
      extractionResult: extractionResult ?? this.extractionResult,
      isMatching: isMatching ?? this.isMatching,
      matchResult: matchResult ?? this.matchResult,
      reviewLineItems: reviewLineItems ?? this.reviewLineItems,
      supplierDetails: supplierDetails ?? this.supplierDetails,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error ?? this.error,
      isOfflineQueued: isOfflineQueued ?? this.isOfflineQueued,
      isMultiPage: isMultiPage ?? this.isMultiPage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rid': rid,
      'imagePath': imageFile?.path,
      's3ImageKey': s3ImageKey,
      'presignedUrl': presignedUrl,
      'verticalType': verticalType,
      'extractionResult': extractionResult != null
          ? {
              'rid': extractionResult!.rid,
              's3ImageKey': extractionResult!.s3ImageKey,
              'presignedUrl': extractionResult!.presignedUrl,
              'parsedLines': extractionResult!.parsedLines
                  .map((e) => e.toJson())
                  .toList(),
              'warning': extractionResult!.warning,
            }
          : null,
      'reviewLineItems': reviewLineItems?.map((e) => e.toJson()).toList(),
      'supplierDetails': supplierDetails?.toJson(),
      'isOfflineQueued': isOfflineQueued,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ScanBillSessionState.fromJson(
    Map<String, dynamic> json,
    String verticalType,
  ) {
    final extractionData = json['extractionResult'] as Map<String, dynamic>?;

    return ScanBillSessionState(
      rid: json['rid'] ?? const Uuid().v4(),
      imageFile: json['imagePath'] != null ? File(json['imagePath']) : null,
      s3ImageKey: json['s3ImageKey'],
      presignedUrl: json['presignedUrl'],
      verticalType: verticalType,
      extractionResult: extractionData != null
          ? ExtractionResult.fromJson(extractionData)
          : null,
      reviewLineItems: (json['reviewLineItems'] as List?)
          ?.map(
            (e) => ReviewLineItem.fromMatchResult(
              MatchResult.fromJson({
                'parsedItem': e,
                'matchConfidence': 'none',
                'requiresManualReview': true,
              }),
            ),
          )
          .toList(),
      supplierDetails: json['supplierDetails'] != null
          ? SupplierDetails.fromJson(json['supplierDetails'])
          : null,
      isOfflineQueued: json['isOfflineQueued'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }

  /// Check if session has unsaved changes
  bool get hasUnsavedChanges =>
      reviewLineItems != null ||
      supplierDetails != null ||
      extractionResult != null;

  /// Get total amount of all valid line items
  double get totalAmount {
    if (reviewLineItems == null) return 0.0;
    return reviewLineItems!
        .where((item) => !item.isDeleted && item.isValid)
        .fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  /// Count of unresolved items (low/none confidence)
  int get unresolvedItemCount {
    if (reviewLineItems == null) return 0;
    return reviewLineItems!
        .where(
          (item) =>
              !item.isDeleted &&
              (item.matchConfidence == 'low' ||
                  item.matchConfidence == 'none' ||
                  item.isNewProduct),
        )
        .length;
  }

  /// Count of valid items ready for submission
  int get validItemCount {
    if (reviewLineItems == null) return 0;
    return reviewLineItems!
        .where((item) => !item.isDeleted && item.isValid)
        .length;
  }
}

/// Notifier for scan bill session
class ScanBillSessionNotifier extends StateNotifier<ScanBillSessionState> {
  final ScanBillApiClient _apiClient;
  final LoggerService _logger;
  final String _verticalType;
  Box<String>? _persistenceBox;
  Timer? _autoSaveTimer;

  ScanBillSessionNotifier({
    required String verticalType,
    ScanBillApiClient? apiClient,
    LoggerService? logger,
  }) : _verticalType = verticalType,
       _apiClient = apiClient ?? sl<ScanBillApiClient>(),
       _logger = logger ?? sl<LoggerService>(),
       super(ScanBillSessionState.initial(verticalType: verticalType)) {
    _initPersistence();
  }

  /// Initialize Hive persistence
  Future<void> _initPersistence() async {
    try {
      _persistenceBox = await Hive.openBox<String>('scan_bill_sessions');

      // Try to restore saved session
      final savedSession = _persistenceBox!.get(_verticalType);
      if (savedSession != null) {
        final json = jsonDecode(savedSession) as Map<String, dynamic>;
        final restoredState = ScanBillSessionState.fromJson(
          json,
          _verticalType,
        );

        // Only restore if session is less than 24 hours old
        final age = DateTime.now().difference(restoredState.createdAt);
        if (age.inHours < 24) {
          _logger.info('ScanBillSessionNotifier: Restored saved session', {
            'rid': restoredState.rid,
            'age': age.inMinutes,
          });
          state = restoredState;
        } else {
          _logger.info('ScanBillSessionNotifier: Discarded old session', {
            'age': age.inHours,
          });
          await clearPersistence();
        }
      }

      // Start auto-save timer
      _startAutoSave();
    } catch (e, stackTrace) {
      _logger.error('ScanBillSessionNotifier: Failed to init persistence', {
        'error': e.toString(),
      }, stackTrace);
    }
  }

  /// Start auto-save timer (saves every 5 seconds if changes)
  void _startAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _saveToPersistence();
    });
  }

  /// Save current state to persistence
  Future<void> _saveToPersistence() async {
    if (_persistenceBox == null || !state.hasUnsavedChanges) return;

    try {
      final json = jsonEncode(state.toJson());
      await _persistenceBox!.put(_verticalType, json);
    } catch (e) {
      _logger.error('ScanBillSessionNotifier: Failed to save session', {
        'error': e.toString(),
      });
    }
  }

  /// Clear persisted session
  Future<void> clearPersistence() async {
    await _persistenceBox?.delete(_verticalType);
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _saveToPersistence(); // Final save
    _persistenceBox?.close();
    super.dispose();
  }

  // ==========================================================================
  // Actions
  // ==========================================================================

  /// Set captured image (single)
  void setImage(File imageFile) {
    state = state.copyWith(
      imageFile: imageFile,
      imageFiles: [imageFile],
      updatedAt: DateTime.now(),
      error: null,
    );
    _saveToPersistence();
  }

  /// Set multiple captured images
  void setImages(List<File> imageFiles) {
    state = state.copyWith(
      imageFile: imageFiles.isNotEmpty ? imageFiles.first : null,
      imageFiles: imageFiles,
      isMultiPage: imageFiles.length > 1,
      updatedAt: DateTime.now(),
      error: null,
    );
    _saveToPersistence();
  }

  /// Extract bill from image(s)
  Future<void> extractBill() async {
    if (state.imageFiles.isEmpty && state.imageFile == null) {
      state = state.copyWith(error: 'No image selected');
      return;
    }

    state = state.copyWith(
      isExtracting: true,
      error: null,
      updatedAt: DateTime.now(),
    );

    try {
      ExtractionResult result;

      // Use multi-image extraction if available
      if (state.imageFiles.length > 1) {
        result = await _apiClient.extractBillMulti(
          imageFiles: state.imageFiles,
          verticalType: state.verticalType,
        );

        // Store multiple S3 keys and URLs
        state = state.copyWith(
          s3ImageKeys: [result.s3ImageKey],
          presignedUrls: [result.presignedUrl],
        );
      } else {
        // Single image
        result = await _apiClient.extractBill(
          imageFile: state.imageFile ?? state.imageFiles.first,
          verticalType: state.verticalType,
        );
      }

      state = state.copyWith(
        isExtracting: false,
        extractionResult: result,
        s3ImageKey: result.s3ImageKey,
        presignedUrl: result.presignedUrl,
        updatedAt: DateTime.now(),
      );

      _logger.info('ScanBillSessionNotifier: Extraction complete', {
        'rid': result.rid,
        'lines': result.parsedLines.length,
        'multiPage': state.imageFiles.length > 1,
      });

      _saveToPersistence();
    } catch (e) {
      _logger.error('ScanBillSessionNotifier: Extraction failed', {
        'error': e.toString(),
      });
      state = state.copyWith(
        isExtracting: false,
        error: e.toString(),
        updatedAt: DateTime.now(),
      );
    }
  }

  /// Match extracted lines to products
  Future<void> matchProducts({String? supplierName}) async {
    if (state.extractionResult == null) {
      state = state.copyWith(error: 'No extraction result available');
      return;
    }

    state = state.copyWith(
      isMatching: true,
      error: null,
      updatedAt: DateTime.now(),
    );

    try {
      final result = await _apiClient.matchProducts(
        rid: state.extractionResult!.rid,
        parsedLines: state.extractionResult!.parsedLines,
        verticalType: state.verticalType,
        supplierName: supplierName,
      );

      // Convert match results to review line items
      final reviewItems = result.matchResults
          .map((match) => ReviewLineItem.fromMatchResult(match))
          .toList();

      state = state.copyWith(
        isMatching: false,
        matchResult: result,
        reviewLineItems: reviewItems,
        updatedAt: DateTime.now(),
      );

      _logger.info('ScanBillSessionNotifier: Matching complete', {
        'matched': result.matchStats,
      });

      _saveToPersistence();
    } catch (e) {
      _logger.error('ScanBillSessionNotifier: Matching failed', {
        'error': e.toString(),
      });
      state = state.copyWith(
        isMatching: false,
        error: e.toString(),
        updatedAt: DateTime.now(),
      );
    }
  }

  /// Update a line item during review
  void updateLineItem(String itemId, ReviewLineItem updatedItem) {
    if (state.reviewLineItems == null) return;

    final updatedList = state.reviewLineItems!.map((item) {
      if (item.id == itemId) {
        return updatedItem;
      }
      return item;
    }).toList();

    state = state.copyWith(
      reviewLineItems: updatedList,
      updatedAt: DateTime.now(),
    );

    _saveToPersistence();
  }

  /// Delete a line item
  void deleteLineItem(String itemId) {
    if (state.reviewLineItems == null) return;

    final updatedList = state.reviewLineItems!.map((item) {
      if (item.id == itemId) {
        return item..isDeleted = true;
      }
      return item;
    }).toList();

    state = state.copyWith(
      reviewLineItems: updatedList,
      updatedAt: DateTime.now(),
    );

    _saveToPersistence();
  }

  /// Toggle selection of a line item
  void toggleItemSelection(String itemId) {
    if (state.reviewLineItems == null) return;

    final updatedList = state.reviewLineItems!.map((item) {
      if (item.id == itemId) {
        return item..isSelected = !item.isSelected;
      }
      return item;
    }).toList();

    state = state.copyWith(
      reviewLineItems: updatedList,
      updatedAt: DateTime.now(),
    );

    _saveToPersistence();
  }

  /// Select all visible items
  void selectAllItems() {
    if (state.reviewLineItems == null) return;

    final updatedList = state.reviewLineItems!.map((item) {
      if (!item.isDeleted) {
        return item..isSelected = true;
      }
      return item;
    }).toList();

    state = state.copyWith(
      reviewLineItems: updatedList,
      updatedAt: DateTime.now(),
    );

    _saveToPersistence();
  }

  /// Deselect all items
  void deselectAllItems() {
    if (state.reviewLineItems == null) return;

    final updatedList = state.reviewLineItems!.map((item) {
      return item..isSelected = false;
    }).toList();

    state = state.copyWith(
      reviewLineItems: updatedList,
      updatedAt: DateTime.now(),
    );

    _saveToPersistence();
  }

  /// Delete selected items
  void deleteSelectedItems() {
    if (state.reviewLineItems == null) return;

    final updatedList = state.reviewLineItems!.map((item) {
      if (item.isSelected) {
        return item
          ..isDeleted = true
          ..isSelected = false;
      }
      return item;
    }).toList();

    state = state.copyWith(
      reviewLineItems: updatedList,
      updatedAt: DateTime.now(),
    );

    _saveToPersistence();
  }

  /// Mark selected items as verified (clear new product flag)
  void markSelectedAsVerified() {
    if (state.reviewLineItems == null) return;

    final updatedList = state.reviewLineItems!.map((item) {
      if (item.isSelected) {
        return item
          ..isNewProduct = false
          ..matchConfidence = 'high'
          ..isSelected = false;
      }
      return item;
    }).toList();

    state = state.copyWith(
      reviewLineItems: updatedList,
      updatedAt: DateTime.now(),
    );

    _saveToPersistence();
  }

  /// Add a new line item manually
  void addLineItem(ReviewLineItem item) {
    final currentList = state.reviewLineItems ?? [];
    state = state.copyWith(
      reviewLineItems: [...currentList, item],
      updatedAt: DateTime.now(),
    );
    _saveToPersistence();
  }

  /// Set supplier details
  void setSupplierDetails(SupplierDetails details) {
    state = state.copyWith(supplierDetails: details, updatedAt: DateTime.now());
    _saveToPersistence();
  }

  /// Submit the purchase entry
  Future<bool> submitEntry() async {
    if (state.reviewLineItems == null || state.s3ImageKey == null) {
      state = state.copyWith(error: 'Missing required data');
      return false;
    }

    if (state.unresolvedItemCount > 0) {
      state = state.copyWith(
        error: 'Please resolve all unmatched items before submitting',
      );
      return false;
    }

    state = state.copyWith(
      isSubmitting: true,
      error: null,
      updatedAt: DateTime.now(),
    );

    try {
      final result = await _apiClient.createEntry(
        rid: state.rid,
        s3ImageKey: state.s3ImageKey!,
        lineItems: state.reviewLineItems!,
        supplierDetails: state.supplierDetails ?? SupplierDetails(),
        totalAmount: state.totalAmount,
        verticalType: state.verticalType,
      );

      _logger.info('ScanBillSessionNotifier: Entry submitted successfully', {
        'rid': state.rid,
      });

      // Clear session after successful submission
      await clearPersistence();

      state = ScanBillSessionState.initial(verticalType: _verticalType);
      return true;
    } catch (e) {
      _logger.error('ScanBillSessionNotifier: Submission failed', {
        'error': e.toString(),
      });

      // Check if it's a network error - queue for offline
      if (e.toString().contains('internet') ||
          e.toString().contains('timeout') ||
          e.toString().contains('connection')) {
        state = state.copyWith(
          isSubmitting: false,
          isOfflineQueued: true,
          error: 'No internet connection. Entry queued for submission.',
          updatedAt: DateTime.now(),
        );
        _saveToPersistence();
        return false;
      }

      state = state.copyWith(
        isSubmitting: false,
        error: e.toString(),
        updatedAt: DateTime.now(),
      );
      return false;
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Reset session
  Future<void> reset() async {
    await clearPersistence();
    state = ScanBillSessionState.initial(verticalType: _verticalType);
  }

  /// Retry offline submission
  Future<bool> retrySubmission() async {
    if (!state.isOfflineQueued) return false;
    return submitEntry();
  }
}

/// Provider factory for scan bill session
final scanBillSessionProvider =
    StateNotifierProvider.family<
      ScanBillSessionNotifier,
      ScanBillSessionState,
      String // verticalType
    >((ref, verticalType) {
      return ScanBillSessionNotifier(verticalType: verticalType);
    });

/// Computed provider for valid items count
final validItemCountProvider = Provider.family<int, String>((
  ref,
  verticalType,
) {
  final state = ref.watch(scanBillSessionProvider(verticalType));
  return state.validItemCount;
});

/// Computed provider for unresolved items count
final unresolvedItemCountProvider = Provider.family<int, String>((
  ref,
  verticalType,
) {
  final state = ref.watch(scanBillSessionProvider(verticalType));
  return state.unresolvedItemCount;
});

/// Computed provider for total amount
final totalAmountProvider = Provider.family<double, String>((
  ref,
  verticalType,
) {
  final state = ref.watch(scanBillSessionProvider(verticalType));
  return state.totalAmount;
});

/// Computed provider for selected items count
final selectedItemCountProvider = Provider.family<int, String>((
  ref,
  verticalType,
) {
  final state = ref.watch(scanBillSessionProvider(verticalType));
  return state.reviewLineItems
          ?.where((i) => !i.isDeleted && i.isSelected)
          .length ??
      0;
});

// ============================================================================
// Offline Queue Status Provider
// ============================================================================

/// Provider for offline queue status
final scanBillQueueStatsProvider = StreamProvider.autoDispose<Map<String, int>>(
  (ref) async* {
    final queue = sl<ScanBillOfflineQueue>();
    await queue.initialize();

    // Initial stats
    yield await queue.getStats();

    // Stream of updates
    await for (final _ in Stream.periodic(const Duration(seconds: 5))) {
      yield await queue.getStats();
    }
  },
);

/// Provider for pending queue count
final scanBillPendingCountProvider = Provider.autoDispose<int>((ref) {
  final statsAsync = ref.watch(scanBillQueueStatsProvider);
  return statsAsync.when(
    data: (stats) => stats['pending'] ?? 0,
    loading: () => 0,
    error: (_, _) => 0,
  );
});
