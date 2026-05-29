import 'package:equatable/equatable.dart';

class TokenData extends Equatable {
  final String accessToken;
  final String idToken;
  final String refreshToken;
  final DateTime expiresAt;
  final String customerId;
  final String phone;
  final String? email;
  final String? displayName;

  const TokenData({
    required this.accessToken,
    required this.idToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.customerId,
    required this.phone,
    this.email,
    this.displayName,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  bool get isNearExpiry =>
      DateTime.now().isAfter(expiresAt.subtract(const Duration(minutes: 5)));

  TokenData copyWithNewTokens({
    required String accessToken,
    required String idToken,
    required DateTime expiresAt,
  }) {
    return TokenData(
      accessToken: accessToken,
      idToken: idToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
      customerId: customerId,
      phone: phone,
      email: email,
      displayName: displayName,
    );
  }

  Map<String, String> toStorageMap() => {
        'accessToken': accessToken,
        'idToken': idToken,
        'refreshToken': refreshToken,
        'expiresAt': expiresAt.toIso8601String(),
        'customerId': customerId,
        'phone': phone,
        if (email != null) 'email': email!,
        if (displayName != null) 'displayName': displayName!,
      };

  factory TokenData.fromStorageMap(Map<String, String> map) {
    return TokenData(
      accessToken: map['accessToken']!,
      idToken: map['idToken']!,
      refreshToken: map['refreshToken']!,
      expiresAt: DateTime.parse(map['expiresAt']!),
      customerId: map['customerId']!,
      phone: map['phone']!,
      email: map['email'],
      displayName: map['displayName'],
    );
  }

  @override
  List<Object?> get props => [accessToken, customerId, expiresAt];
}
