// ============================================================================
// Computer Shop — Riverpod Providers
// ============================================================================
// State management for Job Cards, Parts, Warranty, and Multi-Unit
// All providers connect to real backend APIs via ComputerRepository
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:dukanx/core/di/service_locator.dart';
import '../data/repositories/computer_repository.dart';
import '../utils/computer_shop_business_rules.dart';
import '../utils/job_status_codec.dart';
import 'package:dukanx/core/api/api_client.dart';

// ============================================================================
// Repository Provider
// ============================================================================

final computerRepositoryProvider = Provider<ComputerRepository>((ref) {
  final apiClient = sl<ApiClient>();
  return ComputerRepository(apiClient);
});

// ============================================================================
// Job Card List Provider
// ============================================================================

final jobCardListProvider =
    StateNotifierProvider<JobCardListNotifier, JobCardListState>((ref) {
      final repository = ref.watch(computerRepositoryProvider);
      return JobCardListNotifier(repository);
    });

class JobCardListState {
  final List<ComputerJobCard> jobs;
  final bool isLoading;
  final String? error;
  final bool hasMore;
  final int currentPage;
  final ComputerJobStatus? statusFilter;

  const JobCardListState({
    this.jobs = const [],
    this.isLoading = false,
    this.error,
    this.hasMore = true,
    this.currentPage = 1,
    this.statusFilter,
  });

  JobCardListState copyWith({
    List<ComputerJobCard>? jobs,
    bool? isLoading,
    String? error,
    bool? hasMore,
    int? currentPage,
    Object? statusFilter = _sentinel,
  }) {
    return JobCardListState(
      jobs: jobs ?? this.jobs,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      statusFilter: statusFilter == _sentinel
          ? this.statusFilter
          : statusFilter as ComputerJobStatus?,
    );
  }
}

/// Sentinel value for distinguishing "not provided" from `null`.
const Object _sentinel = _Sentinel();

class _Sentinel {
  const _Sentinel();
}

class JobCardListNotifier extends StateNotifier<JobCardListState> {
  final ComputerRepository _repository;

  JobCardListNotifier(this._repository) : super(const JobCardListState()) {
    loadJobs();
  }

  Future<void> loadJobs({bool refresh = false}) async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final page = refresh ? 1 : state.currentPage;
      final response = await _repository.listJobCards(
        status: state.statusFilter,
        page: page,
        limit: 20,
      );

      final jobs = refresh
          ? response.items
          : [...state.jobs, ...response.items];

      state = state.copyWith(
        jobs: jobs,
        isLoading: false,
        hasMore: response.hasMore,
        currentPage: page + 1,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load job cards: $e',
      );
    }
  }

  void setStatusFilter(ComputerJobStatus? status) {
    state = state.copyWith(
      statusFilter: status,
      currentPage: 1,
      jobs: const [],
    );
    loadJobs(refresh: true);
  }

  Future<void> refresh() => loadJobs(refresh: true);
}

// ============================================================================
// Job Search Provider (Req 27 — server-side search)
// ============================================================================

class JobSearchState {
  final bool isLoading;
  final List<ComputerJobCard> results;
  final String? error;

  const JobSearchState({
    this.isLoading = false,
    this.results = const [],
    this.error,
  });

  JobSearchState copyWith({
    bool? isLoading,
    List<ComputerJobCard>? results,
    Object? error = _sentinel,
  }) {
    return JobSearchState(
      isLoading: isLoading ?? this.isLoading,
      results: results ?? this.results,
      error: error == _sentinel ? this.error : error as String?,
    );
  }
}

/// Drives server-side job-card search for `JobCardListScreen` (Req 27).
///
/// Calling [search] with a non-empty query invokes
/// [ComputerRepository.searchJobCards] across the full dataset. On error
/// (including a 10s timeout), the prior [JobSearchState.results] are
/// retained and [JobSearchState.error] is set so the screen can show an
/// error/retry message without losing what was already found (Req 27.4).
class JobSearchNotifier extends StateNotifier<JobSearchState> {
  final ComputerRepository _repository;
  String _lastQuery = '';

  JobSearchNotifier(this._repository) : super(const JobSearchState());

  Future<void> search(String query) async {
    _lastQuery = query;
    if (query.isEmpty) {
      state = const JobSearchState();
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final results = await _repository.searchJobCards(query);
      // Guard against a stale response overwriting a newer query's result.
      if (_lastQuery != query) return;
      state = state.copyWith(isLoading: false, results: results, error: null);
    } on TimeoutException {
      if (_lastQuery != query) return;
      state = state.copyWith(
        isLoading: false,
        error: 'Search timed out. Please try again.',
      );
    } catch (e) {
      if (_lastQuery != query) return;
      state = state.copyWith(isLoading: false, error: 'Search failed: $e');
    }
  }

  /// Clears search state, reverting the screen to the paginated list.
  void clear() {
    _lastQuery = '';
    state = const JobSearchState();
  }
}

final jobSearchProvider =
    StateNotifierProvider<JobSearchNotifier, JobSearchState>((ref) {
      final repository = ref.watch(computerRepositoryProvider);
      return JobSearchNotifier(repository);
    });

// ============================================================================
// Single Job Card Provider (Family)
// ============================================================================

final jobCardDetailProvider =
    StateNotifierProvider.family<
      JobCardDetailNotifier,
      JobCardDetailState,
      String
    >((ref, jobId) {
      final repository = ref.watch(computerRepositoryProvider);
      return JobCardDetailNotifier(repository, jobId);
    });

class JobCardDetailState {
  final ComputerJobCard? job;
  final List<ComputerJobPart> parts;
  final bool isLoading;
  final String? error;

  const JobCardDetailState({
    this.job,
    this.parts = const [],
    this.isLoading = false,
    this.error,
  });

  JobCardDetailState copyWith({
    ComputerJobCard? job,
    List<ComputerJobPart>? parts,
    bool? isLoading,
    String? error,
  }) {
    return JobCardDetailState(
      job: job ?? this.job,
      parts: parts ?? this.parts,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class JobCardDetailNotifier extends StateNotifier<JobCardDetailState> {
  final ComputerRepository _repository;
  final String _jobId;

  JobCardDetailNotifier(this._repository, this._jobId)
    : super(const JobCardDetailState()) {
    loadJob();
  }

  Future<void> loadJob() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final job = await _repository.getJobCard(_jobId);
      final parts = await _repository.getJobParts(_jobId);

      state = state.copyWith(job: job, parts: parts, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load job details: $e',
      );
    }
  }

  Future<void> addPart({
    required String productId,
    required double quantity,
    required double unitPrice,
    String? notes,
  }) async {
    try {
      await _repository.addJobPart(
        _jobId,
        productId: productId,
        quantity: quantity,
        unitPrice: unitPrice,
        notes: notes,
      );
      await loadJob(); // Refresh to show new part
    } catch (e) {
      state = state.copyWith(error: 'Failed to add part: $e');
      rethrow;
    }
  }

  Future<void> assignTechnician(
    String technicianId,
    String technicianName,
  ) async {
    try {
      await _repository.assignTechnician(
        _jobId,
        technicianId: technicianId,
        technicianName: technicianName,
      );
      await loadJob();
    } catch (e) {
      state = state.copyWith(error: 'Failed to assign technician: $e');
      rethrow;
    }
  }

  Future<void> updateLaborCost({
    double? estimatedLaborCost,
    double? actualLaborCost,
    String? diagnosis,
  }) async {
    try {
      await _repository.updateLaborCost(
        _jobId,
        estimatedLaborCost: estimatedLaborCost,
        actualLaborCost: actualLaborCost,
        diagnosis: diagnosis,
      );
      await loadJob();
    } catch (e) {
      state = state.copyWith(error: 'Failed to update labor cost: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> convertToInvoice({
    required String customerName,
    String? customerPhone,
    String paymentMode = 'cash',
    String? notes,
    double discount = 0,
  }) async {
    try {
      final result = await _repository.convertJobToInvoice(
        _jobId,
        customerName: customerName,
        customerPhone: customerPhone,
        paymentMode: paymentMode,
        notes: notes,
        discount: discount,
      );
      await loadJob();
      return result;
    } catch (e) {
      state = state.copyWith(error: 'Failed to convert to invoice: $e');
      rethrow;
    }
  }

  /// Updates the job status after validating the transition.
  ///
  /// Rejects invalid transitions pre-network with a reason message.
  /// Handles a 30s timeout leaving status unchanged.
  Future<void> updateStatus(ComputerJobStatus newStatus) async {
    final currentJob = state.job;
    if (currentJob == null) {
      state = state.copyWith(error: 'Cannot update status: job not loaded');
      return;
    }

    final currentStatus = currentJob.status;

    // Validate transition before any backend call
    if (!ComputerShopBusinessRules.isValidJobTransition(
      currentStatus,
      newStatus,
    )) {
      state = state.copyWith(
        error:
            'Invalid transition from ${JobStatusCodec.label(currentStatus)} '
            'to ${JobStatusCodec.label(newStatus)}',
      );
      return;
    }

    try {
      await _repository
          .updateJobCardStatus(_jobId, newStatus)
          .timeout(const Duration(seconds: 30));
      await loadJob();
    } on TimeoutException {
      state = state.copyWith(error: 'Status change did not complete');
    } catch (e) {
      state = state.copyWith(error: 'Failed to update status: $e');
    }
  }
}

// ============================================================================
// Warranty Provider
// ============================================================================

final warrantyProvider = StateNotifierProvider<WarrantyNotifier, WarrantyState>(
  (ref) {
    final repository = ref.watch(computerRepositoryProvider);
    return WarrantyNotifier(repository);
  },
);

class WarrantyState {
  final ComputerWarranty? warranty;
  final bool isLoading;
  final String? error;
  final bool isSearching;

  const WarrantyState({
    this.warranty,
    this.isLoading = false,
    this.error,
    this.isSearching = false,
  });

  WarrantyState copyWith({
    ComputerWarranty? warranty,
    bool? isLoading,
    String? error,
    bool? isSearching,
  }) {
    return WarrantyState(
      warranty: warranty,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isSearching: isSearching ?? this.isSearching,
    );
  }
}

class WarrantyNotifier extends StateNotifier<WarrantyState> {
  final ComputerRepository _repository;

  WarrantyNotifier(this._repository) : super(const WarrantyState());

  Future<void> lookupWarranty(String serialNumber) async {
    state = state.copyWith(isLoading: true, error: null, warranty: null);

    try {
      final warranty = await _repository.getWarranty(
        serialNumber: serialNumber,
      );
      state = state.copyWith(warranty: warranty, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Warranty not found for serial: $serialNumber',
      );
    }
  }

  Future<void> registerWarranty({
    required String serialNumber,
    required String productId,
    required int warrantyPeriodMonths,
    required String purchaseDate,
    required String invoiceId,
    String? customerId,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final warranty = await _repository.registerWarranty(
        serialNumber: serialNumber,
        productId: productId,
        warrantyPeriodMonths: warrantyPeriodMonths,
        purchaseDate: purchaseDate,
        invoiceId: invoiceId,
        customerId: customerId,
      );
      state = state.copyWith(warranty: warranty, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to register warranty: $e',
      );
      rethrow;
    }
  }

  void clear() {
    state = const WarrantyState();
  }
}

// ============================================================================
// Serial History Provider
// ============================================================================

final serialHistoryProvider =
    FutureProvider.family<ComputerSerialHistory, String>((
      ref,
      serialNumber,
    ) async {
      final repository = ref.watch(computerRepositoryProvider);
      return await repository.getSerialHistory(serialNumber);
    });

// ============================================================================
// Multi-Unit Provider
// ============================================================================

final multiUnitConfigProvider =
    StateNotifierProvider<MultiUnitNotifier, MultiUnitState>((ref) {
      final repository = ref.watch(computerRepositoryProvider);
      return MultiUnitNotifier(repository);
    });

class MultiUnitState {
  final bool isLoading;
  final String? error;
  final UnitConversionResult? lastConversion;

  const MultiUnitState({
    this.isLoading = false,
    this.error,
    this.lastConversion,
  });

  MultiUnitState copyWith({
    bool? isLoading,
    String? error,
    UnitConversionResult? lastConversion,
  }) {
    return MultiUnitState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastConversion: lastConversion ?? this.lastConversion,
    );
  }
}

class MultiUnitNotifier extends StateNotifier<MultiUnitState> {
  final ComputerRepository _repository;

  MultiUnitNotifier(this._repository) : super(const MultiUnitState());

  Future<void> configureMultiUnit(MultiUnitConfig config) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _repository.setMultiUnitConversion(config);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to configure multi-unit: $e',
      );
      rethrow;
    }
  }

  Future<void> convertUnit({
    required String productId,
    required String fromUnit,
    required String toUnit,
    required double quantity,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _repository.convertStockUnit(
        productId: productId,
        fromUnit: fromUnit,
        toUnit: toUnit,
        quantity: quantity,
      );
      state = state.copyWith(isLoading: false, lastConversion: result);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to convert unit: $e',
      );
      rethrow;
    }
  }
}

// ============================================================================
// Create Job Card Form State
// ============================================================================

final createJobCardFormProvider =
    StateNotifierProvider<CreateJobCardNotifier, CreateJobCardState>((ref) {
      final repository = ref.watch(computerRepositoryProvider);
      return CreateJobCardNotifier(repository);
    });

class CreateJobCardState {
  final bool isLoading;
  final String? error;
  final bool isSuccess;
  final String? createdJobId;

  const CreateJobCardState({
    this.isLoading = false,
    this.error,
    this.isSuccess = false,
    this.createdJobId,
  });

  CreateJobCardState copyWith({
    bool? isLoading,
    String? error,
    bool? isSuccess,
    String? createdJobId,
  }) {
    return CreateJobCardState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isSuccess: isSuccess ?? this.isSuccess,
      createdJobId: createdJobId ?? this.createdJobId,
    );
  }
}

class CreateJobCardNotifier extends StateNotifier<CreateJobCardState> {
  final ComputerRepository _repository;

  CreateJobCardNotifier(this._repository) : super(const CreateJobCardState());

  Future<void> createJobCard(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, error: null, isSuccess: false);

    try {
      final job = await _repository.createJobCard(data);
      state = state.copyWith(
        isLoading: false,
        isSuccess: true,
        createdJobId: job.id,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to create job card: $e',
      );
      rethrow;
    }
  }

  void reset() {
    state = const CreateJobCardState();
  }
}

// ============================================================================
// Status Filter Options
// ============================================================================

/// Status filter options derived from the canonical [ComputerJobStatus] enum.
/// Wire strings are never exposed here — labels come from [JobStatusCodec].
final jobStatusOptionsProvider = Provider<List<Map<String, dynamic>>>(
  (ref) => [
    {'value': null, 'label': 'All Statuses', 'color': Colors.grey},
    {
      'value': ComputerJobStatus.intake,
      'label': JobStatusCodec.label(ComputerJobStatus.intake),
      'color': Colors.orange,
    },
    {
      'value': ComputerJobStatus.diagnosis,
      'label': JobStatusCodec.label(ComputerJobStatus.diagnosis),
      'color': Colors.amber,
    },
    {
      'value': ComputerJobStatus.partsOrdered,
      'label': JobStatusCodec.label(ComputerJobStatus.partsOrdered),
      'color': Colors.deepOrange,
    },
    {
      'value': ComputerJobStatus.underRepair,
      'label': JobStatusCodec.label(ComputerJobStatus.underRepair),
      'color': Colors.blue,
    },
    {
      'value': ComputerJobStatus.qa,
      'label': JobStatusCodec.label(ComputerJobStatus.qa),
      'color': Colors.purple,
    },
    {
      'value': ComputerJobStatus.ready,
      'label': JobStatusCodec.label(ComputerJobStatus.ready),
      'color': Colors.teal,
    },
    {
      'value': ComputerJobStatus.delivered,
      'label': JobStatusCodec.label(ComputerJobStatus.delivered),
      'color': Colors.green,
    },
    {
      'value': ComputerJobStatus.cancelled,
      'label': JobStatusCodec.label(ComputerJobStatus.cancelled),
      'color': Colors.red,
    },
  ],
);

// ============================================================================
// Valid Status Transitions
// ============================================================================

/// Returns the list of valid next statuses for a given [current] status,
/// computed from [ComputerShopBusinessRules.isValidJobTransition].
///
/// Used by the UI to populate the status-change control with only valid
/// options. When the returned list is empty, the control should be disabled.
List<ComputerJobStatus> getValidTransitions(ComputerJobStatus current) {
  return ComputerJobStatus.values
      .where(
        (next) => ComputerShopBusinessRules.isValidJobTransition(current, next),
      )
      .toList();
}

/// Provider that returns valid next statuses for a given current status.
/// Pass the current job status and get back the list of valid transitions.
final validStatusTransitionsProvider =
    Provider.family<List<ComputerJobStatus>, ComputerJobStatus>(
      (ref, currentStatus) => getValidTransitions(currentStatus),
    );

// ============================================================================
// RMA (Return Merchandise Authorization) Provider
// ============================================================================

/// RMA statuses as defined by the backend.
enum RmaStatus {
  initiated,
  shippedToOem,
  replacementReceived,
  rejectedByOem,
  resolved,
}

/// Wire strings for RMA statuses.
class RmaStatusCodec {
  static const _wireMap = {
    RmaStatus.initiated: 'INITIATED',
    RmaStatus.shippedToOem: 'SHIPPED_TO_OEM',
    RmaStatus.replacementReceived: 'REPLACEMENT_RECEIVED',
    RmaStatus.rejectedByOem: 'REJECTED_BY_OEM',
    RmaStatus.resolved: 'RESOLVED',
  };

  static String toWire(RmaStatus status) => _wireMap[status]!;

  static String label(RmaStatus status) {
    switch (status) {
      case RmaStatus.initiated:
        return 'Initiated';
      case RmaStatus.shippedToOem:
        return 'Shipped to OEM';
      case RmaStatus.replacementReceived:
        return 'Replacement Received';
      case RmaStatus.rejectedByOem:
        return 'Rejected by OEM';
      case RmaStatus.resolved:
        return 'Resolved';
    }
  }
}

class RmaState {
  final bool isLoading;
  final String? error;
  final String? createdRmaId;
  final bool statusUpdateSuccess;

  const RmaState({
    this.isLoading = false,
    this.error,
    this.createdRmaId,
    this.statusUpdateSuccess = false,
  });

  RmaState copyWith({
    bool? isLoading,
    String? error,
    String? createdRmaId,
    bool? statusUpdateSuccess,
  }) {
    return RmaState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      createdRmaId: createdRmaId ?? this.createdRmaId,
      statusUpdateSuccess: statusUpdateSuccess ?? this.statusUpdateSuccess,
    );
  }
}

class RmaNotifier extends StateNotifier<RmaState> {
  final ComputerRepository _repository;

  RmaNotifier(this._repository) : super(const RmaState());

  /// Creates an RMA. Returns the created RMA id on success.
  /// On error, sets state.error and leaves prior data unchanged.
  Future<void> createRma({
    required String componentSerialId,
    required String brand,
    required String reason,
    String? oemRmaNumber,
  }) async {
    state = state.copyWith(
      isLoading: true,
      error: null,
      statusUpdateSuccess: false,
    );
    try {
      final rmaId = await _repository.createRma(
        componentSerialId: componentSerialId,
        brand: brand,
        reason: reason,
        oemRmaNumber: oemRmaNumber,
      );
      state = state.copyWith(isLoading: false, createdRmaId: rmaId);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Updates an existing RMA's status.
  /// On error, sets state.error and leaves prior data unchanged.
  Future<void> updateRmaStatus(String rmaId, RmaStatus status) async {
    state = state.copyWith(
      isLoading: true,
      error: null,
      statusUpdateSuccess: false,
    );
    try {
      await _repository.updateRmaStatus(rmaId, RmaStatusCodec.toWire(status));
      state = state.copyWith(isLoading: false, statusUpdateSuccess: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Clears any error state.
  void clearError() {
    state = state.copyWith(error: null);
  }
}

final rmaProvider = StateNotifierProvider<RmaNotifier, RmaState>((ref) {
  final repository = ref.watch(computerRepositoryProvider);
  return RmaNotifier(repository);
});

// ============================================================================
// Custom Build / BOM Checkout Provider (Req 10)
// ============================================================================

class BuildCheckoutState {
  final bool isLoading;
  final String? error;
  final bool success;
  final String? unitReference;

  const BuildCheckoutState({
    this.isLoading = false,
    this.error,
    this.success = false,
    this.unitReference,
  });

  BuildCheckoutState copyWith({
    bool? isLoading,
    String? error,
    bool? success,
    String? unitReference,
  }) {
    return BuildCheckoutState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      success: success ?? this.success,
      unitReference: unitReference ?? this.unitReference,
    );
  }
}

class BuildCheckoutNotifier extends StateNotifier<BuildCheckoutState> {
  final ComputerRepository _repository;

  BuildCheckoutNotifier(this._repository) : super(const BuildCheckoutState());

  /// Checks out a PC build. On success, [BuildCheckoutState.unitReference]
  /// holds the unit reference returned by the backend, falling back to the
  /// invoice reference when the backend response carries none (Req 10.5).
  /// On error, sets state.error and leaves prior data unchanged (Req 10.6).
  Future<void> checkout({
    required List<Map<String, dynamic>> components,
    String? customerId,
    required String invoiceId,
  }) async {
    state = state.copyWith(isLoading: true, error: null, success: false);
    try {
      final unitRef = await _repository.checkoutBuild(
        components: components,
        customerId: customerId,
        invoiceId: invoiceId,
      );
      state = state.copyWith(
        isLoading: false,
        success: true,
        unitReference: unitRef ?? invoiceId,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Clears any error state without discarding the BOM/invoice held by the
  /// caller (that data lives in the screen's own state, not here).
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Resets to the initial state (used after starting a new build).
  void reset() {
    state = const BuildCheckoutState();
  }
}

final buildCheckoutProvider =
    StateNotifierProvider<BuildCheckoutNotifier, BuildCheckoutState>((ref) {
      final repository = ref.watch(computerRepositoryProvider);
      return BuildCheckoutNotifier(repository);
    });

// ============================================================================
// Bulk Serial Intake Provider (Req 12)
// ============================================================================

class BulkSerialIntakeState {
  final bool isLoading;
  final String? error;
  final BulkSerialIntakeResult? result;

  const BulkSerialIntakeState({
    this.isLoading = false,
    this.error,
    this.result,
  });

  BulkSerialIntakeState copyWith({
    bool? isLoading,
    String? error,
    BulkSerialIntakeResult? result,
  }) {
    return BulkSerialIntakeState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      result: result ?? this.result,
    );
  }
}

class BulkSerialIntakeNotifier extends StateNotifier<BulkSerialIntakeState> {
  final ComputerRepository _repository;

  BulkSerialIntakeNotifier(this._repository)
    : super(const BulkSerialIntakeState());

  /// Submits [serials] for bulk intake against [productId].
  ///
  /// Callers must have already enforced the 1-500 bound and filtered out
  /// format-invalid/intra-submission-duplicate serials (Req 12.1, 12.2);
  /// [clientRejected] carries those client-side rejections so they can be
  /// merged into the displayed report alongside any backend rejections.
  ///
  /// On failure, sets state.error and does not mark anything as persisted
  /// (Req 12.5).
  Future<void> submit({
    required String productId,
    required List<String> serials,
    List<BulkSerialRejection> clientRejected = const [],
  }) async {
    state = state.copyWith(isLoading: true, error: null, result: null);
    try {
      final result = await _repository.bulkIntakeSerials(
        productId: productId,
        serials: serials,
      );
      state = state.copyWith(
        isLoading: false,
        result: BulkSerialIntakeResult(
          accepted: result.accepted,
          rejected: [...clientRejected, ...result.rejected],
        ),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Resets to the initial state (used after starting a new submission).
  void reset() {
    state = const BulkSerialIntakeState();
  }
}

final bulkSerialIntakeProvider =
    StateNotifierProvider<BulkSerialIntakeNotifier, BulkSerialIntakeState>((
      ref,
    ) {
      final repository = ref.watch(computerRepositoryProvider);
      return BulkSerialIntakeNotifier(repository);
    });
