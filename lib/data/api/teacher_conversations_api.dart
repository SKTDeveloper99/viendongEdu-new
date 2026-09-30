import '../../models/teacher_conversation_models.dart';
import '../../services/ems_api_service.dart';

/// Teacher chat with students — `/api/v1/teacher/conversations` on the CRM.
/// The server scopes every call to threads addressed to the signed-in
/// teacher; nothing here sends a teacher id.
abstract final class TeacherConversationsApi {
  static const _base = '/v1/teacher/conversations';

  /// `GET /?status=open|closed` through the disk cache; [onStored] paints the
  /// stored copy first.
  static Future<
    ({List<TeacherConversation> data, DateTime savedAt, bool fresh})
  >
  listCached(
    String status, {
    int limit = 100,
    void Function(List<TeacherConversation> rows, DateTime savedAt)? onStored,
  }) async {
    final r = await EmsApiService.sendCached(
      _base,
      query: {'status': status, 'limit': '$limit'},
      onStored: onStored == null
          ? null
          : (d, at) => onStored(TeacherConversation.listFrom(d), at),
    );
    return (
      data: TeacherConversation.listFrom(r.data),
      savedAt: r.savedAt,
      fresh: r.fresh,
    );
  }

  /// `GET /unread-count` -> `{count}`: threads awaiting the teacher's reply.
  /// For the future home-tile badge.
  static Future<int> unreadCount() async {
    final body = await EmsApiService.sendMap('GET', '$_base/unread-count');
    return (body['count'] as num?)?.toInt() ?? 0;
  }

  static Future<TeacherThread> thread(String id) async =>
      TeacherThread.fromJson(
        await EmsApiService.sendMap('GET', '$_base/${Uri.encodeComponent(id)}'),
      );

  /// `POST /:id/messages {body}` -> `{message}`.
  static Future<TeacherMessage?> send(String id, String message) async {
    final body = await EmsApiService.sendMap(
      'POST',
      '$_base/${Uri.encodeComponent(id)}/messages',
      body: {'body': message.trim()},
    );
    final m = body['message'];
    return m is Map<String, dynamic> ? TeacherMessage.fromJson(m) : null;
  }

  /// `PATCH /:id` — resolves and closes the thread.
  static Future<void> resolve(String id) async {
    await EmsApiService.sendMap('PATCH', '$_base/${Uri.encodeComponent(id)}');
  }

  /// `POST / {mssv, subject?, body}` -> `{conversation, message}`. Returns the
  /// new conversation id.
  static Future<String> create({
    required String mssv,
    required String message,
    String? subject,
  }) async {
    final body = await EmsApiService.sendMap(
      'POST',
      _base,
      body: {
        'mssv': mssv.trim(),
        'body': message.trim(),
        if (subject != null && subject.trim().isNotEmpty)
          'subject': subject.trim(),
      },
    );
    final conv = body['conversation'];
    final id = conv is Map ? conv['id']?.toString() : null;
    if (id == null || id.isEmpty) {
      throw EmsException(
        'Máy chủ chưa xác nhận tin nhắn. Hãy kiểm tra danh sách trước khi gửi lại.',
      );
    }
    return id;
  }
}
