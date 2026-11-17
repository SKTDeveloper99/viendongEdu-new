import '../../services/ems_api_service.dart';

/// `GET /auth/app/me` → `{user, kinds, permissions, can, counts, day_card}`
/// (Overlord slice).
abstract final class AppMeApi {
  /// The first call after a quiet spell can outlast the 7 s read limit while
  /// the server warms its counts; one quiet retry then fills the home by
  /// itself (the server has usually finished the first one meanwhile).
  /// Only a no-answer failure is retried; a refusal (401, 403, ...) is not.
  static Future<Map<String, dynamic>> me({
    Duration retryAfter = const Duration(seconds: 2),
  }) async {
    try {
      return await EmsApiService.sendMap('GET', '/auth/app/me');
    } on EmsException catch (e) {
      if (e.statusCode != null) rethrow;
      await Future<void>.delayed(retryAfter);
      return EmsApiService.sendMap('GET', '/auth/app/me');
    }
  }
}
