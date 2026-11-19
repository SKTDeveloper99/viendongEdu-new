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

  /// Reviewer move: `POST /v1/tasks/:id/transition {assignment_id, to_status, note?}`
  /// → `{ok, assignment, event}`.
  static Future<Map<String, dynamic>> review(
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
  /// In a Nhóm with a head (LAW T-46) each call is a signature: when the
  /// giver is the head, the first call already finishes it (`done`); when a
  /// second signer is still due, the second call answers 409 and the work
  /// waits for them. Neither is an error for the person who signed.
  static Future<void> approve(
    String id,
    String assignmentId,
    String status,
  ) async {
    var signed = false;
    if (status == 'submitted') {
      try {
        final r = await review(id, assignmentId, 'in_review');
        if ((r['assignment'] as Map?)?['status'] == 'done') return;
        signed = true;
      } on EmsException catch (e) {
        // 409: already in_review (an earlier Duyệt got half way); go on.
        if (e.statusCode != 409) rethrow;
      }
    }
    try {
      await review(id, assignmentId, 'done');
    } on EmsException catch (e) {
      if (!(signed && e.statusCode == 409)) rethrow;
    }
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

  /// A report (duty report, recurring report) handed in the way the web's
  /// report form does it: `POST /v1/teacher/tasks/:assignmentId/report`,
  /// multipart `note` + up to 8 `photos`. The server starts the part, checks
  /// the word and photo minimums and hands it in, all in one transaction.
  static Future<Map<String, dynamic>> submitReport(
    String assignmentId, {
    required String note,
    List<({List<int> bytes, String filename})> photos = const [],
  }) => EmsUpload.files(
    '/v1/teacher/tasks/$assignmentId/report',
    files: photos,
    field: 'photos',
    fields: {'note': note},
  );

  /// An ordinary piece with a word or file minimum, handed in like the web:
  /// `POST /v1/tasks/my/:assignmentId/submit`, multipart `note` + `files`.
  /// (The bare transition never records the text the minimum is counted on.)
  static Future<Map<String, dynamic>> submitWithNote(
    String assignmentId, {
    required String note,
    List<({List<int> bytes, String filename})> files = const [],
  }) => EmsUpload.files(
    '/v1/tasks/my/$assignmentId/submit',
    files: files,
    field: 'files',
    fields: {'note': note},
  );

  /// The hand-in rules of my part, from my own list (`GET /v1/tasks/my`,
  /// where the server folds the template's minimums in); the piece itself
  /// ([task]) is the fallback when the row is not there.
  static Future<ReportRule> ruleFor(
    Map<String, dynamic> task,
    String assignmentId,
  ) async {
    try {
      for (final r in await received()) {
        if ('${r['assignment_id']}' == assignmentId) return ReportRule.of(r);
      }
    } on EmsException catch (e) {
      if (e.statusCode == 401) rethrow;
    }
    return ReportRule.of({
      'is_report': task['is_report'],
      'min_words': task['report_min_words'],
      'min_photos': task['report_min_photos'],
      'max_photos': task['report_max_photos'],
      'min_submission_files': task['min_submission_files'],
    });
  }

  /// "+ Giao việc": `POST /v1/tasks`, reviewed by the giver. The same
  /// [requestId] on a resend makes the server answer once. Returns the id.
  static Future<String> give({
    required String title,
    String description = '',
    DateTime? due,
    required List<String> people,
    required String requestId,
  }) async {
    final r = await EmsApiService.sendMap(
      'POST',
      '/v1/tasks',
      body: {
        'title': title,
        if (description.isNotEmpty) 'description': description,
        if (due != null) 'due_at': due.toUtc().toIso8601String(),
        'assignee_user_ids': people,
        'requires_review': true,
        'client_request_id': requestId,
      },
    );
    final id = (r['task'] as Map?)?['id']?.toString();
    if (id == null) throw EmsException('Máy chủ không trả về việc vừa giao.');
    return id;
  }

  /// A giver's file on the piece itself (no `assignment_id`): every receiver
  /// sees it under "Tệp kèm", as on the web.
  static Future<Map<String, dynamic>> attachToPiece(
    String id,
    List<int> bytes, {
    required String filename,
  }) => EmsUpload.file(
    '/v1/tasks/$id/attachments',
    bytes: bytes,
    filename: filename,
  );

  /// Receiver side: start / hand in. Behind [taskShowsReceipt] only: the
  /// old "Đã nhận" (an acknowledge rings the giver).
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

/// Proposed LAW T-59 (2026-11-18, server `34a61b2`): task screens show no
/// "Đã nhận" button, no "Chưa nhận"/"Chưa mở" label and no receipt step; a new
/// piece reads "Mới giao" until it is started. Notices keep their "Đã nhận".
/// If the owner turns T-59 down: --dart-define=TASK_SHOWS_RECEIPT=true.
const bool taskShowsReceipt = bool.fromEnvironment(
  'TASK_SHOWS_RECEIPT',
  defaultValue: false,
);

/// New = still `assigned` ("Mới giao"); with receipts shown, also never
/// acknowledged ("Chưa mở").
bool isUnopened(Map<String, dynamic> a, {bool receipts = taskShowsReceipt}) =>
    a['status'] == 'assigned' && (!receipts || a['acknowledged_at'] == null);

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
  bool receipts = taskShowsReceipt,
}) => switch (status) {
  'assigned' => !receipts ? 'Mới giao' : (acknowledged ? 'Đã nhận' : 'Chưa mở'),
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

/// The giver's files on a piece. The server sends them in both
/// `instruction_attachments` and `attachments` (same ids), so each id is
/// listed once; files on a person's part (`assignment_id` set) are not here.
List<Map> pieceFiles(Map task) {
  final seen = <String>{};
  return [
    for (final f in [
      ...((task['instruction_attachments'] as List?) ?? const []),
      ...((task['attachments'] as List?) ?? const []).where(
        (f) => (f as Map)['assignment_id'] == null,
      ),
    ].cast<Map>())
      if (seen.add('${f['id'] ?? f['storage_key'] ?? f['filename']}')) f,
  ];
}

/// What a hand-in must carry (CRM lib/tasks/report-policy.js): at least
/// [minWords] words, at least [minPhotos] photos on the part, at most
/// [maxPhotos] in one sending; [isReport] goes through the report form.
class ReportRule {
  final bool isReport;
  final int minWords;
  final int minPhotos;
  final int? maxPhotos;
  final int minFiles;
  const ReportRule({
    this.isReport = false,
    this.minWords = 0,
    this.minPhotos = 0,
    this.maxPhotos,
    this.minFiles = 0,
  });

  factory ReportRule.of(Map<String, dynamic> r) {
    final max = asInt(r['max_photos']);
    return ReportRule(
      isReport: r['is_report'] == true,
      minWords: asInt(r['min_words']),
      minPhotos: asInt(r['min_photos']),
      maxPhotos: max > 0 ? max : null,
      minFiles: asInt(r['min_submission_files']),
    );
  }

  /// A long text and photos: the report sheet, not the short note.
  bool get needsReportSheet => isReport || minWords > 0 || minPhotos > 0;

  /// The server's one request takes at most this many photos.
  int get photoCap => maxPhotos == null ? 8 : (maxPhotos! < 8 ? maxPhotos! : 8);
}

/// Words as the server counts them: runs of non-space.
int wordCount(String text) {
  final t = text.trim();
  return t.isEmpty ? 0 : t.split(RegExp(r'\s+')).length;
}
