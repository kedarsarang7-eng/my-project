class LoginRequestDto {
  final String username;
  final String password;

  const LoginRequestDto({required this.username, required this.password});

  Map<String, dynamic> toJson() => {'username': username, 'password': password};
}

class LoginResponseDto {
  final String accessToken;
  final String? idToken;
  final String? refreshToken;
  final int? expiresIn;

  const LoginResponseDto({
    required this.accessToken,
    this.idToken,
    this.refreshToken,
    this.expiresIn,
  });

  factory LoginResponseDto.fromJson(Map<String, dynamic> json) {
    return LoginResponseDto(
      accessToken: json['accessToken'] as String,
      idToken: json['idToken'] as String?,
      refreshToken: json['refreshToken'] as String?,
      expiresIn: json['expiresIn'] as int?,
    );
  }
}

class RefreshTokenRequestDto {
  final String refreshToken;

  const RefreshTokenRequestDto({required this.refreshToken});

  Map<String, dynamic> toJson() => {'refreshToken': refreshToken};
}
