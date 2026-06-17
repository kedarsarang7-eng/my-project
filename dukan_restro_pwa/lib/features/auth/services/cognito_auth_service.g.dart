// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cognito_auth_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(authService)
final authServiceProvider = AuthServiceProvider._();

final class AuthServiceProvider extends $FunctionalProvider<
    CognitoAuthServicePWA,
    CognitoAuthServicePWA,
    CognitoAuthServicePWA> with $Provider<CognitoAuthServicePWA> {
  AuthServiceProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'authServiceProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$authServiceHash();

  @$internal
  @override
  $ProviderElement<CognitoAuthServicePWA> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CognitoAuthServicePWA create(Ref ref) {
    return authService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CognitoAuthServicePWA value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CognitoAuthServicePWA>(value),
    );
  }
}

String _$authServiceHash() => r'd8f3c873915ce75c00ec2510d487ec52e9361e18';
