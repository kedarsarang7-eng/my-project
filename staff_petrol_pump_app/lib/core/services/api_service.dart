import 'package:dio/dio.dart';
import '../network/api_client.dart';

class ApiService {
  final ApiClient _apiClient;

  ApiService({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) {
    return _apiClient.get(path, queryParameters: queryParameters);
  }

  Future<Response> post(String path, {dynamic data}) {
    return _apiClient.post(path, data: data);
  }

  Future<Response> put(String path, {dynamic data}) {
    return _apiClient.put(path, data: data);
  }

  Future<Response> patch(String path, {dynamic data}) {
    return _apiClient.patch(path, data: data);
  }

  Future<Response> delete(String path) {
    return _apiClient.delete(path);
  }
}
