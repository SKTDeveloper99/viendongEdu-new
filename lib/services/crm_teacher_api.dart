import 'dart:convert';
import 'package:http/http.dart' as http;
import 'app_session.dart';
import 'ems_api_service.dart';
import '../models/crm_teacher_profile.dart';
import '../models/crm_teacher_class.dart';

/// Lời gọi CRM cho các màn hình giáo viên (trừ điểm danh EMS — đã có sẵn
/// trong [EmsApiService]). Thay cho `ApiService` (IMS) cho toàn bộ slice
/// giáo viên: `gv_home_screen`, `gv_schedule_screen`, `gv_lophoc_screen`,
/// `gv_quanly_lop_screen`, `gv_lichthi_screen`.
///
/// Mọi endpoint dưới đây sống ở `routes/portals/teacher-portal.js` (CRM,
/// `crm-clean` repo) — xem `docs/ims_to_crm_teacher_map.md` cho bảng đối
/// chiếu đầy đủ IMS → CRM. Đi qua [EmsApiService.send] để dùng chung xử lý
/// lỗi/timeout/401 với phần còn lại của app — KHÔNG tự viết http client
/// riêng.
class CrmTeacherApi {
  /// `GET /api/teacher/me`.
  static Future<CrmTeacherProfile> me() async {
    final body = await EmsApiService.send('GET', '/teacher/me')
        as Map<String, dynamic>;
    final t = (body['teacher'] as Map?)?.cast<String, dynamic>() ?? const {};
    return CrmTeacherProfile.fromJson(t);
  }

  /// `GET /api/teacher/me/overview?semester=`. Một lời gọi cho hồ sơ + lịch
  /// dạy hôm nay + tóm tắt học kỳ — dùng cho `gv_home_screen`.
  static Future<CrmTeacherOverview> overview({String? semester}) async {
    final body =
        await EmsApiService.send(
              'GET',
              '/teacher/me/overview',
              query: (semester == null || semester.isEmpty)
                  ? null
                  : {'semester': semester},
            )
            as Map<String, dynamic>;
    return CrmTeacherOverview.fromJson(body);
  }

  /// `GET /api/teacher/me/semesters`. Mirror của IMS `GET /hocky`: mảng trần
  /// (`res.json(rows)`, KHÔNG bọc trong `{data: ...}`).
  ///
  /// [EmsApiService.send] không dùng được ở đây: `_decode` của nó chỉ chấp
  /// nhận JSON ở dạng object (`Map`) — một mảng trần khiến nó tưởng nhầm là
  /// "dữ liệu không đọc được" dù server trả 200 hợp lệ. [_getRawList] đi
  /// vòng qua đúng một bước đó (parse mảng thay vì object) nhưng vẫn dùng
  /// chung [EmsApiService.client]/[EmsApiService.baseUrl]/token — không phải
  /// một http client độc lập.
  static Future<List<CrmSemester>> semesters() async {
    final body = await _getRawList('/teacher/me/semesters');
    return body
        .whereType<Map<String, dynamic>>()
        .map(CrmSemester.fromJson)
        .toList();
  }

  /// `GET /api/teacher/me/schedule?date=YYYY-MM-DD`.
  static Future<List<CrmScheduleSlot>> scheduleForDate(String date) async {
    final body =
        await EmsApiService.send(
              'GET',
              '/teacher/me/schedule',
              query: {'date': date},
            )
            as Map<String, dynamic>;
    final list = body['data'];
    if (list is! List) return const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(CrmScheduleSlot.fromJson)
        .toList();
  }

  /// `GET /api/teacher/me/schedule/semester?semester=`.
  static Future<List<CrmScheduleSlot>> scheduleForSemester(
    String semester,
  ) async {
    final body =
        await EmsApiService.send(
              'GET',
              '/teacher/me/schedule/semester',
              query: {'semester': semester},
            )
            as Map<String, dynamic>;
    final list = body['data'];
    if (list is! List) return const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(CrmScheduleSlot.fromJson)
        .toList();
  }

  /// `GET /api/teacher/me/classes?semester=`. `semester` bỏ trống dùng mặc
  /// định của server (học kỳ hiện tại); truyền `'all'` để lấy mọi học kỳ.
  static Future<List<CrmTeacherClass>> classes({String? semester}) async {
    final body =
        await EmsApiService.send(
              'GET',
              '/teacher/me/classes',
              query: (semester == null || semester.isEmpty)
                  ? null
                  : {'semester': semester},
            )
            as Map<String, dynamic>;
    final list = body['classes'];
    if (list is! List) return const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(CrmTeacherClass.fromJson)
        .toList();
  }

  /// `GET /api/teacher/me/classes/:sectionId/students`.
  static Future<List<CrmClassStudent>> classStudents(String sectionId) async {
    final body =
        await EmsApiService.send(
              'GET',
              '/teacher/me/classes/$sectionId/students',
            )
            as Map<String, dynamic>;
    final list = body['students'];
    if (list is! List) return const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(CrmClassStudent.fromJson)
        .toList();
  }

  /// `GET /api/teacher/me/classes/:sectionId/attendance`. Trả về PHẲNG (một
  /// dòng cho mỗi cặp buổi/học viên) — xem [CrmAttendanceRow] để biết vì sao
  /// đây chỉ là bản chụp CRM, không phải điểm danh EMS thật.
  static Future<List<CrmAttendanceRow>> classAttendance(
    String sectionId,
  ) async {
    final body =
        await EmsApiService.send(
              'GET',
              '/teacher/me/classes/$sectionId/attendance',
            )
            as Map<String, dynamic>;
    final list = body['attendance'];
    if (list is! List) return const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(CrmAttendanceRow.fromJson)
        .toList();
  }

  /// `GET /api/teacher/me/exams?semester=`. Thay IMS `giangvien/lichthi`.
  ///
  /// GHI CHÚ TRIỂN KHAI (2026-09-24): route này (`routes/portals/teacher-
  /// exams.js`, bot S3) mới chỉ có trên nhánh làm việc riêng của S3, CHƯA lên
  /// `main`/prod của crm-clean tại thời điểm viết file này. Gọi hàm này trước
  /// khi route đó được gộp sẽ trả 404 — màn hình xử lý như một lỗi mạng bình
  /// thường (hiện "Thử lại"), không có gì phải sửa ở phía app khi route lên
  /// prod. Xem `docs/ims_to_crm_teacher_map.md`.
  static Future<List<CrmTeacherExam>> exams({String? semester}) async {
    final body =
        await EmsApiService.send(
              'GET',
              '/teacher/me/exams',
              query: (semester == null || semester.isEmpty)
                  ? null
                  : {'semester': semester},
            )
            as Map<String, dynamic>;
    final list = body['exams'];
    if (list is! List) return const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(CrmTeacherExam.fromJson)
        .toList();
  }

  /// GET một endpoint mà server trả một mảng JSON TRẦN (không bọc object) —
  /// xem [semesters]. Dùng [EmsApiService.client]/[EmsApiService.baseUrl] và
  /// cùng kiểu Bearer token, để test có thể tiêm [EmsApiService.client] y hệt
  /// mọi lời gọi khác trong app; lỗi được dựng theo cùng khuôn `{error,
  /// message}`/`{error}` mà [EmsApiService] dùng, để nơi gọi bắt
  /// [EmsException] (kể cả 401) như bình thường.
  static Future<List<dynamic>> _getRawList(String path) async {
    final uri = Uri.parse('${EmsApiService.baseUrl}$path');
    final token = AppSession.instance.emsToken;
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    http.Response res;
    try {
      res = await EmsApiService.client
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw EmsException('Không tải được danh sách học kỳ. Vui lòng thử lại.');
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      dynamic decoded;
      try {
        decoded = jsonDecode(res.body);
      } catch (_) {
        decoded = null;
      }
      if (decoded is List) return decoded;
      throw EmsException(
        'Máy chủ trả về dữ liệu không đọc được.',
        statusCode: res.statusCode,
      );
    }

    Map<String, dynamic>? errBody;
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) errBody = decoded;
    } catch (_) {
      errBody = null;
    }
    final rawError = errBody?['error']?.toString();
    final rawMessage = errBody?['message']?.toString();
    throw EmsException(
      rawMessage ?? rawError ?? 'Không kết nối được máy chủ thông tin.',
      code: rawError,
      statusCode: res.statusCode,
    );
  }
}

/// `GET /api/teacher/me/overview` — toàn bộ payload.
class CrmTeacherOverview {
  final CrmTeacherProfile teacher;
  final List<CrmSemester> semesters;
  final String? currentSemester;
  final String? todayDate;
  final List<CrmScheduleSlot> todaySessions;
  final List<CrmScheduleSlot> semesterSlots;
  final CrmTeacherSummary summary;

  const CrmTeacherOverview({
    required this.teacher,
    this.semesters = const [],
    this.currentSemester,
    this.todayDate,
    this.todaySessions = const [],
    this.semesterSlots = const [],
    this.summary = const CrmTeacherSummary(),
  });

  factory CrmTeacherOverview.fromJson(Map<String, dynamic> j) {
    final teacherJson =
        (j['teacher'] as Map?)?.cast<String, dynamic>() ?? const {};
    final semJson = (j['semesters'] as List?) ?? const [];
    final todayJson = (j['today_sessions'] as List?) ?? const [];
    final slotsJson = (j['semester_slots'] as List?) ?? const [];
    final summaryJson =
        (j['summary'] as Map?)?.cast<String, dynamic>() ?? const {};
    return CrmTeacherOverview(
      teacher: CrmTeacherProfile.fromJson(teacherJson),
      semesters: semJson
          .whereType<Map<String, dynamic>>()
          .map(CrmSemester.fromJson)
          .toList(),
      currentSemester: j['current_semester']?.toString(),
      todayDate: j['today_date']?.toString(),
      todaySessions: todayJson
          .whereType<Map<String, dynamic>>()
          .map(CrmScheduleSlot.fromJson)
          .toList(),
      semesterSlots: slotsJson
          .whereType<Map<String, dynamic>>()
          .map(CrmScheduleSlot.fromJson)
          .toList(),
      summary: CrmTeacherSummary.fromJson(summaryJson),
    );
  }
}
