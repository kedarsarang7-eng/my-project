// ============================================================================
// ID CARD DESIGNER STATES
// ============================================================================

import 'package:equatable/equatable.dart';
import '../../data/models/staff_profile_model.dart';
import 'id_card_models.dart';

abstract class IDCardDesignerState extends Equatable {
  const IDCardDesignerState();

  @override
  List<Object?> get props => [];
}

/// Initial state
class IDCardDesignerInitial extends IDCardDesignerState {
  const IDCardDesignerInitial();
}

/// Loading state
class IDCardDesignerLoading extends IDCardDesignerState {
  const IDCardDesignerLoading();
}

/// Loaded state with staff and settings
class IDCardDesignerLoaded extends IDCardDesignerState {
  final StaffProfileModel staff;
  final IDCardSettings settings;

  const IDCardDesignerLoaded({
    required this.staff,
    required this.settings,
  });

  IDCardDesignerLoaded copyWith({
    StaffProfileModel? staff,
    IDCardSettings? settings,
  }) {
    return IDCardDesignerLoaded(
      staff: staff ?? this.staff,
      settings: settings ?? this.settings,
    );
  }

  @override
  List<Object?> get props => [staff, settings];
}

/// Print in progress
class IDCardPrintInProgress extends IDCardDesignerState {
  final StaffProfileModel staff;
  final IDCardSettings settings;

  const IDCardPrintInProgress({
    required this.staff,
    required this.settings,
  });

  @override
  List<Object?> get props => [staff, settings];
}

/// Print success
class IDCardPrintSuccess extends IDCardDesignerState {
  final StaffProfileModel staff;
  final IDCardSettings settings;

  const IDCardPrintSuccess({
    required this.staff,
    required this.settings,
  });

  @override
  List<Object?> get props => [staff, settings];
}

/// Export in progress
class IDCardExportInProgress extends IDCardDesignerState {
  final StaffProfileModel staff;
  final IDCardSettings settings;
  final String format;

  const IDCardExportInProgress({
    required this.staff,
    required this.settings,
    required this.format,
  });

  @override
  List<Object?> get props => [staff, settings, format];
}

/// Export success
class IDCardExported extends IDCardDesignerState {
  final StaffProfileModel staff;
  final IDCardSettings settings;
  final String filePath;
  final String format;

  const IDCardExported({
    required this.staff,
    required this.settings,
    required this.filePath,
    required this.format,
  });

  @override
  List<Object?> get props => [staff, settings, filePath, format];
}

/// Email sent
class IDCardEmailed extends IDCardDesignerState {
  final StaffProfileModel staff;
  final IDCardSettings settings;
  final String email;

  const IDCardEmailed({
    required this.staff,
    required this.settings,
    required this.email,
  });

  @override
  List<Object?> get props => [staff, settings, email];
}

/// Batch print in progress
class IDCardBatchPrintInProgress extends IDCardDesignerState {
  final StaffProfileModel staff;
  final IDCardSettings settings;

  const IDCardBatchPrintInProgress({
    required this.staff,
    required this.settings,
  });

  @override
  List<Object?> get props => [staff, settings];
}

/// Batch print success
class IDCardBatchPrintSuccess extends IDCardDesignerState {
  final StaffProfileModel staff;
  final IDCardSettings settings;

  const IDCardBatchPrintSuccess({
    required this.staff,
    required this.settings,
  });

  @override
  List<Object?> get props => [staff, settings];
}

/// Template downloaded
class IDCardTemplateDownloaded extends IDCardDesignerState {
  final StaffProfileModel staff;
  final IDCardSettings settings;

  const IDCardTemplateDownloaded({
    required this.staff,
    required this.settings,
  });

  @override
  List<Object?> get props => [staff, settings];
}

/// Error state
class IDCardError extends IDCardDesignerState {
  final String message;

  const IDCardError({required this.message});

  @override
  List<Object?> get props => [message];
}
