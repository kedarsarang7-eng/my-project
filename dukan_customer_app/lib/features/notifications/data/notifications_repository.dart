import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dukanx_shared/dukanx_shared.dart';
import '../../../core/di/providers.dart';

class NotificationsRepository {
  final CustomerApiClient _client;
  const NotificationsRepository(this._client);

  Future<List<CustomerNotification>> getNotifications() async {
    final response = await _client.get('/customer/v1/notifications');
    if (!response.isSuccess) {
      throw ApiException(
        statusCode: response.statusCode,
        message: response.error ?? 'Failed to load notifications',
      );
    }
    final items = response.data!['notifications'] as List<dynamic>? ?? [];
    return items
        .map((e) => CustomerNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> markRead(String notificationId) async {
    await _client.patch('/customer/v1/notifications/$notificationId/read');
  }

  Future<void> markAllRead() async {
    await _client.patch('/customer/v1/notifications/read-all');
  }
}

final notificationsRepositoryProvider =
    Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(ref.read(customerApiClientProvider));
});

final notificationsProvider =
    FutureProvider<List<CustomerNotification>>((ref) async {
  return ref.read(notificationsRepositoryProvider).getNotifications();
});
