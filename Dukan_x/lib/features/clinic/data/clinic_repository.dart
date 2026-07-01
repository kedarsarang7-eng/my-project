import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/error/failures.dart';

final clinicRepositoryProvider = Provider<ClinicRepository>((ref) {
  return ClinicRepository(apiClient: sl<ApiClient>());
});
class PatientQueueItem {
  final String id;
  final String patientId;
  final String patientName;
  final int tokenNumber;
  final String status; // waiting, in-consultation, completed
  final DateTime checkInTime;

  PatientQueueItem({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.tokenNumber,
    required this.status,
    required this.checkInTime,
  });

  factory PatientQueueItem.fromJson(Map<String, dynamic> json) {
    final appointmentTimeRaw = json['appointmentTime']?.toString();
    DateTime checkIn;
    if (json['checkInTime'] != null) {
      checkIn = DateTime.tryParse(json['checkInTime'].toString()) ?? DateTime.now();
    } else if (appointmentTimeRaw != null && appointmentTimeRaw.isNotEmpty) {
      final today = DateTime.now().toIso8601String().split('T').first;
      checkIn =
          DateTime.tryParse('${today}T$appointmentTimeRaw') ?? DateTime.now();
    } else {
      checkIn = DateTime.now();
    }

    return PatientQueueItem(
      id: (json['id'] ?? '').toString(),
      patientId: (json['patientId'] ?? '').toString(),
      patientName: (json['patientName'] ?? '').toString(),
      tokenNumber: (json['tokenNumber'] as num?)?.toInt() ?? 0,
      status: (json['status'] ?? 'waiting').toString(),
      checkInTime: checkIn,
    );
  }
}

class ClinicRepository {
  final ApiClient apiClient;

  ClinicRepository({required this.apiClient});

  Future<Either<Failure, List<PatientQueueItem>>> getLiveQueue() async {
    try {
      final response = await apiClient.get('/clinic/queue');
      final payload = response.data ?? <String, dynamic>{};
      final rawList = payload['data'] is List
          ? payload['data'] as List
          : (payload['queue'] is List ? payload['queue'] as List : const []);
      final items = rawList
          .map((item) => PatientQueueItem.fromJson(item))
          .toList();
      return Right(items);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, bool>> updateQueueStatus(String queueId, String status) async {
    try {
      await apiClient.put('/clinic/queue/$queueId/status', body: {'status': status});
      return const Right(true);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, bool>> saveConsultation(String patientId, Map<String, dynamic> soapData) async {
    try {
      final subjective = (soapData['subjective'] ?? soapData['subject'] ?? '')
          .toString();
      final objective = (soapData['objective'] ?? '').toString();
      final assessment = (soapData['assessment'] ?? '').toString();
      final plan = (soapData['plan'] ?? '').toString();

      // BUG-C001: Validate required SOAP fields before sending
      final missing = <String>[];
      if (subjective.trim().isEmpty) missing.add('Subjective');
      if (objective.trim().isEmpty) missing.add('Objective');
      if (assessment.trim().isEmpty) missing.add('Assessment');
      if (plan.trim().isEmpty) missing.add('Plan');
      if (missing.isNotEmpty) {
        return Left(InputFailure('Required: ${missing.join(', ')}'));
      }

      await apiClient.post('/clinic/consultation', body: {
        'patientId': patientId,
        'appointmentId': soapData['appointmentId'],
        'subjective': subjective,
        'objective': objective,
        'assessment': assessment,
        'plan': plan,
        'notes': soapData['notes']?.toString(),
        'vitals': {
          'bpParams': soapData['bloodPressure']?.toString() ?? soapData['bpParams']?.toString(),
          'pulse': _toIntOrNull(soapData['pulse']),
          'temperature': _toDoubleOrNull(soapData['temperature']),
          'weight': _toDoubleOrNull(soapData['weight']),
          'spO2': _toIntOrNull(soapData['spO2']),
        },
      });
      return const Right(true);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, List<Map<String, dynamic>>>> getPatientHistory(String patientId) async {
    try {
      final response = await apiClient.get('/clinic/patients/$patientId/history');
      final dynamic payload = response.data;
      final List<dynamic> rawHistory = payload is Map<String, dynamic>
          ? List<dynamic>.from(payload['history'] ?? payload['data'] ?? const [])
          : payload is List
              ? payload
              : const [];

      return Right(rawHistory.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        
        // BUG-032 FIX: Handle orphaned doctor references gracefully
        // If doctor was deleted, doctor field may be null or have null values
        final doctorData = map['doctor'] as Map<String, dynamic>?;
        final doctorName = doctorData?['name'] ?? doctorData?['fullName'] ?? 'Doctor Not Available';
        final doctorId = doctorData?['id'] ?? map['doctorId'] ?? 'unknown';
        
        return {
          'id': map['id'],
          'date': map['recordDate'] ?? map['date'],
          'diagnosis': map['description'] ?? map['diagnosis'],
          'recordType': map['recordType'],
          'referenceId': map['referenceId'],
          'soap': map['soap'],
          'prescriptions': map['prescriptions'],
          // BUG-032: Include sanitized doctor info
          'doctorName': doctorName,
          'doctorId': doctorId,
          'doctorDeleted': doctorData == null,
          ...map,
        };
      }).toList());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, bool>> orderLabTest(String patientId, List<String> testIds) async {
    try {
      await apiClient.post('/clinic/labs/orders', body: {
        'patientId': patientId,
        'tests': testIds
            .where((t) => t.trim().isNotEmpty)
            .map((t) => {'testName': t.trim()})
            .toList(),
        'priority': 'routine',
      });
      return const Right(true);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  // ── Patient CRUD ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getPatientById(String patientId) async {
    try {
      final response = await apiClient.get('/clinic/patients/$patientId');
      final payload = response.data;
      if (payload is Map<String, dynamic>) {
        return payload['data'] is Map<String, dynamic> ? payload['data'] : payload;
      }
      return null;
    } catch (_) { return null; }
  }

  Future<Either<Failure, List<Map<String, dynamic>>>> listPatients({String? search, int limit = 50}) async {
    try {
      final queryParams = <String, String>{'limit': limit.toString()};
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      final response = await apiClient.get('/clinic/patients', queryParams: queryParams);
      final payload = response.data ?? {};
      final rawList = payload['data'] is List ? payload['data'] as List : const [];
      return Right(rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, Map<String, dynamic>>> registerPatient(Map<String, dynamic> data) async {
    try {
      final response = await apiClient.post('/clinic/patients', body: data);
      return Right(Map<String, dynamic>.from(response.data ?? {}));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, bool>> updatePatient(String patientId, Map<String, dynamic> data) async {
    try {
      await apiClient.put('/clinic/patients/$patientId', body: data);
      return const Right(true);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  // ── Appointment CRUD ────────────────────────────────────────────────────

  Future<Either<Failure, Map<String, dynamic>>> createAppointment(Map<String, dynamic> data) async {
    try {
      final response = await apiClient.post('/clinic/appointments', body: data);
      return Right(Map<String, dynamic>.from(response.data ?? {}));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, List<Map<String, dynamic>>>> listAppointments({String? date, String? status}) async {
    try {
      final queryParams = <String, String>{};
      if (date != null) queryParams['date'] = date;
      if (status != null) queryParams['status'] = status;
      final response = await apiClient.get('/clinic/appointments', queryParams: queryParams);
      final payload = response.data ?? {};
      final rawList = payload['data'] is List ? payload['data'] as List : const [];
      return Right(rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, bool>> cancelAppointment(String id) async {
    try {
      await apiClient.delete('/clinic/appointments/$id');
      return const Right(true);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  // ── Doctor Profile ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getDoctorProfile() async {
    try {
      final response = await apiClient.get('/clinic/doctors/me');
      final payload = response.data;
      if (payload is Map<String, dynamic>) {
        return payload['data'] is Map<String, dynamic> ? payload['data'] : payload;
      }
      return null;
    } catch (_) { return null; }
  }

  Future<Either<Failure, bool>> updateDoctorProfile(Map<String, dynamic> data) async {
    try {
      await apiClient.put('/clinic/doctors/me', body: data);
      return const Right(true);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  // ── Dashboard Stats ─────────────────────────────────────────────────────

  Future<Either<Failure, Map<String, dynamic>>> getDashboardStats() async {
    try {
      final response = await apiClient.get('/clinic/dashboard/stats');
      return Right(Map<String, dynamic>.from(response.data ?? {}));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  // ── Billing ─────────────────────────────────────────────────────────────

  Future<Either<Failure, Map<String, dynamic>>> createClinicBill(Map<String, dynamic> data) async {
    try {
      final response = await apiClient.post('/clinic/billing', body: data);
      return Right(Map<String, dynamic>.from(response.data ?? {}));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, Map<String, dynamic>>> getClinicBill(String id) async {
    try {
      final response = await apiClient.get('/clinic/billing/$id');
      return Right(Map<String, dynamic>.from(response.data ?? {}));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  // ── ICD-10 & Drug Search ────────────────────────────────────────────────

  Future<Either<Failure, List<Map<String, dynamic>>>> searchICD10(String query) async {
    try {
      final response = await apiClient.get('/clinic/icd10/search', queryParams: {'query': query});
      final list = (response.data as List?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
      return Right(list);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, List<Map<String, dynamic>>>> searchDrugs(String query) async {
    try {
      final response = await apiClient.get('/clinic/drugs/search', queryParams: {'query': query});
      final list = (response.data as List?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
      return Right(list);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  // ── Refill Queue ────────────────────────────────────────────────────────

  Future<Either<Failure, Map<String, dynamic>>> createRefillRequest(Map<String, dynamic> data) async {
    try {
      final response = await apiClient.post('/clinic/refills', body: data);
      return Right(Map<String, dynamic>.from(response.data ?? {}));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, List<Map<String, dynamic>>>> listRefillRequests({String? status}) async {
    try {
      final params = <String, String>{};
      if (status != null) params['status'] = status;
      final response = await apiClient.get('/clinic/refills', queryParams: params);
      final list = (response.data as List?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
      return Right(list);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  // ── Visit/Prescription CRUD ─────────────────────────────────────────────

  Future<Either<Failure, bool>> updateVisit(String id, Map<String, dynamic> data) async {
    try {
      await apiClient.put('/clinic/visits/$id', body: data);
      return const Right(true);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, bool>> deleteVisit(String id) async {
    try {
      await apiClient.delete('/clinic/visits/$id');
      return const Right(true);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, bool>> updatePrescription(String id, Map<String, dynamic> data) async {
    try {
      await apiClient.put('/clinic/prescriptions/$id', body: data);
      return const Right(true);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, bool>> deletePrescription(String id) async {
    try {
      await apiClient.delete('/clinic/prescriptions/$id');
      return const Right(true);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  // ── SOAP Note Read ──────────────────────────────────────────────────────

  Future<Either<Failure, Map<String, dynamic>>> getSoapNote(String id) async {
    try {
      final response = await apiClient.get('/clinic/soap-notes/$id');
      return Right(Map<String, dynamic>.from(response.data ?? {}));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}

int? _toIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  return int.tryParse(v.toString());
}

double? _toDoubleOrNull(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  return double.tryParse(v.toString());
}
