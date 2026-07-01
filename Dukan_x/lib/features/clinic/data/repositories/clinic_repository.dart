import '../../../../core/api/api_client.dart';
import '../models/patient_model.dart';

/// Repository for Clinic Patient Management operations
class ClinicRepository {
  final ApiClient _apiClient;

  ClinicRepository(this._apiClient);

  Future<List<Patient>> getPatients({String? search}) async {
    final params = <String, String>{};
    if (search != null) params['search'] = search;

    final response = await _apiClient.get(
      '/clinic/patients',
      queryParams: params,
    );

    if (response.statusCode == 200) {
      final data = response.data ?? {};
      final items =
          data['items'] ?? data['patients'] ?? (data is List ? data : []);
      return (items as List)
          .map((e) => Patient.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to load patients: ${response.error}');
  }

  Future<void> deletePatient(String id) async {
    final response = await _apiClient.delete('/clinic/patients/$id');
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete patient: ${response.error}');
    }
  }

  Future<void> restorePatient(String id) async {
    final response = await _apiClient.post('/clinic/patients/$id/restore');
    if (response.statusCode != 200) {
      throw Exception('Failed to restore patient: ${response.error}');
    }
  }
}
