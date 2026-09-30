import '../../services/ems_api_service.dart';

abstract final class TeacherNotificationsApi {
  // ── Giảng viên — thông báo CRM (thay backend Vercel “noti-backend-eight” (đã gỡ), gỡ bởi
  // bot A5, 2026-09-25) ───────────────────────────────────────────────────
  // `routes/portals/teacher-notifications.js` (crm-clean), mounted ở
  // `/api/teacher/notifications`. Hình dạng phản hồi khớp NGUYÊN VĂN với
  // parser cũ (`{success, data: [{id, title, body, status, sentAt}]}`) — xem
  // ghi chú trong file route đó, viết đúng như vậy để không phải sửa lại
  // parser ở `notifications_screen.dart`.

  /// `GET /teacher/notifications?limit=`.
  static Future<List<dynamic>> teacherNotifications({int limit = 50}) async {
    final body =
        await EmsApiService.send('GET', '/teacher/notifications', query: {'limit': '$limit'})
            as Map<String, dynamic>;
    final list = body['data'];
    return list is List ? list : const [];
  }

  /// `PATCH /teacher/notifications/:id { read: true }`.
  static Future<void> markTeacherNotificationRead(String id) {
    return EmsApiService.sendMap('PATCH', '/teacher/notifications/$id', body: {'read': true});
  }

  /// `POST /teacher/notifications/mark-all-read`.
  static Future<void> markAllTeacherNotificationsRead() {
    return EmsApiService.sendMap('POST', '/teacher/notifications/mark-all-read');
  }

  /// `GET /teacher/notifications/unread-count` → `{count}`.
  static Future<int> teacherUnreadCount() async {
    final body = await EmsApiService.sendMap('GET', '/teacher/notifications/unread-count');
    return (body['count'] as num?)?.toInt() ?? 0;
  }

  /// `POST /teacher/notifications/devices {fcm_token, platform?, app_version?}`.
  /// Kênh đăng ký lại token cho giảng viên NGOÀI lúc đăng nhập (xoay token,
  /// khôi phục phiên) — trước 2026-09-25 không có, phải đợi lần đăng nhập kế
  /// tiếp (xem `NotificationService._postToken`).
  static Future<void> registerTeacherDevice(
    String fcmToken, {
    String? platform,
    String? appVersion,
  }) async {
    await EmsApiService.sendMap(
      'POST',
      '/teacher/notifications/devices',
      body: {
        'fcm_token': fcmToken,
        'platform': ?platform,
        'app_version': ?appVersion,
      },
    );
  }

  /// `DELETE /teacher/notifications/devices {fcm_token}`.
  static Future<void> revokeTeacherDevice(String fcmToken) async {
    await EmsApiService.sendMap(
      'DELETE',
      '/teacher/notifications/devices',
      body: {'fcm_token': fcmToken},
    );
  }
}
