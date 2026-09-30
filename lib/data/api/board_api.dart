import '../../services/ems_api_service.dart';

abstract final class BoardApi {
  // ── Bảng tin ───────────────────────────────────────────────────────────────
  //
  // 401 ở bất kỳ lời gọi nào dưới đây nghĩa là phiên EMS đã hết hạn — không
  // còn token IMS để đối chiếu lại nữa. Nơi gọi bắt EmsException(statusCode:
  // 401), gọi AppSession.clear() rồi điều hướng về '/login'.

  static Future<List<AnnouncementItem>> board({int limit = 50}) async {
    final body = await EmsApiService.sendMap('GET', '/v1/student/board?limit=$limit');
    final items = body['items'];
    if (items is! List) return <AnnouncementItem>[];
    return items
        .whereType<Map<String, dynamic>>()
        .map(AnnouncementItem.fromJson)
        .toList();
  }

  /// [board] through the disk cache; [onStored] paints the stored copy first.
  static Future<({List<AnnouncementItem> data, DateTime savedAt, bool fresh})>
  boardCached({
    int limit = 50,
    void Function(List<AnnouncementItem> items, DateTime savedAt)? onStored,
  }) async {
    List<AnnouncementItem> parse(dynamic body) {
      final items = body is Map ? body['items'] : null;
      if (items is! List) return <AnnouncementItem>[];
      return items
          .whereType<Map<String, dynamic>>()
          .map(AnnouncementItem.fromJson)
          .toList();
    }

    final r = await EmsApiService.sendCached(
      '/v1/student/board',
      query: {'limit': '$limit'},
      onStored: onStored == null ? null : (d, at) => onStored(parse(d), at),
    );
    return (data: parse(r.data), savedAt: r.savedAt, fresh: r.fresh);
  }

  static Future<BoardUnread> unreadCount() async {
    final body = await EmsApiService.sendMap('GET', '/v1/student/board/unread-count');
    return BoardUnread(
      unread: (body['unread'] as num?)?.toInt() ?? 0,
      mustReadPending: (body['must_read_pending'] as num?)?.toInt() ?? 0,
    );
  }

  /// Gắn installation Firebase hiện tại với chính học viên đã đăng nhập EMS.
  /// MSSV không nằm trong body: server lấy nó từ token EMS đã ký.
  static Future<void> registerStudentDevice(
    String fcmToken, {
    String? platform,
    String? appVersion,
  }) async {
    await EmsApiService.sendMap(
      'POST',
      '/v1/student/board/devices',
      body: {
        'fcm_token': fcmToken,
        'platform': ?platform,
        'app_version': ?appVersion,
      },
    );
  }

  static Future<void> revokeStudentDevice(String fcmToken) async {
    await EmsApiService.sendMap(
      'DELETE',
      '/v1/student/board/devices',
      body: {'fcm_token': fcmToken},
    );
  }

  /// Đóng dấu đã đọc. Idempotent ở phía server: gọi lại không đổi mốc thời gian.
  static Future<void> markRead(String id) {
    return EmsApiService.sendMap('POST', '/v1/student/board/$id/read');
  }

  /// Xác nhận đã đọc và hiểu. Server đóng cả hai mốc trong một câu lệnh.
  static Future<void> acknowledge(String id) {
    return EmsApiService.sendMap('POST', '/v1/student/board/$id/acknowledge');
  }
}
