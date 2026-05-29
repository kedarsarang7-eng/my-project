import '../../../core/network/api_client.dart';

/// Staff member model
class StaffMember {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String status;
  final DateTime createdAt;
  final DateTime? lastActiveAt;
  final int transactionsCount;
  final double totalRevenue;
  final String? avatarUrl;

  StaffMember({
    required this.id,
    required this.name,
    required this.email,
    this.phone = '',
    this.role = 'staff',
    this.status = 'active',
    required this.createdAt,
    this.lastActiveAt,
    this.transactionsCount = 0,
    this.totalRevenue = 0,
    this.avatarUrl,
  });

  factory StaffMember.fromJson(Map<String, dynamic> json) {
    return StaffMember(
      id: json['id'] ?? json['userId'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      role: json['role'] ?? 'staff',
      status: json['status'] ?? 'active',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      lastActiveAt: json['lastActiveAt'] != null
          ? DateTime.tryParse(json['lastActiveAt'])
          : null,
      transactionsCount: (json['transactionsCount'] ?? 0).toInt(),
      totalRevenue: (json['totalRevenue'] ?? 0).toDouble(),
      avatarUrl: json['avatarUrl'],
    );
  }

  bool get isActive => status == 'active';
  bool get isOwner => role == 'owner' || role == 'admin';
  String get displayRole => role.substring(0, 1).toUpperCase() + role.substring(1);
}

/// Staff invitation request
class StaffInvitation {
  final String email;
  final String name;
  final String role;
  final String? phone;

  StaffInvitation({
    required this.email,
    required this.name,
    this.role = 'staff',
    this.phone,
  });

  Map<String, dynamic> toJson() => {
    'email': email,
    'name': name,
    'role': role,
    if (phone != null) 'phone': phone,
  };
}

/// Staff invitation response
class StaffInvitationResponse {
  final String invitationId;
  final String email;
  final String status;
  final String? temporaryPassword;
  final DateTime expiresAt;

  StaffInvitationResponse({
    required this.invitationId,
    required this.email,
    required this.status,
    this.temporaryPassword,
    required this.expiresAt,
  });

  factory StaffInvitationResponse.fromJson(Map<String, dynamic> json) {
    return StaffInvitationResponse(
      invitationId: json['invitationId'] ?? '',
      email: json['email'] ?? '',
      status: json['status'] ?? 'pending',
      temporaryPassword: json['temporaryPassword'],
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt']) ?? DateTime.now().add(const Duration(days: 7))
          : DateTime.now().add(const Duration(days: 7)),
    );
  }
}

/// Staff performance metrics
class StaffPerformance {
  final String staffId;
  final String staffName;
  final int totalTransactions;
  final double totalRevenue;
  final double totalFuelLiters;
  final int petrolTransactions;
  final int dieselTransactions;
  final double petrolLiters;
  final double dieselLiters;
  final DateTime periodStart;
  final DateTime periodEnd;

  StaffPerformance({
    required this.staffId,
    required this.staffName,
    required this.totalTransactions,
    required this.totalRevenue,
    required this.totalFuelLiters,
    required this.petrolTransactions,
    required this.dieselTransactions,
    required this.petrolLiters,
    required this.dieselLiters,
    required this.periodStart,
    required this.periodEnd,
  });

  factory StaffPerformance.fromJson(Map<String, dynamic> json) {
    return StaffPerformance(
      staffId: json['staffId'] ?? '',
      staffName: json['staffName'] ?? '',
      totalTransactions: (json['totalTransactions'] ?? 0).toInt(),
      totalRevenue: (json['totalRevenue'] ?? 0).toDouble(),
      totalFuelLiters: (json['totalFuelLiters'] ?? 0).toDouble(),
      petrolTransactions: (json['petrolTransactions'] ?? 0).toInt(),
      dieselTransactions: (json['dieselTransactions'] ?? 0).toInt(),
      petrolLiters: (json['petrolLiters'] ?? 0).toDouble(),
      dieselLiters: (json['dieselLiters'] ?? 0).toDouble(),
      periodStart: json['periodStart'] != null
          ? DateTime.tryParse(json['periodStart']) ?? DateTime.now()
          : DateTime.now(),
      periodEnd: json['periodEnd'] != null
          ? DateTime.tryParse(json['periodEnd']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  double get averageTransactionValue => totalTransactions > 0
      ? totalRevenue / totalTransactions
      : 0;

  double get petrolPercentage => totalFuelLiters > 0
      ? (petrolLiters / totalFuelLiters) * 100
      : 0;

  double get dieselPercentage => totalFuelLiters > 0
      ? (dieselLiters / totalFuelLiters) * 100
      : 0;
}

/// Staff repository for API operations
class StaffRepository {
  final ApiClient _apiClient = ApiClient();

  /// Get all staff members for the current owner's station
  Future<List<StaffMember>> getStaffList({
    String? status,
    String? role,
    int page = 1,
    int limit = 20,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (status != null) 'status': status,
      if (role != null) 'role': role,
    };

    final response = await _apiClient.get(
      '/staff',
      queryParameters: queryParams,
    );

    if (response.statusCode == 200 && response.data['success'] == true) {
      final data = response.data['data'] ?? response.data;
      final List<dynamic> staffList = data is List ? data : (data['items'] ?? []);
      return staffList.map((e) => StaffMember.fromJson(e)).toList();
    } else {
      throw Exception(response.data['error'] ?? 'Failed to load staff list');
    }
  }

  /// Get staff member details
  Future<StaffMember> getStaffDetails(String staffId) async {
    final response = await _apiClient.get('/staff/$staffId');

    if (response.statusCode == 200 && response.data['success'] == true) {
      final data = response.data['data'] ?? response.data;
      return StaffMember.fromJson(data);
    } else {
      throw Exception(response.data['error'] ?? 'Failed to load staff details');
    }
  }

  /// Invite new staff member
  Future<StaffInvitationResponse> inviteStaff(StaffInvitation invitation) async {
    final response = await _apiClient.post(
      '/staff/invite',
      data: invitation.toJson(),
    );

    if ((response.statusCode == 200 || response.statusCode == 201) &&
        response.data['success'] == true) {
      final data = response.data['data'] ?? response.data;
      return StaffInvitationResponse.fromJson(data);
    } else {
      throw Exception(response.data['error'] ?? 'Failed to invite staff');
    }
  }

  /// Update staff member
  Future<StaffMember> updateStaff(
    String staffId, {
    String? name,
    String? phone,
    String? role,
    String? status,
  }) async {
    final response = await _apiClient.patch(
      '/staff/$staffId',
      data: {
        if (name != null) 'name': name,
        if (phone != null) 'phone': phone,
        if (role != null) 'role': role,
        if (status != null) 'status': status,
      },
    );

    if (response.statusCode == 200 && response.data['success'] == true) {
      final data = response.data['data'] ?? response.data;
      return StaffMember.fromJson(data);
    } else {
      throw Exception(response.data['error'] ?? 'Failed to update staff');
    }
  }

  /// Deactivate staff member
  Future<void> deactivateStaff(String staffId) async {
    final response = await _apiClient.post('/staff/$staffId/deactivate');

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(response.data['error'] ?? 'Failed to deactivate staff');
    }
  }

  /// Reactivate staff member
  Future<void> reactivateStaff(String staffId) async {
    final response = await _apiClient.post('/staff/$staffId/reactivate');

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(response.data['error'] ?? 'Failed to reactivate staff');
    }
  }

  /// Get staff performance metrics
  Future<List<StaffPerformance>> getStaffPerformance({
    required DateTime startDate,
    required DateTime endDate,
    String? staffId,
  }) async {
    final queryParams = <String, dynamic>{
      'startDate': startDate.toIso8601String().split('T')[0],
      'endDate': endDate.toIso8601String().split('T')[0],
      if (staffId != null) 'staffId': staffId,
    };

    final response = await _apiClient.get(
      '/reports/staff-performance',
      queryParameters: queryParams,
    );

    if (response.statusCode == 200 && response.data['success'] == true) {
      final data = response.data['data'] ?? response.data;
      final List<dynamic> performanceList = data is List ? data : (data['items'] ?? []);
      return performanceList.map((e) => StaffPerformance.fromJson(e)).toList();
    } else {
      throw Exception(response.data['error'] ?? 'Failed to load staff performance');
    }
  }

  /// Get individual staff transactions
  Future<List<Map<String, dynamic>>> getStaffTransactions(
    String staffId, {
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,
    int limit = 20,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (startDate != null)
        'startDate': startDate.toIso8601String().split('T')[0],
      if (endDate != null) 'endDate': endDate.toIso8601String().split('T')[0],
    };

    final response = await _apiClient.get(
      '/staff/$staffId/transactions',
      queryParameters: queryParams,
    );

    if (response.statusCode == 200 && response.data['success'] == true) {
      final data = response.data['data'] ?? response.data;
      final List<dynamic> transactions = data is List ? data : (data['items'] ?? []);
      return transactions.cast<Map<String, dynamic>>();
    } else {
      throw Exception(response.data['error'] ?? 'Failed to load staff transactions');
    }
  }

  /// Resend invitation email
  Future<void> resendInvitation(String invitationId) async {
    final response = await _apiClient.post('/staff/invitations/$invitationId/resend');

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(response.data['error'] ?? 'Failed to resend invitation');
    }
  }

  /// Cancel pending invitation
  Future<void> cancelInvitation(String invitationId) async {
    final response = await _apiClient.delete('/staff/invitations/$invitationId');

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(response.data['error'] ?? 'Failed to cancel invitation');
    }
  }
}
