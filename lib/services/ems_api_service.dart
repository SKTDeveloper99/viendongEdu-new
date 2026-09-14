import 'dart:convert';
import 'package:http/http.dart' as http;
import 'app_session.dart';

/// Lỗi từ EMS. `code` là mã máy ổn định (ví dụ 'account_deactivated'),
/// `message` là câu tiếng Việt hiển thị cho người dùng.
class EmsException implements Exception {
  final String message;
  final String? code;
  final int? statusCode;
  EmsException(this.message, {this.code, this.statusCode});

  /// EMS đã trả lời rằng tài khoản không được phép dùng EMS.
  ///
  /// 401 thường chỉ có nghĩa là một token đã hết hạn. Giữ nó ở đường thử lại;
  /// nếu coi 401 là từ chối vĩnh viễn, một phiên cũ có thể khoá EMS cho tới khi
  /// tiến trình ứng dụng được khởi động lại.
  bool get isDeliberateDenial => statusCode == 403 || statusCode == 404;

  @override
  String toString() => message;
}

/// Cầu nối tới EMS (CRM Viễn Đông).
///
/// Tách hẳn khỏi [ApiService] (IMS) vì hai hệ thống có hai token riêng và hai
/// vòng đời riêng: EMS hỏng thì màn hình IMS vẫn phải chạy bình thường.
///
/// Không hardcode IP/port, không bỏ qua kiểm tra TLS.
class EmsApiService {
  /// Production. Đổi khi build bằng:
  ///   flutter build --dart-define=EMS_API_BASE_URL=https://.../api
  static const String baseUrl = String.fromEnvironment(
    'EMS_API_BASE_URL',
    defaultValue: 'https://ems.viendong.edu.vn/api',
  );

  static const Duration _timeout = Duration(seconds: 15);

  /// Đường ra mạng. Thay được trong test để chạy màn hình Bảng tin với dữ liệu
  /// dựng sẵn; trong app thật luôn là client HTTP mặc định (giữ nguyên kiểm tra
  /// TLS — không có chế độ bỏ qua chứng chỉ).
  static http.Client client = http.Client();

  /// Header cho widget ảnh (Image.network) — ảnh cũng nằm sau Bearer token.
  static Map<String, String> get authHeaders {
    final t = AppSession.instance.emsToken;
    return (t == null || t.isEmpty) ? const {} : {'Authorization': 'Bearer $t'};
  }

  static Map<String, String> _headers({bool auth = true}) {
    final h = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      final t = AppSession.instance.emsToken;
      if (t != null && t.isNotEmpty) h['Authorization'] = 'Bearer $t';
    }
    return h;
  }

  /// Đọc body JSON và dựng [EmsException] từ cả `error` lẫn `message`.
  ///
  /// Server trả `{error: <mã máy>, message: <tiếng Việt>}` cho các lỗi có mã,
  /// và `{error: <câu tiếng Việt>}` cho các lỗi do middleware dựng. Xử lý cả
  /// hai dạng, và cả trường hợp body KHÔNG phải JSON (nginx/Cloudflare chen vào
  /// một trang HTML) — lúc đó vẫn phải là một lỗi đọc được, không phải crash.
  static Map<String, dynamic> _decode(http.Response res) {
    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    } catch (_) {
      body = null;
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (body == null) {
        throw EmsException(
          'Máy chủ trả về dữ liệu không đọc được.',
          statusCode: res.statusCode,
        );
      }
      return body;
    }

    final rawError = body?['error']?.toString();
    final rawMessage = body?['message']?.toString();

    // 422 riêng của điểm danh: có học viên đã quẹt cổng mà bị ghi VẮNG không
    // kèm lý do. Không phải lỗi — là câu hỏi. Màn hình hỏi lý do rồi gửi lại,
    // nên nó cần biết ĐÍCH DANH ai, không chỉ là "lưu thất bại".
    if (body?['code'] == 'punch_conflict_needs_reason') {
      final raw = body?['students'];
      throw EmsPunchConflict(
        rawError ?? 'Cần nêu lý do.',
        students: (raw is List)
            ? raw
                  .whereType<Map<String, dynamic>>()
                  .map(
                    (e) => EmsPunchedStudent(
                      mssv: e['mssv']?.toString() ?? '',
                      punchedAt: DateTime.tryParse(
                        e['punched_at']?.toString() ?? '',
                      )?.toLocal(),
                    ),
                  )
                  .toList()
            : const [],
        statusCode: res.statusCode,
      );
    }

    throw EmsException(
      rawMessage ?? rawError ?? 'Không kết nối được máy chủ thông tin.',
      code: rawError,
      statusCode: res.statusCode,
    );
  }

  static Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    http.Response res;
    try {
      final headers = _headers(auth: auth);
      final encoded = body == null ? null : jsonEncode(body);
      res =
          await (method == 'POST'
                  ? client.post(uri, headers: headers, body: encoded)
                  : method == 'DELETE'
                  ? client.delete(uri, headers: headers, body: encoded)
                  : client.get(uri, headers: headers))
              .timeout(_timeout);
    } catch (e) {
      // Mạng hỏng / quá hạn / DNS — không có statusCode, nên không bị coi là
      // từ chối có chủ đích và màn hình sẽ hiện nút "Thử lại".
      throw EmsException('Không tải được bảng tin. Vui lòng thử lại.');
    }
    return _decode(res);
  }

  // ── Identity mirror ────────────────────────────────────────────────────────
  // Token IMS CHÍNH LÀ giấy thông hành ở đây; các endpoint này không cần Bearer.

  /// Đổi token IMS của học viên lấy token EMS. Trả về token EMS.
  static Future<String> mirrorStudent(String imsToken) async {
    final body = await _send(
      'POST',
      '/v1/identity/mirror',
      body: {'ims_token': imsToken},
      auth: false,
    );
    final token = body['crm_token']?.toString();
    if (token == null || token.isEmpty) {
      throw EmsException('Máy chủ thông tin không cấp được phiên đăng nhập.');
    }
    return token;
  }

  /// Bản đối chiếu cho giảng viên.
  static Future<String> mirrorTeacher(
    String imsToken, {
    String? fcmToken,
    String? platform,
    String? appVersion,
  }) async {
    final body = await _send(
      'POST',
      '/v1/identity/teacher-mirror',
      body: {
        'ims_token': imsToken,
        // Null-aware entries: bỏ hẳn khoá khi giá trị null, không gửi null.
        'fcm_token': ?fcmToken,
        'platform': ?platform,
        'app_version': ?appVersion,
      },
      auth: false,
    );
    final token = body['crm_token']?.toString();
    if (token == null || token.isEmpty) {
      throw EmsException('Máy chủ thông tin không cấp được phiên đăng nhập.');
    }
    return token;
  }

  // ── Điểm danh EMS ──────────────────────────────────────────────────────────
  //
  // EMS là nguồn dữ liệu điểm danh chính thức. Không đọc/ghi IMS khi vận hành.
  //
  // Khác biệt cốt lõi so với IMS, và cũng là lý do màn hình này tồn tại:
  //   - chưa điểm danh KHÔNG phải là vắng (status = null, không mặc định absent);
  //   - lưu lại nhiều lần cũng chỉ ra một dòng (UNIQUE session_key + mssv);
  //   - trường hợp lạ vẫn được ghi và gắn cờ để xem lại, không bị chặn.

  static Future<List<EmsSession>> mySessions({String? date}) {
    return _withReMirror(() async {
      final q = (date == null || date.isEmpty) ? '' : '?date=$date';
      final body = await _send('GET', '/attendance/my-sessions$q');
      // `from_schedule: false` = máy chủ KHÔNG có buổi nào hôm nay và đang trả
      // về danh sách mọi lớp của giáo viên (không giờ, không phòng) thay thế.
      // Đó không phải buổi học hôm nay: lưu điểm danh vào đó bị từ chối (422)
      // và ngày 14/09 nó đã sinh ra 21 dấu điểm danh cho lớp chưa khai giảng.
      // Hiện danh sách trống — hôm nay không có buổi học là hôm nay không có.
      if (body['from_schedule'] == false) return <EmsSession>[];
      final list = body['sessions'];
      if (list is! List) return <EmsSession>[];
      return list
          .whereType<Map<String, dynamic>>()
          .map(EmsSession.fromJson)
          .toList();
    });
  }

  static Future<EmsRoster> roster(EmsSession s) {
    return _withReMirror(() async {
      final q =
          '?section_id=${Uri.encodeQueryComponent(s.sectionId)}'
          '&date=${Uri.encodeQueryComponent(s.sessionDate)}'
          '&start_time=${Uri.encodeQueryComponent(s.startTime ?? '')}'
          '&end_time=${Uri.encodeQueryComponent(s.endTime ?? '')}';
      final body = await _send('GET', '/attendance/roster$q');
      return EmsRoster.fromJson(body);
    });
  }

  /// Trạng thái EMS của MỘT buổi, theo `session_key` (`<lmhid>:<HH-MM>:<yyyy-MM-dd>`).
  /// Dùng khi chỉ có dữ liệu lịch IMS trong tay (Quản lý lớp): danh sách lớp
  /// vẫn là của IMS, nhưng ai có mặt / vắng là EMS nói — không phải IMS.
  /// Trả về map mssv → status ('present' | 'late' | 'absent' | 'excused').
  static Future<Map<String, String>> sessionMarks(String sessionKey) {
    return _withReMirror(() async {
      final body = await _send(
        'GET',
        '/attendance/session-marks?session_key=${Uri.encodeQueryComponent(sessionKey)}',
      );
      final list = body['marks'];
      final out = <String, String>{};
      if (list is List) {
        for (final m in list.whereType<Map<String, dynamic>>()) {
          final mssv = m['mssv']?.toString();
          final st = m['status']?.toString();
          if (mssv != null && st != null) out[mssv] = st;
        }
      }
      return out;
    });
  }

  /// `session_key` đúng như máy chủ tạo (repositories/attendance-write-repo.js):
  /// `<ims lopmonhoc id>:<HH-MM>:<yyyy-MM-dd>`.
  static String sessionKeyFor({
    required String lmhId,
    required String date,
    required String startTime,
  }) {
    final t = startTime.trim();
    final hhmm = t.length >= 5 ? t.substring(0, 5).replaceAll(':', '-') : t.replaceAll(':', '-');
    return '$lmhId:$hhmm:$date';
  }

  /// Lưu điểm danh. Những trường hợp lạ vẫn được lưu và gắn cờ để xem lại.
  static Future<EmsSaveResult> saveMarks(
    EmsSession s,
    List<EmsMark> marks, {
    List<String> remove = const [],
  }) {
    return _withReMirror(() async {
      try {
        final body = await _send(
          'POST',
          '/attendance/marks',
          body: {
            'section_id': s.sectionId,
            'date': s.sessionDate,
            'start_time': ?s.startTime,
            'end_time': ?s.endTime,
            'marks': marks.map((m) => m.toJson()).toList(),
            // Bỏ điểm danh những học viên giáo viên đã bỏ chọn.
            if (remove.isNotEmpty) 'remove': remove,
          },
        );
        return EmsSaveResult.fromJson(body);
      } on EmsPunchConflict {
        rethrow;
      }
    });
  }

  /// Học viên xem điểm danh EMS của chính mình.
  static Future<List<EmsStudentMark>> myAttendance({int limit = 100}) {
    return _withReMirror(() async {
      final body = await _send(
        'GET',
        '/student/me/attendance-ems?limit=$limit',
      );
      final list = body['marks'] ?? body['history'] ?? body['items'];
      if (list is! List) return <EmsStudentMark>[];
      return list
          .whereType<Map<String, dynamic>>()
          .map(EmsStudentMark.fromJson)
          .toList();
    });
  }

  // ── Bảng tin ───────────────────────────────────────────────────────────────
  //
  // Mỗi lời gọi đi qua [_withReMirror]: gặp 401 thì thử đối chiếu LẠI MỘT LẦN
  // bằng token IMS hiện có rồi gọi lại. Một lần, không lặp — 401 lần hai nghĩa
  // là phiên IMS cũng đã hết, và việc thử mãi chỉ tạo bão request.

  static Future<T> _withReMirror<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on EmsException catch (e) {
      if (e.statusCode != 401) rethrow;
      final ok = await AppSession.instance.refreshEmsToken();
      if (!ok) rethrow;
      return await call();
    }
  }

  static Future<List<AnnouncementItem>> board({int limit = 50}) {
    return _withReMirror(() async {
      final body = await _send('GET', '/v1/student/board?limit=$limit');
      final items = body['items'];
      if (items is! List) return <AnnouncementItem>[];
      return items
          .whereType<Map<String, dynamic>>()
          .map(AnnouncementItem.fromJson)
          .toList();
    });
  }

  static Future<BoardUnread> unreadCount() {
    return _withReMirror(() async {
      final body = await _send('GET', '/v1/student/board/unread-count');
      return BoardUnread(
        unread: (body['unread'] as num?)?.toInt() ?? 0,
        mustReadPending: (body['must_read_pending'] as num?)?.toInt() ?? 0,
      );
    });
  }

  /// Gắn installation Firebase hiện tại với chính học viên đã đăng nhập EMS.
  /// MSSV không nằm trong body: server lấy nó từ token EMS đã ký.
  static Future<void> registerStudentDevice(
    String fcmToken, {
    String? platform,
    String? appVersion,
  }) async {
    await _send(
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
    await _send(
      'DELETE',
      '/v1/student/board/devices',
      body: {'fcm_token': fcmToken},
    );
  }

  /// Đóng dấu đã đọc. Idempotent ở phía server: gọi lại không đổi mốc thời gian.
  static Future<void> markRead(String id) {
    return _withReMirror(() => _send('POST', '/v1/student/board/$id/read'));
  }

  /// Xác nhận đã đọc và hiểu. Server đóng cả hai mốc trong một câu lệnh.
  static Future<void> acknowledge(String id) {
    return _withReMirror(
      () => _send('POST', '/v1/student/board/$id/acknowledge'),
    );
  }
}

/// Một tấm ảnh kèm theo thông báo.
///
/// [url] là đường dẫn tương đối server trả về; [absoluteUrl] ghép với base để
/// widget ảnh dùng trực tiếp. Ảnh cần Bearer token nên phải kèm [authHeaders].
class AnnouncementImage {
  final String id;
  final String url;
  final int? width;
  final int? height;

  const AnnouncementImage({
    required this.id,
    required this.url,
    this.width,
    this.height,
  });

  factory AnnouncementImage.fromJson(Map<String, dynamic> j) =>
      AnnouncementImage(
        id: j['id']?.toString() ?? '',
        url: j['url']?.toString() ?? '',
        width: (j['width'] as num?)?.toInt(),
        height: (j['height'] as num?)?.toInt(),
      );

  /// Server trả '/api/v1/...' còn baseUrl đã kết thúc bằng '/api' — cắt phần
  /// '/api' trùng để không thành '/api/api/v1/...'.
  String get absoluteUrl {
    final base = EmsApiService.baseUrl;
    final path = url.startsWith('/api') ? url.substring(4) : url;
    return '$base$path';
  }

  double? get aspectRatio => (width != null && height != null && height! > 0)
      ? width! / height!
      : null;
}

class BoardUnread {
  final int unread;
  final int mustReadPending;
  const BoardUnread({required this.unread, required this.mustReadPending});
}

/// Một thông báo đã đến tay học viên này.
///
/// `body` là NGUYÊN VĂN server đã đóng băng lúc phát hành — app không ghép
/// trường, không dựng lại từ mẫu.
class AnnouncementItem {
  final String id;
  final String title;
  final String body;
  final String? category;
  final bool mustRead;
  final bool isCorrection;
  final DateTime? publishedAt;
  final List<AnnouncementImage> images;
  DateTime? readAt;
  DateTime? acknowledgedAt;

  AnnouncementItem({
    required this.id,
    required this.title,
    required this.body,
    this.category,
    this.mustRead = false,
    this.isCorrection = false,
    this.publishedAt,
    this.images = const [],
    this.readAt,
    this.acknowledgedAt,
  });

  bool get isUnread => readAt == null;
  bool get needsAcknowledgement => mustRead && acknowledgedAt == null;

  static DateTime? _date(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString())?.toLocal();
  }

  factory AnnouncementItem.fromJson(Map<String, dynamic> j) => AnnouncementItem(
    id: j['id']?.toString() ?? '',
    title: j['title']?.toString() ?? '',
    body: j['body']?.toString() ?? '',
    category: j['category']?.toString(),
    mustRead: j['must_read'] == true,
    isCorrection: j['is_correction'] == true,
    publishedAt: _date(j['published_at']),
    images: (j['images'] is List)
        ? (j['images'] as List)
              .whereType<Map<String, dynamic>>()
              .map(AnnouncementImage.fromJson)
              .toList()
        : const [],
    readAt: _date(j['read_at']),
    acknowledgedAt: _date(j['acknowledged_at']),
  );

  static const Map<String, String> categoryLabels = {
    'general': 'Thông báo chung',
    'schedule': 'Lịch học / lịch thi',
    'deadline': 'Hạn chót',
    'urgent': 'Khẩn',
  };

  String get categoryLabel => categoryLabels[category] ?? 'Thông báo';
}

// ── Mô hình điểm danh EMS ────────────────────────────────────────────────────

/// Học viên đã quẹt cổng nhưng đang bị ghi VẮNG mà chưa có lý do.
class EmsPunchedStudent {
  final String mssv;
  final DateTime? punchedAt;
  const EmsPunchedStudent({required this.mssv, this.punchedAt});
}

/// 422 có chủ đích từ EMS, không phải sự cố. Kế thừa [EmsException] để mọi
/// `catch (EmsException)` sẵn có vẫn bắt được, nhưng mang theo danh sách người.
class EmsPunchConflict extends EmsException {
  final List<EmsPunchedStudent> students;
  EmsPunchConflict(super.message, {required this.students, super.statusCode})
    : super(code: 'punch_conflict_needs_reason');
}

/// Một buổi dạy trong sổ lịch bền vững của EMS.
class EmsSession {
  final String sectionId;
  final String sectionCode;
  final String? subjectName;
  final String? room;
  final String sessionDate;
  final String? startTime;
  final String? endTime;
  final int rosterSize;
  final int markedCount;
  final String sessionKey;
  final String reportState;

  const EmsSession({
    required this.sectionId,
    required this.sectionCode,
    required this.sessionDate,
    required this.sessionKey,
    this.subjectName,
    this.room,
    this.startTime,
    this.endTime,
    this.rosterSize = 0,
    this.markedCount = 0,
    this.reportState = 'open',
  });

  bool get isMarked => markedCount > 0;

  String get timeLabel => (startTime == null || endTime == null)
      ? 'Chưa có giờ'
      : '$startTime – $endTime';

  factory EmsSession.fromJson(Map<String, dynamic> j) => EmsSession(
    sectionId: j['section_id']?.toString() ?? '',
    sectionCode: j['section_code']?.toString() ?? '',
    subjectName: j['subject_name']?.toString(),
    room: j['room']?.toString(),
    sessionDate: j['session_date']?.toString() ?? '',
    startTime: j['start_time']?.toString(),
    endTime: j['end_time']?.toString(),
    // count(*) của Postgres là bigint — có thể về dạng chuỗi. Parse cho chắc.
    rosterSize: int.tryParse('${j['roster_size'] ?? 0}') ?? 0,
    markedCount: int.tryParse('${j['marked_count'] ?? 0}') ?? 0,
    sessionKey: j['session_key']?.toString() ?? '',
    reportState: j['report_state']?.toString() ?? 'open',
  );

  Map<String, dynamic> toJson() => {
    'section_id': sectionId,
    'section_code': sectionCode,
    'subject_name': ?subjectName,
    'room': ?room,
    'session_date': sessionDate,
    'start_time': ?startTime,
    'end_time': ?endTime,
    'roster_size': rosterSize,
    'marked_count': markedCount,
    'session_key': sessionKey,
    'report_state': reportState,
  };
}

/// Một dòng trong danh sách lớp.
///
/// [status] null nghĩa là CHƯA ĐIỂM DANH — không phải vắng. Đây là khác biệt
/// quan trọng nhất so với IMS và giao diện phải thể hiện đúng như vậy.
class EmsRosterStudent {
  final String mssv;
  final String fullName;
  final String? classCode;
  final bool inScope;
  final String? status;
  final String? note;
  final bool scanned;
  final DateTime? scannedAt;
  final int? punchId;

  const EmsRosterStudent({
    required this.mssv,
    required this.fullName,
    this.classCode,
    this.inScope = false,
    this.status,
    this.note,
    this.scanned = false,
    this.scannedAt,
    this.punchId,
  });

  factory EmsRosterStudent.fromJson(Map<String, dynamic> j) => EmsRosterStudent(
    mssv: j['mssv']?.toString() ?? '',
    fullName: j['full_name']?.toString() ?? '',
    classCode: j['class_code']?.toString(),
    inScope: j['in_scope'] == true,
    status: j['status']?.toString(),
    note: j['note']?.toString(),
    scanned: j['scanned'] == true,
    scannedAt: DateTime.tryParse(j['scanned_at']?.toString() ?? '')?.toLocal(),
    // punch_id là bigint của Postgres — tuỳ driver trả về SỐ hoặc CHUỖI. Ép
    // 'as num' sẽ nổ khi nó là chuỗi. Parse từ toString() cho chắc.
    punchId: j['punch_id'] == null ? null : int.tryParse(j['punch_id'].toString()),
  );

  Map<String, dynamic> toJson() => {
    'mssv': mssv,
    'full_name': fullName,
    'class_code': ?classCode,
    'in_scope': inScope,
    'status': ?status,
    'note': ?note,
    'scanned': scanned,
    'scanned_at': ?scannedAt?.toIso8601String(),
    'punch_id': ?punchId,
  };
}

class EmsRoster {
  final String sessionKey;
  final List<EmsRosterStudent> students;
  final int unmatchedScans;
  /// Lần gần nhất EMS kéo được lượt quẹt cổng từ máy chấm công (null = chưa
  /// bao giờ). Giáo viên nhìn giờ này để biết danh sách "đã quẹt" cũ tới đâu.
  final DateTime? scanSyncedAt;

  const EmsRoster({
    required this.sessionKey,
    required this.students,
    this.unmatchedScans = 0,
    this.scanSyncedAt,
  });

  factory EmsRoster.fromJson(Map<String, dynamic> j) => EmsRoster(
    sessionKey: j['session_key']?.toString() ?? '',
    scanSyncedAt: DateTime.tryParse(j['scan_synced_at']?.toString() ?? ''),
    students: (j['students'] is List)
        ? (j['students'] as List)
              .whereType<Map<String, dynamic>>()
              .map(EmsRosterStudent.fromJson)
              .toList()
        : const [],
    unmatchedScans: (j['unmatched_scans'] is List)
        ? (j['unmatched_scans'] as List).length
        : 0,
  );
}

class EmsMark {
  final String mssv;
  final String status; // 'present' | 'absent'
  final String? note;
  final int? punchId;
  const EmsMark({
    required this.mssv,
    required this.status,
    this.note,
    this.punchId,
  });

  Map<String, dynamic> toJson() => {
    'mssv': mssv,
    'status': status,
    'note': ?note,
    'punch_id': ?punchId,
  };
}

class EmsSaveResult {
  final int saved;
  final int inserted;
  final int updated;
  final bool late;
  final DateTime? deadline;
  final List<String> overriddenPunches;

  const EmsSaveResult({
    this.saved = 0,
    this.inserted = 0,
    this.updated = 0,
    this.late = false,
    this.deadline,
    this.overriddenPunches = const [],
  });

  factory EmsSaveResult.fromJson(Map<String, dynamic> j) => EmsSaveResult(
    saved: (j['saved'] as num?)?.toInt() ?? 0,
    inserted: (j['inserted'] as num?)?.toInt() ?? 0,
    updated: (j['updated'] as num?)?.toInt() ?? 0,
    late: j['late'] == true,
    deadline: DateTime.tryParse(j['deadline']?.toString() ?? '')?.toLocal(),
    overriddenPunches: (j['overridden_punches'] is List)
        ? (j['overridden_punches'] as List).map((e) => e.toString()).toList()
        : const [],
  );
}

/// Một dòng điểm danh EMS mà học viên tự xem.
class EmsStudentMark {
  final String? sessionKey;
  final String? sessionDate;
  final String? status;
  final String? subjectName;
  final String? sectionCode;
  final String? note;
  final String? startTime;
  final String? endTime;
  final DateTime? arrivedAt;
  final bool? arrivalOnTime;
  /// 'ems' (teacher/scanner record, authoritative) or 'ims' (mirrored history).
  final String? source;

  const EmsStudentMark({
    this.sessionKey,
    this.sessionDate,
    this.status,
    this.subjectName,
    this.sectionCode,
    this.note,
    this.startTime,
    this.endTime,
    this.arrivedAt,
    this.arrivalOnTime,
    this.source,
  });

  factory EmsStudentMark.fromJson(Map<String, dynamic> j) => EmsStudentMark(
    sessionKey: j['session_key']?.toString(),
    sessionDate: j['session_date']?.toString(),
    status: j['status']?.toString(),
    subjectName: j['subject_name']?.toString(),
    sectionCode: j['section_code']?.toString(),
    note: j['note']?.toString(),
    startTime: j['start_time']?.toString(),
    endTime: j['end_time']?.toString(),
    arrivedAt: DateTime.tryParse(j['arrived_at']?.toString() ?? '')?.toLocal(),
    arrivalOnTime: j['arrival_on_time'] as bool?,
    source: j['source']?.toString(),
  );

  Map<String, dynamic> toJson() => {
    'session_key': ?sessionKey,
    'session_date': ?sessionDate,
    'status': ?status,
    'source': ?source,
    'subject_name': ?subjectName,
    'section_code': ?sectionCode,
    'note': ?note,
    'start_time': ?startTime,
    'end_time': ?endTime,
    'arrived_at': ?arrivedAt?.toIso8601String(),
    'arrival_on_time': ?arrivalOnTime,
  };

  /// Ngày buổi học dạng dd/MM/yyyy.
  ///
  /// session_date của EMS là một Postgres DATE, về tới đây dưới dạng
  /// 'YYYY-MM-DDT00:00:00.000Z'. KHÔNG đưa qua DateTime.parse().toLocal() —
  /// nửa đêm UTC quy về giờ Việt Nam (+7) sẽ nhảy về NGÀY HÔM TRƯỚC. Đây là
  /// một mốc lịch, không phải một thời điểm: đọc thẳng Y-M-D từ chuỗi.
  String get sessionDateVN {
    final s = sessionDate ?? '';
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
    return m == null ? s : '${m.group(3)}/${m.group(2)}/${m.group(1)}';
  }
}
