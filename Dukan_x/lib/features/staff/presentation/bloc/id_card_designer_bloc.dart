// ============================================================================
// ID CARD DESIGNER BLoC - State Management for ID Card Creation
// ============================================================================

import 'dart:io';
import 'dart:ui';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:printing/printing.dart';
import 'id_card_designer_event.dart';
import 'id_card_designer_state.dart';
import 'id_card_models.dart';
import '../../services/staff_attendance_service.dart';

/// BLoC for managing ID card designer state
/// 
/// Handles:
/// - Loading staff data for ID card
/// - Template selection and customization
/// - Photo upload/capture
/// - Export to PDF/PNG
/// - Print functionality
class IDCardDesignerBloc extends Bloc<IDCardDesignerEvent, IDCardDesignerState> {
  final StaffAttendanceService _attendanceService;

  IDCardDesignerBloc({required StaffAttendanceService attendanceService})
      : _attendanceService = attendanceService,
        super(const IDCardDesignerInitial()) {
    on<LoadStaffForIDCard>(_onLoadStaffForIDCard);
    on<UpdateSettings>(_onUpdateSettings);
    on<UpdatePhoto>(_onUpdatePhoto);
    on<PrintIDCard>(_onPrintIDCard);
    on<ExportIDCard>(_onExportIDCard);
    on<EmailIDCard>(_onEmailIDCard);
    on<PrintAllCards>(_onPrintAllCards);
    on<DownloadTemplate>(_onDownloadTemplate);
  }

  Future<void> _onLoadStaffForIDCard(
    LoadStaffForIDCard event,
    Emitter<IDCardDesignerState> emit,
  ) async {
    emit(const IDCardDesignerLoading());

    try {
      final staff = await _attendanceService.getStaffById(event.staffId);
      
      emit(IDCardDesignerLoaded(
        staff: staff,
        settings: IDCardSettings(
          primaryColor: _getColorForRole(staff.role.jsonValue),
        ),
      ));
    } catch (e) {
      emit(IDCardError(message: 'Failed to load staff: ${e.toString()}'));
    }
  }

  Future<void> _onUpdateSettings(
    UpdateSettings event,
    Emitter<IDCardDesignerState> emit,
  ) async {
    final currentState = state;
    if (currentState is IDCardDesignerLoaded) {
      emit(currentState.copyWith(settings: event.settings));
    }
  }

  Future<void> _onUpdatePhoto(
    UpdatePhoto event,
    Emitter<IDCardDesignerState> emit,
  ) async {
    final currentState = state;
    if (currentState is IDCardDesignerLoaded) {
      emit(currentState.copyWith(
        settings: currentState.settings.copyWith(
          photoPath: event.photoPath,
          photoMode: PhotoMode.upload,
        ),
      ));
    }
  }

  Future<void> _onPrintIDCard(
    PrintIDCard event,
    Emitter<IDCardDesignerState> emit,
  ) async {
    final currentState = state;
    if (currentState is IDCardDesignerLoaded) {
      emit(IDCardPrintInProgress(
        staff: currentState.staff,
        settings: currentState.settings,
      ));

      try {
        final result = await _attendanceService.exportIDCard(
          staffId: currentState.staff.staffId,
          settings: currentState.settings,
          format: 'pdf',
        );

        final filePath = result['filePath'] as String?;
        if (filePath != null) {
          final bytes = await File(filePath).readAsBytes();
          await Printing.layoutPdf(onLayout: (_) => bytes);
        }

        emit(IDCardPrintSuccess(
          staff: currentState.staff,
          settings: currentState.settings,
        ));
        emit(currentState);
      } catch (e) {
        emit(IDCardError(message: 'Print failed: ${e.toString()}'));
        emit(currentState);
      }
    }
  }

  Future<void> _onExportIDCard(
    ExportIDCard event,
    Emitter<IDCardDesignerState> emit,
  ) async {
    final currentState = state;
    if (currentState is IDCardDesignerLoaded) {
      emit(IDCardExportInProgress(
        staff: currentState.staff,
        settings: currentState.settings,
        format: event.format,
      ));

      try {
        final result = await _attendanceService.exportIDCard(
          staffId: currentState.staff.staffId,
          settings: currentState.settings,
          format: event.format,
          filePath: event.filePath,
        );

        emit(IDCardExported(
          staff: currentState.staff,
          settings: currentState.settings,
          filePath: result['filePath'] as String,
          format: event.format,
        ));
        
        emit(currentState);
      } catch (e) {
        emit(IDCardError(message: 'Export failed: ${e.toString()}'));
        emit(currentState);
      }
    }
  }

  Future<void> _onEmailIDCard(
    EmailIDCard event,
    Emitter<IDCardDesignerState> emit,
  ) async {
    final currentState = state;
    if (currentState is IDCardDesignerLoaded) {
      try {
        await _attendanceService.emailIDCard(
          staffId: currentState.staff.staffId,
          settings: currentState.settings,
          email: currentState.staff.email,
        );

        emit(IDCardEmailed(
          staff: currentState.staff,
          settings: currentState.settings,
          email: currentState.staff.email ?? '',
        ));
        
        emit(currentState);
      } catch (e) {
        emit(IDCardError(message: 'Email failed: ${e.toString()}'));
        emit(currentState);
      }
    }
  }

  Future<void> _onPrintAllCards(
    PrintAllCards event,
    Emitter<IDCardDesignerState> emit,
  ) async {
    final currentState = state;
    if (currentState is IDCardDesignerLoaded) {
      emit(IDCardBatchPrintInProgress(
        staff: currentState.staff,
        settings: currentState.settings,
      ));

      try {
        await _attendanceService.printAllCards(
          pumpStationId: currentState.staff.petrolPumpId,
        );

        emit(IDCardBatchPrintSuccess(
          staff: currentState.staff,
          settings: currentState.settings,
        ));
        
        emit(currentState);
      } catch (e) {
        emit(IDCardError(message: 'Batch print failed: ${e.toString()}'));
        emit(currentState);
      }
    }
  }

  Future<void> _onDownloadTemplate(
    DownloadTemplate event,
    Emitter<IDCardDesignerState> emit,
  ) async {
    final currentState = state;
    if (currentState is IDCardDesignerLoaded) {
      try {
        await _attendanceService.downloadIDCardTemplate(
          template: currentState.settings.template,
        );

        emit(IDCardTemplateDownloaded(
          staff: currentState.staff,
          settings: currentState.settings,
        ));
        
        emit(currentState);
      } catch (e) {
        emit(IDCardError(message: 'Download failed: ${e.toString()}'));
        emit(currentState);
      }
    }
  }

  Color _getColorForRole(String role) {
    switch (role.toLowerCase()) {
      case 'manager':
        return const Color(0xFF1565C0); // Blue
      case 'supervisor':
        return const Color(0xFF6A1B9A); // Purple
      case 'cashier':
        return const Color(0xFF2E7D32); // Green
      case 'pump_operator':
        return const Color(0xFFEF6C00); // Orange
      default:
        return const Color(0xFF1E3A5F); // Navy
    }
  }
}
