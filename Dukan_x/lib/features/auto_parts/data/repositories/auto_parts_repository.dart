import '../../../../core/api/api_client.dart';
import '../models/job_card_model.dart';

/// Repository for Auto Parts module API operations
class AutoPartsRepository {
  final ApiClient _apiClient;

  AutoPartsRepository(this._apiClient);

  Future<List<JobCard>> getJobCards({String? status}) async {
    final params = <String, String>{};
    if (status != null) params['status'] = status;

    final response = await _apiClient.get(
      '/auto-parts/job-cards',
      queryParams: params,
    );

    if (response.statusCode == 200) {
      final data = response.data ?? {};
      final items =
          data['items'] ?? data['jobCards'] ?? (data is List ? data : []);
      return (items as List)
          .map((e) => JobCard.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to load job cards: ${response.error}');
  }

  Future<JobCard> getJobCard(String id) async {
    final response = await _apiClient.get('/auto-parts/job-cards/$id');
    if (response.statusCode == 200) {
      return JobCard.fromJson(response.data ?? {});
    }
    throw Exception('Failed to load job card: ${response.error}');
  }

  Future<JobCard> createJobCard(Map<String, dynamic> data) async {
    final response = await _apiClient.post('/auto-parts/job-cards', body: data);
    if (response.statusCode == 201 || response.statusCode == 200) {
      return JobCard.fromJson(response.data ?? {});
    }
    throw Exception('Failed to create job card: ${response.error}');
  }

  Future<void> updateJobCard(String id, Map<String, dynamic> data) async {
    final response = await _apiClient.put(
      '/auto-parts/job-cards/$id',
      body: data,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update job card: ${response.error}');
    }
  }

  Future<void> updateJobCardStatus(String id, {required String status}) async {
    final response = await _apiClient.patch(
      '/auto-parts/job-cards/$id/status',
      body: {'status': status},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update status: ${response.error}');
    }
  }

  Future<void> deleteJobCard(String id) async {
    final response = await _apiClient.delete('/auto-parts/job-cards/$id');
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete job card: ${response.error}');
    }
  }

  Future<void> restoreJobCard(String id) async {
    final response = await _apiClient.post('/auto-parts/job-cards/$id/restore');
    if (response.statusCode != 200) {
      throw Exception('Failed to restore job card: ${response.error}');
    }
  }
}
