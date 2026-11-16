import '../../services/ems_api_service.dart';

/// Small groups and tables (Overlord slice; server migrations 181–182).
abstract final class SmallGroupApi {
  /// People the caller may give work to (`?work=1`), or everyone on staff.
  static Future<List<Map<String, dynamic>>> people({bool work = true}) async {
    final b = await EmsApiService.sendMap(
      'GET',
      '/v1/directory/report-recipients',
      query: work ? const {'work': '1'} : null,
    );
    return EmsApiService.rows(b['people'] ?? const []);
  }

  /// "Giao một phần": `POST /week-calendar/pieces/:taskId/delegate`.
  /// Opens the piece's small group when there is none, adds the people,
  /// optionally makes a table, and gives the part inside the group.
  static Future<Map<String, dynamic>> delegate(
    String taskId, {
    required List<String> people,
    required String title,
    String? description,
    DateTime? dueAt,
    String? listTitle,
    List<Map<String, String>> columns = const [],
  }) => EmsApiService.sendMap(
    'POST',
    '/week-calendar/pieces/$taskId/delegate',
    body: {
      'assignee_user_ids': people,
      'title': title,
      if (description != null && description.isNotEmpty)
        'description': description,
      if (dueAt != null) 'due_at': dueAt.toUtc().toIso8601String(),
      if (listTitle != null && listTitle.isNotEmpty)
        'list': {'title': listTitle, 'columns': columns},
    },
  );

  /// "Giữ nhóm này": `POST /spaces/:id/keep`.
  static Future<void> keep(String spaceId) =>
      EmsApiService.sendMap('POST', '/spaces/$spaceId/keep');

  /// A small group with no piece: temporary unless kept.
  static Future<Map<String, dynamic>> create({
    required String name,
    required List<String> members,
    bool temporary = true,
  }) => EmsApiService.sendMap(
    'POST',
    '/spaces',
    body: {'name': name, 'member_user_ids': members, 'temporary': temporary},
  );

  // ── Tables (Danh sách) ────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> lists(String spaceId) async {
    final b = await EmsApiService.sendMap(
      'GET',
      '/spaces/$spaceId/student-lists',
    );
    return EmsApiService.rows(b['lists'] ?? const []);
  }

  static Future<Map<String, dynamic>> createList(
    String spaceId,
    String title,
  ) => EmsApiService.sendMap(
    'POST',
    '/spaces/$spaceId/student-lists',
    body: {'title': title},
  );

  static Future<Map<String, dynamic>> list(String spaceId, String listId) =>
      EmsApiService.sendMap('GET', '/spaces/$spaceId/student-lists/$listId');

  static Future<void> addColumn(
    String spaceId,
    String listId,
    String name,
    String kind,
  ) => EmsApiService.sendMap(
    'POST',
    '/spaces/$spaceId/student-lists/$listId/columns',
    body: {'name': name, 'kind': kind},
  );

  /// rows: `[{mssv}]`, `[{user_id}]` or `[{text}]` (one kind per call).
  static Future<Map<String, dynamic>> addRows(
    String spaceId,
    String listId,
    List<Map<String, String>> rows,
  ) => EmsApiService.sendMap(
    'POST',
    '/spaces/$spaceId/student-lists/$listId/rows',
    body: {'rows': rows},
  );

  static Future<void> setCell(
    String spaceId,
    String listId,
    String rowId,
    String columnId,
    String? value,
  ) => EmsApiService.sendMap(
    'PUT',
    '/spaces/$spaceId/student-lists/$listId/rows/$rowId/cells/$columnId',
    body: {'value': value},
  );
}

const columnKinds = <String, String>{
  'yes_no': 'Có / Không',
  'text': 'Chữ',
  'number': 'Số',
  'date': 'Ngày',
  'link': 'Liên kết',
};
