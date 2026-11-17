import '../../services/ems_api_service.dart';

/// The bell's work rows (`/v1/notifications?work=1`) and marking one read.
abstract final class BellApi {
  static Future<List<Map<String, dynamic>>> workRows() async {
    final b = await EmsApiService.sendMap(
      'GET',
      '/v1/notifications',
      query: const {'limit': '50', 'work': '1'},
    );
    return EmsApiService.rows(b['notifications'] ?? const []);
  }

  static Future<void> markRead(String kind, String id) => EmsApiService.sendMap(
    'PATCH',
    '/v1/notifications/$kind/$id/read',
  ).then((_) {}, onError: (_) {});
}
