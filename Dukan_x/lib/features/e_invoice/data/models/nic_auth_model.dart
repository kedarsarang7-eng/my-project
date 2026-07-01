class NicAuthModel {
  final String status;
  final AuthData? data;
  final ErrorDetails? error;

  NicAuthModel({required this.status, this.data, this.error});

  bool get isSuccess => status == '1';

  factory NicAuthModel.fromJson(Map<String, dynamic> json) {
    return NicAuthModel(
      status: json['Status'] as String,
      data: json['Data'] != null ? AuthData.fromJson(json['Data']) : null,
      error: json['ErrorDetails'] != null
          ? ErrorDetails.fromJson(json['ErrorDetails'])
          : null,
    );
  }
}

class AuthData {
  final String clientId;
  final String userName;
  final String? authToken;
  final String? sek; // Session Encryption Key
  final String? tokenExpiry;

  AuthData({
    required this.clientId,
    required this.userName,
    this.authToken,
    this.sek,
    this.tokenExpiry,
  });

  factory AuthData.fromJson(Map<String, dynamic> json) {
    return AuthData(
      clientId: json['ClientId'] as String,
      userName: json['UserName'] as String,
      authToken: json['AuthToken'] as String?,
      sek: json['Sek'] as String?,
      tokenExpiry: json['TokenExpiry'] as String?,
    );
  }
}

class ErrorDetails {
  final String? errorCode;
  final String? errorMessage;

  ErrorDetails({this.errorCode, this.errorMessage});

  factory ErrorDetails.fromJson(List<dynamic> jsonList) {
    if (jsonList.isEmpty) return ErrorDetails();
    final first = jsonList.first as Map<String, dynamic>;
    return ErrorDetails(
      errorCode: first['ErrorCode'] as String?,
      errorMessage: first['ErrorMessage'] as String?,
    );
  }
}
