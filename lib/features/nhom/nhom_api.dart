import '../../services/ems_api_service.dart';

/// Native Nhóm (Overlord slice) on `routes/spaces/spaces.js` (`/api/spaces`).
abstract final class NhomApi {
  /// `GET /spaces` → `{spaces:[…], can_create}`.
  static Future<Map<String, dynamic>> list() =>
      EmsApiService.sendMap('GET', '/spaces');

  /// `GET /spaces/:id` → `{space, members, counts, can_manage, me}`.
  static Future<Map<String, dynamic>> one(String id) =>
      EmsApiService.sendMap('GET', '/spaces/$id');

  static Future<List<Map<String, dynamic>>> feed(String id) async {
    final b = await EmsApiService.sendMap('GET', '/spaces/$id/feed');
    return EmsApiService.rows(b['feed'] ?? const []);
  }

  /// `GET /spaces/:id/tasks` → one row per person per piece.
  static Future<List<Map<String, dynamic>>> work(String id) async {
    final b = await EmsApiService.sendMap('GET', '/spaces/$id/tasks');
    return EmsApiService.rows(b['assignments'] ?? const []);
  }

  /// urgent: "Cần xem ngay" (a banner to the group, the sender's daily cap).
  static Future<Map<String, dynamic>> post(
    String id,
    String body, {
    bool urgent = false,
  }) => EmsApiService.sendMap(
    'POST',
    '/spaces/$id/posts',
    body: {'kind': 'discussion', 'body': body, if (urgent) 'urgent': true},
  );

  /// `POST /spaces/:id/tasks {title, description?, due_at?, assignee_user_ids?, list_id?}`
  /// — without assignees, everyone else in the group receives it.
  static Future<Map<String, dynamic>> giveWork(
    String id, {
    required String title,
    String? description,
    DateTime? dueAt,
    List<String>? assigneeIds,
    String? listId,
  }) => EmsApiService.sendMap(
    'POST',
    '/spaces/$id/tasks',
    body: {
      'title': title,
      if (description != null && description.isNotEmpty)
        'description': description,
      if (dueAt != null) 'due_at': dueAt.toUtc().toIso8601String(),
      if (assigneeIds != null && assigneeIds.isNotEmpty)
        'assignee_user_ids': assigneeIds,
      'requires_review': true,
      // The table each receiver fills before "Nộp" (LAW T-49/T-58).
      'list_id': ?listId,
    },
  );
}
