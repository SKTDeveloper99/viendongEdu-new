// lib/services/crm_student_api.dart — student academic reads against the CRM
// ("EMS"), replacing every `ApiService` (IMS, api_service.dart) call the
// student-facing screens used to make.
//
// Deliberately thin: every request goes through `EmsApiService.send`, the ONE
// shared network path (base URL, Bearer token, timeout, error decoding —
// including the 401 = "session expired" contract) that the rest of the app
// already uses for điểm danh and Bảng tin. This file does not open its own
// http.Client and does not duplicate `EmsApiService`'s error handling; it
// only adds the paths and typed parsing for the student academic surface.
//
// Server contracts read from crm-clean (read-only) on 2026-09-24:
//   routes/portals/student-portal.js (mounted under /api/student)
//   routes/portals/student-exams.js  (mounted under /api/student, its own
//     router — see docs/api/mobile-ims-replacement-S3.md in that repo's
//     worktree .claude/worktrees/agent-a86dcd5eb8ad283d1)
//
// A 401 from any call here means the CRM session (not an IMS one — none
// exists any more) has expired. Screens must catch
// `EmsException(statusCode: 401)`, call `AppSession.instance.clear()`, and
// navigate to '/login' — see lib/services/crm_session_guard.dart for the one
// shared helper.
import '../models/crm_student_profile.dart';
import '../models/crm_student_grades.dart';
import '../models/crm_student_graduation_summary.dart';
import '../models/crm_student_schedule.dart';
import '../models/crm_student_exams.dart';
import 'ems_api_service.dart';

class CrmStudentApi {
  CrmStudentApi._();

  /// `GET /api/student/me` → { student }.
  /// Thay `hocvien/user/info` (`ApiService.getUserInfo`).
  static Future<CrmStudentProfile> me() async {
    final body = await EmsApiService.send('GET', '/student/me')
        as Map<String, dynamic>;
    final student = body['student'];
    if (student is! Map<String, dynamic>) {
      throw EmsException('Máy chủ không trả về hồ sơ học viên.');
    }
    return CrmStudentProfile.fromJson(student);
  }

  /// `GET /api/student/me/grades` → { mssv, summary, grades }.
  /// Thay `hocvien/bangdiemtongket` (`ApiService.getBangDiem`).
  static Future<CrmStudentGradesView> grades() async {
    final body = await EmsApiService.send('GET', '/student/me/grades')
        as Map<String, dynamic>;
    return CrmStudentGradesView.fromJson(body);
  }

  /// `GET /api/student/me/remaining-subjects` → { mssv, has_curriculum,
  /// subjects, all_required_count, passed_count }.
  /// Thay `hocvien/monhocchuadat` (`ApiService.getMonHocChuaDat`). Dùng cho
  /// tab "Chưa học" của bảng điểm — cho tổng quan chương trình (X/Y môn,
  /// điểm trung bình, đủ điều kiện) dùng [graduationSummary] thay vì cộng
  /// dồn danh sách này ở client.
  static Future<CrmRemainingSubjectsView> remainingSubjects() async {
    final body =
        await EmsApiService.send('GET', '/student/me/remaining-subjects')
            as Map<String, dynamic>;
    return CrmRemainingSubjectsView.fromJson(body);
  }

  /// `GET /api/student/me/graduation-summary` → { student, academic,
  /// attendance, tuition, eligibility, remaining_subjects }. Only `academic`
  /// and `remaining_subjects` are parsed (see
  /// lib/models/crm_student_graduation_summary.dart — tuition/finance is out
  /// of this slice's scope). Thay `hocvien/thongkectdt`
  /// (`ApiService.getThongKeCTDT`): the overview tab's "X/Y môn", average,
  /// and eligibility now come straight from this endpoint instead of being
  /// summed client-side over /me/grades.
  static Future<CrmGraduationSummary> graduationSummary() async {
    final body =
        await EmsApiService.send('GET', '/student/me/graduation-summary')
            as Map<String, dynamic>;
    return CrmGraduationSummary.fromJson(body);
  }

  /// `GET /api/student/me/sections?semester=` → { mssv, sections }.
  /// Thay `hocvien/lopmonhoc` (`ApiService.getLopMonHoc`).
  static Future<List<CrmStudentSection>> sections({String? semester}) async {
    final body = await EmsApiService.send(
      'GET',
      '/student/me/sections',
      query: (semester == null || semester.isEmpty)
          ? null
          : {'semester': semester},
    ) as Map<String, dynamic>;
    final list = body['sections'];
    if (list is! List) return const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(CrmStudentSection.fromJson)
        .toList();
  }

  /// `GET /api/student/me/schedule?semester=` → { mssv, schedule }.
  /// Thay `hocvien/tkbtheongay` (`ApiService.getScheduleByDate` /
  /// `getTodaySchedule`) — xem ghi chú "weeks_pattern" trong
  /// lib/models/crm_student_schedule.dart về khác biệt theo-tuần so với
  /// theo-ngày của IMS.
  static Future<List<CrmScheduleItem>> schedule({String? semester}) async {
    final body = await EmsApiService.send(
      'GET',
      '/student/me/schedule',
      query: (semester == null || semester.isEmpty)
          ? null
          : {'semester': semester},
    ) as Map<String, dynamic>;
    final list = body['schedule'];
    if (list is! List) return const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(CrmScheduleItem.fromJson)
        .toList();
  }

  /// `GET /api/student/me/exams?semester=` → { semester_code, exams }.
  /// Thay `hocvien/lichthi` (`ApiService.getExams`). Bỏ trống [semester]
  /// (hoặc truyền `'all'`) để lấy TOÀN BỘ lịch sử, mới nhất trước — hợp đồng
  /// server kể từ 2026-09-25; truyền một mã học kỳ cụ thể để lọc đúng kỳ đó.
  /// Xem docs/ims_to_crm_student_academic_map.md.
  static Future<CrmStudentExamsView> exams({String? semester}) async {
    final body = await EmsApiService.send(
      'GET',
      '/student/me/exams',
      query: (semester == null || semester.isEmpty)
          ? null
          : {'semester': semester},
    ) as Map<String, dynamic>;
    return CrmStudentExamsView.fromJson(body);
  }
}
