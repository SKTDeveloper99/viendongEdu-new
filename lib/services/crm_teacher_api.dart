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
  /// (`res.json(rows)`, KHÔNG bọc trong `{data: ...}`). [EmsApiService.send]
  /// trả `dynamic` (Map hoặc List) nên dùng thẳng được ở đây, không cần
  /// client HTTP riêng nữa.
  static Future<List<CrmSemester>> semesters() async {
    final body = await EmsApiService.send('GET', '/teacher/me/semesters');
    if (body is! List) {
      throw EmsException('Máy chủ trả về dữ liệu không đọc được.');
    }
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
