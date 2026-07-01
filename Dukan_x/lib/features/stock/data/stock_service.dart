import 'dart:convert';
import 'dart:io';
import 'package:dukanx/core/compat/firebase_auth_compat.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; // For MediaType
import '../../../../config/api_config.dart';

class StockService {
  Future<String?> _getToken() async {
    return await FirebaseAuth.instance.currentUser?.getIdToken();
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  Future<String> _getOwnerId() async {
    return FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  Future<Map<String, dynamic>> lookupBarcode(String barcode) async {
    final ownerId = await _getOwnerId();
    if (ownerId.isEmpty) {
      throw Exception("User not logged in");
    }

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/stock/lookup-barcode'),
      headers: await _getHeaders(),
      body: jsonEncode({"owner_uid": ownerId, "barcode": barcode}),
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body['data']; // {found: bool, source: ..., data: ...}
    } else {
      throw Exception('Failed to lookup barcode: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> analyzeImage(File imageFile) async {
    final ownerId = await _getOwnerId();
    if (ownerId.isEmpty) {
      throw Exception("User not logged in");
    }

    // Multipart request
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/stock/analyze-image'),
    );

    final token = await _getToken();
    request.headers['Authorization'] = 'Bearer $token';

    request.fields['owner_uid'] = ownerId;
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
        contentType: MediaType('image', 'jpeg'), // assist parsing
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body['data']; // {name, category, ...}
    } else {
      throw Exception('Image analysis failed: ${response.statusCode}');
    }
  }

  Future<void> addStock(Map<String, dynamic> itemData) async {
    final ownerId = await _getOwnerId();
    if (ownerId.isEmpty) {
      throw Exception("User not logged in");
    }

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/stock/add'),
      headers: await _getHeaders(),
      body: jsonEncode({"owner_uid": ownerId, "item_data": itemData}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to add stock: ${response.body}');
    }
  }
}
