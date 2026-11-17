import 'dart:math';

import '../../services/ems_api_service.dart';
import '../../services/ems_upload.dart';

/// Native "Việc của tôi" (Overlord slice) on the JSON Viva's web already uses:
/// `routes/tasks/tasks.js` under `/api/v1/tasks`.
abstract final class WorkApi {
  /// Work given to me: `GET /v1/tasks/my` → `{tasks:[assignment rows]}`.
  static Future<List<Map<String, dynamic>>> received() async {
    final b = await EmsApiService.sendMap('GET', '/v1/tasks/my');
    return EmsApiService.rows(b['tasks'] ?? const []);
  }

  /// Work I gave: `GET /v1/tasks?created_by=me` (admin, vice_admin).
  static Future<List<Map<String, dynamic>>> given() async {
    final b = await EmsApiService.sendMap(
      'GET',
      '/v1/tasks',
      query: const {'created_by': 'me', 'limit': '200'},
    );
    return EmsApiService.rows(b['tasks'] ?? const []);
  }

  /// One piece: `GET /v1/tasks/:id` → `{task:{…, assignments, attachments}}`.
  static Future<Map<String, dynamic>> task(String id) async {
    final b = await EmsApiService.sendMap('GET', '/v1/tasks/$id');
    return EmsApiService.parse(() => b['task'] as Map<String, dynamic>);
  }

  static Future<List<Map<String, dynamic>>> comments(String id) async {
    final b = await EmsApiService.sendMap('GET', '/v1/tasks/$id/comments');
    return EmsApiService.rows(b['comments'] ?? const []);
  }

  static Future<void> addComment(String id, String body) =>
      EmsApiService.sendMap(
        'POST',
        '/v1/tasks/$id/comments',
        body: {'body': body},
      );

  /// Reviewer move: `POST /v1/tasks/:id/transition {assignment_id, to_status, note?}`.
  static Future<void> review(
    String id,
    String assignmentId,
    String toStatus, {
    String? note,
  }) => EmsApiService.sendMap(
    'POST',
    '/v1/tasks/$id/transition',
    body: {
      'assignment_id': assignmentId,
      'to_status': toStatus,
      if (note != null && note.isNotEmpty) 'note': note,
    },
  );

  /// Duyệt: a hand-in goes submitted → in_review → done (state machine).
  static Future<void> approve(
    String id,
    String assignmentId,
    String status,
  ) async {
    if (status == 'submitted') await review(id, assignmentId, 'in_review');
    await review(id, assignmentId, 'done');
  }

  /// Trả lại with a reason: → in_progress.
  static Future<void> giveBack(String id, String assignmentId, String note) =>
      review(id, assignmentId, 'in_progress', note: note);

  /// Nhắc one person with her own sentence: `POST /v1/tasks/:id/nudge-one`.
  static Future<void> nudge(String id, String assignmentId, String message) =>
      EmsApiService.sendMap(
        'POST',
        '/v1/tasks/$id/nudge-one',
        body: {'assignment_id': assignmentId, 'message': message},
      );

  /// A file on my part of a piece, as the web sends it:
  /// `POST /v1/tasks/:id/attachments` (multipart `file` + `assignment_id`).
  static Future<Map<String, dynamic>> attach(
    String id,
    String assignmentId,
    List<int> bytes, {
    required String filename,
  }) => EmsUpload.file(
    '/v1/tasks/$id/attachments',
    bytes: bytes,
    filename: filename,
    fields: {'assignment_id': assignmentId},
  );

  /// Receiver side: "Đã nhận", then start / hand in.
  static Future<void> acknowledge(String assignmentId) =>
      EmsApiService.sendMap('POST', '/v1/tasks/my/$assignmentId/acknowledge');

  static Future<void> move(
    String assignmentId,
    String toStatus, {
    String? note,
  }) => EmsApiService.sendMap(
    'POST',
    '/v1/tasks/my/$assignmentId/transition',
    body: {
      'to_status': toStatus,
      if (note != null && note.isNotEmpty) 'note': note,
    },
  );
}

/// THE SWITCH for Việc của tôi (2026-11-17): true = pieces the person has not
/// opened yet come first, newest first, then the rest in the server's order;
/// false = the server's order only. One line here, or
/// --dart-define=MY_WORK_UNOPENED_FIRST=false.
const bool myWorkUnopenedFirst = bool.fromEnvironment(
  'MY_WORK_UNOPENED_FIRST',
  defaultValue: true,
);

/// Not opened = still `assigned` and never acknowledged ("Chưa mở").
bool isUnopened(Map<String, dynamic> a) =>
    a['status'] == 'assigned' && a['acknowledged_at'] == null;

/// Unopened pieces first (newest `assigned_at` first), the rest after them in
/// the order given. Stable: equal items keep their order.
List<Map<String, dynamic>> unopenedFirst(List<Map<String, dynamic>> rows) {
  final fresh = rows.where(isUnopened).toList();
  final rest = rows.where((a) => !isUnopened(a)).toList();
  DateTime at(Map<String, dynamic> a) =>
      DateTime.tryParse('${a['assigned_at'] ?? ''}') ?? DateTime(0);
  final indexed = [for (var i = 0; i < fresh.length; i++) (i, fresh[i])];
  indexed.sort((x, y) {
    final c = at(y.$2).compareTo(at(x.$2));
    return c != 0 ? c : x.$1.compareTo(y.$1);
  });
  return [for (final e in indexed) e.$2, ...rest];
}

/// A random v4 UUID for `client_request_id`: the same id on a resend lets
/// the server answer once (POST /v1/tasks double-submit guard).
String newRequestId() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  String h(int i) => b[i].toRadixString(16).padLeft(2, '0');
  final x = [for (var i = 0; i < 16; i++) h(i)].join();
  return '${x.substring(0, 8)}-${x.substring(8, 12)}-${x.substring(12, 16)}-'
      '${x.substring(16, 20)}-${x.substring(20)}';
}

int asInt(Object? v) => v is int ? v : int.tryParse('${v ?? ''}') ?? 0;

/// Status words for one person's part, as the web board says them.
String statusLabel(
  String? status, {
  bool acknowledged = false,
  int returned = 0,
}) => switch (status) {
  'assigned' => acknowledged ? 'Đã nhận' : 'Chưa mở',
  'in_progress' => returned > 0 ? 'Bị trả lại' : 'Đang làm',
  'submitted' => 'Đã nộp',
  'in_review' => 'Đang xem',
  'done' => 'Đã duyệt',
  'blocked' => 'Vướng',
  'cancelled' => 'Đã huỷ',
  _ => status ?? '',
};

String dueLabel(Object? iso) {
  final d = DateTime.tryParse('${iso ?? ''}')?.toLocal();
  if (d == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return 'hạn ${two(d.hour)}:${two(d.minute)} ${two(d.day)}/${two(d.month)}';
}

String whenLabel(Object? iso) {
  final d = DateTime.tryParse('${iso ?? ''}')?.toLocal();
  if (d == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.hour)}:${two(d.minute)} ${two(d.day)}/${two(d.month)}';
}
