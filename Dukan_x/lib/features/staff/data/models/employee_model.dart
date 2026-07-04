/// Employee model for Universal Staff Management module.
///
/// Maps to the backend Employee entity (SK: EMP#{id}).
/// PII fields are returned masked by default from the API.
class EmployeeModel {
  final String id;
  final String businessId;
  final String fullName;
  final String? designationId;
  final String? departmentId;
  final String status;
  final String? phone;
  final String? email;
  final String? aadhaarMasked;
  final String? panMasked;
  final String? passportMasked;
  final String? drivingLicenceMasked;
  final String? bankAccountMasked;
  final String? upiMasked;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EmployeeModel({
    required this.id,
    required this.businessId,
    required this.fullName,
    this.designationId,
    this.departmentId,
    this.status = 'active',
    this.phone,
    this.email,
    this.aadhaarMasked,
    this.panMasked,
    this.passportMasked,
    this.drivingLicenceMasked,
    this.bankAccountMasked,
    this.upiMasked,
    this.photoUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    return EmployeeModel(
      id: json['id'] as String? ?? '',
      businessId: json['businessId'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      designationId: json['designationId'] as String?,
      departmentId: json['departmentId'] as String?,
      status: json['status'] as String? ?? 'active',
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      aadhaarMasked: json['aadhaarMasked'] as String?,
      panMasked: json['panMasked'] as String?,
      passportMasked: json['passportMasked'] as String?,
      drivingLicenceMasked: json['drivingLicenceMasked'] as String?,
      bankAccountMasked: json['bankAccountMasked'] as String?,
      upiMasked: json['upiMasked'] as String?,
      photoUrl: json['photoUrl'] as String?,
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'businessId': businessId,
    'fullName': fullName,
    'designationId': designationId,
    'departmentId': departmentId,
    'status': status,
    'phone': phone,
    'email': email,
    'aadhaarMasked': aadhaarMasked,
    'panMasked': panMasked,
    'passportMasked': passportMasked,
    'drivingLicenceMasked': drivingLicenceMasked,
    'bankAccountMasked': bankAccountMasked,
    'upiMasked': upiMasked,
    'photoUrl': photoUrl,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}
