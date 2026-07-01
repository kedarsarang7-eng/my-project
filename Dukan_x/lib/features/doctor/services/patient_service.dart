import 'package:uuid/uuid.dart';
import '../../../../core/error/error_handler.dart';
import '../data/repositories/patient_repository.dart';
import '../data/repositories/doctor_repository.dart';
import '../models/patient_model.dart';

class PatientService {
  final PatientRepository _patientRepository;
  final DoctorRepository _doctorRepository;

  PatientService({
    required PatientRepository patientRepository,
    required DoctorRepository doctorRepository,
  }) : _patientRepository = patientRepository,
       _doctorRepository = doctorRepository;

  /// Generate a secure QR Token for a patient if not exists
  Future<String> generateQrToken(String patientId) async {
    try {
      final patient = await _patientRepository.getPatientById(patientId);
      if (patient == null) throw Exception('Patient not found');

      if (patient.qrToken != null && patient.qrToken!.isNotEmpty) {
        return patient.qrToken!;
      }

      // Generate new token
      final token = const Uuid()
          .v4(); // Simple UUID for now, could be signed JWT
      final updated = patient.copyWith(qrToken: token);
      await _patientRepository.updatePatient(updated);
      return token;
    } catch (e, stack) {
      ErrorHandler.handle(
        e,
        stackTrace: stack,
        userMessage: 'Failed to generate QR token',
      );
      rethrow;
    }
  }

  /// Process a scanned QR code to find patient
  /// Returns patient if found and valid
  Future<PatientModel?> scanPatientQr(String qrToken) async {
    try {
      return await _patientRepository.getPatientByQrToken(qrToken);
    } catch (e, stack) {
      ErrorHandler.handle(
        e,
        stackTrace: stack,
        userMessage: 'Failed to scan patient QR',
      );
      rethrow;
    }
  }

  /// Link a patient to a doctor (Create PatientDoctorLink)
  Future<void> linkPatientToDoctor(String patientId, String doctorId) async {
    try {
      // 1. Verify existence
      final patient = await _patientRepository.getPatientById(patientId);
      // Ensure doctor exists. Using getProfile just to verify.
      final doctor = await _doctorRepository.getProfileByVendorId(doctorId);

      if (patient == null) throw Exception('Patient not found');
      if (doctor == null) throw Exception('Doctor profile not found');

      // 2. Create Link
      await _doctorRepository.linkPatient(patientId, doctor.id);
    } catch (e, stack) {
      ErrorHandler.handle(
        e,
        stackTrace: stack,
        userMessage: 'Failed to link patient to doctor',
      );
      rethrow;
    }
  }
}
