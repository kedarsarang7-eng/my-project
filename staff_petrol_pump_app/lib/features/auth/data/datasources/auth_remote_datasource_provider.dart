import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_remote_datasource.dart';

/// Provider for AuthRemoteDataSource
final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSourceImpl();
});
