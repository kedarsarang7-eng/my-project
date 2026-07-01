import '../../../core/api/api_client.dart';
import '../../../core/di/service_locator.dart';

/// Represents a patient in the pharmacy registry.
class PatientRecord {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? address;
  final DateTime? dateOfBirth;
  final String? bloodGroup;
  final String? allergies;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PatientRecord({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.address,
    this.dateOfBirth,
    this.bloodGroup,
    this.allergies,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PatientRecord.fromJson(Map<String, dynamic> j) => PatientRecord(
        id: j['id'] as String,
        name: j['name'] as String,
        phone: j['phone'] as String,
        email: j['email'] as String?,
        address: j['address'] as String?,
        dateOfBirth: j['dateOfBirth'] != null
            ? DateTime.tryParse(j['dateOfBirth'] as String)
            : null,
        bloodGroup: j['bloodGroup'] as String?,
        allergies: j['allergies'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        if (email != null) 'email': email,
        if (address != null) 'address': address,
        if (dateOfBirth != null) 'dateOfBirth': dateOfBirth!.toIso8601String(),
        if (bloodGroup != null) 'bloodGroup': bloodGroup,
        if (allergies != null) 'allergies': allergies,
      };
}

/// A purchase history entry for a patient.
class PatientPurchaseRecord {
  final String invoiceId;
  final String invoiceNumber;
  final DateTime date;
  final double grandTotal;
  final List<String> productNames;

  const PatientPurchaseRecord({
    required this.invoiceId,
    required this.invoiceNumber,
    required this.date,
    required this.grandTotal,
    required this.productNames,
  });

  factory PatientPurchaseRecord.fromJson(Map<String, dynamic> j) =>
      PatientPurchaseRecord(
        invoiceId: j['invoiceId'] as String,
        invoiceNumber: j['invoiceNumber'] as String,
        date: DateTime.parse(j['date'] as String),
        grandTotal: (j['grandTotal'] as num).toDouble(),
        productNames: (j['productNames'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList(),
      );
}

/// Service for managing the pharmacy Patient Registry.
class PatientRegistryService {
  final ApiClient _api;

  PatientRegistryService() : _api = sl<ApiClient>();

  /// List patients with optional search query and pagination.
  Future<List<PatientRecord>> listPatients({
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'limit': '$limit',
      if (search != null && search.isNotEmpty) 'search': search,
    };
    final res = await _api.get('/pharmacy/patients', queryParams: params);
    if (!res.isSuccess || res.data == null) return [];
    final items = res.data!['items'] as List<dynamic>? ?? [];
    return items
        .map((e) => PatientRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Get a single patient by ID.
  Future<PatientRecord?> getPatient(String patientId) async {
    final res = await _api.get('/pharmacy/patients/$patientId');
    if (!res.isSuccess || res.data == null) return null;
    return PatientRecord.fromJson(res.data!);
  }

  /// Create a new patient record.
  Future<PatientRecord?> createPatient(PatientRecord patient) async {
    final res = await _api.post('/pharmacy/patients', body: patient.toJson());
    if (!res.isSuccess || res.data == null) return null;
    return PatientRecord.fromJson(res.data!);
  }

  /// Update an existing patient record.
  Future<PatientRecord?> updatePatient(
      String patientId, PatientRecord patient) async {
    final res = await _api.put(
      '/pharmacy/patients/$patientId',
      body: patient.toJson(),
    );
    if (!res.isSuccess || res.data == null) return null;
    return PatientRecord.fromJson(res.data!);
  }

  /// Fetch purchase history for a patient.
  Future<List<PatientPurchaseRecord>> getPurchaseHistory(
    String patientId, {
    int limit = 50,
  }) async {
    final res = await _api.get(
      '/pharmacy/patients/$patientId/purchases',
      queryParams: {'limit': '$limit'},
    );
    if (!res.isSuccess || res.data == null) return [];
    final items = res.data!['items'] as List<dynamic>? ?? [];
    return items
        .map((e) => PatientPurchaseRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
