import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dukanx_shared/dukanx_shared.dart';
import '../../../core/di/providers.dart';

class ProfileRepository {
  final CustomerApiClient _client;
  const ProfileRepository(this._client);

  Future<CustomerProfile> getProfile() async {
    final response = await _client.get('/customer/v1/profile');
    if (!response.isSuccess) {
      throw ApiException(
        statusCode: response.statusCode,
        message: response.error ?? 'Failed to load profile',
      );
    }
    return CustomerProfile.fromJson(response.data!);
  }

  Future<CustomerProfile> updateProfile({
    required String displayName,
    String? email,
    String? address,
    String? city,
    String? state,
    String? pincode,
  }) async {
    final response = await _client.patch(
      '/customer/v1/profile',
      body: {
        'displayName': displayName,
        'email': ?email,
        'address': ?address,
        'city': ?city,
        'state': ?state,
        'pincode': ?pincode,
      },
    );

    if (!response.isSuccess) {
      throw ApiException(
        statusCode: response.statusCode,
        message: response.error ?? 'Failed to update profile',
      );
    }
    return CustomerProfile.fromJson(response.data!);
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.read(customerApiClientProvider));
});

final customerProfileProvider = FutureProvider<CustomerProfile>((ref) async {
  return ref.read(profileRepositoryProvider).getProfile();
});
