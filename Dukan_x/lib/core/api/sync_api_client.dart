import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../sync/models/sync_payloads.dart';

class SyncApiClient {
  final String _baseUrl;
  final String _authToken; // In real app, fetch from AuthProvider

  SyncApiClient({String? baseUrl, required String authToken})
    : _baseUrl =
          baseUrl ??
          dotenv.env['API_BASE_URL'] ??
          'http://localhost:8000/api/v1',
      _authToken = authToken;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $_authToken',
  };

  /// Push local changes to server
  Future<void> pushChanges(PushRequest request) async {
    final url = Uri.parse('$_baseUrl/sync/push');

    try {
      final response = await http.post(
        url,
        headers: _headers,
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Sync Push Failed: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Network Error during Push: $e');
    }
  }

  /// Pull remote changes from server
  Future<PullResponse> pullChanges(PullRequest request) async {
    final url = Uri.parse('$_baseUrl/sync/pull');

    try {
      final response = await http.post(
        url,
        headers: _headers,
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return PullResponse.fromJson(data);
      } else {
        throw Exception(
          'Sync Pull Failed: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Network Error during Pull: $e');
    }
  }
}
