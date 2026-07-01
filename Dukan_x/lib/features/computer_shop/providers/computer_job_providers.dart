// ============================================================================
// Computer Shop — Riverpod Providers
// ============================================================================
// State management for Job Cards, Parts, Warranty, and Multi-Unit
// All providers connect to real backend APIs via ComputerRepository
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:dukanx/core/di/service_locator.dart';
import '../data/repositories/computer_repository.dart';
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
  final String? statusFilter;

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
    String? statusFilter,
  }) {
    return JobCardListState(
      jobs: jobs ?? this.jobs,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      statusFilter: statusFilter ?? this.statusFilter,
    );
  }
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

  void setStatusFilter(String? status) {
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
    double discountCents = 0,
  }) async {
    try {
      final result = await _repository.convertJobToInvoice(
        _jobId,
        customerName: customerName,
        customerPhone: customerPhone,
        paymentMode: paymentMode,
        notes: notes,
        discountCents: discountCents,
      );
      await loadJob();
      return result;
    } catch (e) {
      state = state.copyWith(error: 'Failed to convert to invoice: $e');
      rethrow;
    }
  }

  Future<void> updateStatus(String status) async {
    try {
      await _repository.updateJobCardStatus(_jobId, status);
      await loadJob();
    } catch (e) {
      state = state.copyWith(error: 'Failed to update status: $e');
      rethrow;
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

final jobStatusOptionsProvider = Provider<List<Map<String, dynamic>>>(
  (ref) => [
    {'value': null, 'label': 'All Statuses', 'color': Colors.grey},
    {'value': 'INTAKE', 'label': 'Intake', 'color': Colors.orange},
    {'value': 'DIAGNOSIS', 'label': 'Diagnosis', 'color': Colors.amber},
    {
      'value': 'AWAITING_PARTS',
      'label': 'Awaiting Parts',
      'color': Colors.deepOrange,
    },
    {'value': 'REPAIRING', 'label': 'Repairing', 'color': Colors.blue},
    {'value': 'QC', 'label': 'QC', 'color': Colors.purple},
    {'value': 'DELIVERED', 'label': 'Delivered', 'color': Colors.green},
  ],
);
