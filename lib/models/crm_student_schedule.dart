// lib/models/crm_student_schedule.dart — typed shapes replacing IMS
// `hocvien/lopmonhoc` (classes) and `hocvien/tkbtheongay` (schedule by day).
//
// Sources (crm-clean, read-only):
//   GET /api/student/me/sections?semester=  → { mssv, sections }
//     lib/portals-student-portal-service.js#getSections
//     repositories/portals-student-portal-repo.js#getSections
//   GET /api/student/me/schedule?semester=  → { mssv, schedule }
//     lib/portals-student-portal-service.js#getSchedule
//     repositories/portals-student-portal-repo.js#getSchedule
//
// Known gaps / behaviour changes vs the old IMS shape (see
// docs/ims_to_crm_student_academic_map.md):
//   - IMS `hocvien/lopmonhoc` had per-class evaluation weights (`tylecc`,
//     `tylegk`, `tyleck`) and a syllabus text (`decuong`). Neither exists on
//     the CRM `sections`/`curriculum` tables the repo query reads from — the
//     old screen's `_tyLeLabel` helper and the `decuong` field were already
//     UNUSED in the widget tree (dead code kept in git), so nothing visibly
//     regresses; they are simply not modelled here.
//   - There is no IMS internal `lmhid` any more (that was an
//     ims_snapshot-only surrogate key). Matching a class to its EMS
//     attendance rows now happens by `section_code` (EMS's own
//     `EmsStudentMark.sectionCode`), which is a more stable join than the old
//     numeric id.
//   - `/me/schedule` is NOT a per-date feed like `hocvien/tkbtheongay?ngay=`.
//     It returns each class's WEEKLY recurring slot for a semester (day_code
//     + start/end time + a `weeks_pattern` string, `tuanhocstr`, whose
//     encoding is undocumented and is deliberately NOT decoded here — see
//     `CrmScheduleItem.occursOn`). A selected date is matched by weekday +
//     falling within [start_date, end_date]; a class that meets on alternating
//     weeks (if `weeks_pattern` encodes that) may over-show on some dates.
//     This is flagged, not hidden.
class CrmStudentSection {
  final String? semesterCode;
  final int? sectionId;
  final String sectionCode;
  final String subjectCode;
  final String subjectName;
  final int credits;
  final String teacherName;
  final DateTime? ngayBatDau;
  final DateTime? ngayKetThuc;
  final int? siSo;

  const CrmStudentSection({
    this.semesterCode,
    this.sectionId,
    this.sectionCode = '',
    this.subjectCode = '',
    this.subjectName = '',
    this.credits = 0,
    this.teacherName = '',
    this.ngayBatDau,
    this.ngayKetThuc,
    this.siSo,
  });

  factory CrmStudentSection.fromJson(Map<String, dynamic> j) =>
      CrmStudentSection(
        semesterCode: j['semester_code']?.toString(),
        sectionId: (j['section_id'] as num?)?.toInt(),
        sectionCode: j['section_code']?.toString() ?? '',
        subjectCode: j['subject_code']?.toString() ?? '',
        subjectName: j['subject_name']?.toString() ?? '',
        credits: (j['credits'] as num?)?.toInt() ?? 0,
        teacherName: j['teacher_name']?.toString() ?? '',
        ngayBatDau: DateTime.tryParse(j['ngay_bat_dau']?.toString() ?? ''),
        ngayKetThuc: DateTime.tryParse(j['ngay_ket_thuc']?.toString() ?? ''),
        siSo: (j['si_so'] as num?)?.toInt(),
      );
}

/// Mã thứ của `ref_days` (migrations/003_phase_a_teachers_schema.sql):
/// '2'..'7' = Thứ 2..Thứ 7, 'CN' = Chủ nhật. `DateTime.weekday` là 1..7
/// (Mon..Sun) — hàm này đổi 1-1 giữa hai hệ.
String dayCodeForWeekday(int weekday) => switch (weekday) {
  1 => '2',
  2 => '3',
  3 => '4',
  4 => '5',
  5 => '6',
  6 => '7',
  _ => 'CN',
};

class CrmScheduleItem {
  final String subjectCode;
  final String subjectName;
  final String? semesterCode;
  final String sectionCode;
  final String? dayCode;
  final String? dayName;
  final String? periodStartName;
  final String? startTime;
  final String? endTime;
  final int? numPeriods;
  final String room;
  final String teacherName;
  final String? weeksPattern;
  final DateTime? startDate;
  final DateTime? endDate;

  const CrmScheduleItem({
    this.subjectCode = '',
    this.subjectName = '',
    this.semesterCode,
    this.sectionCode = '',
    this.dayCode,
    this.dayName,
    this.periodStartName,
    this.startTime,
    this.endTime,
    this.numPeriods,
    this.room = '',
    this.teacherName = '',
    this.weeksPattern,
    this.startDate,
    this.endDate,
  });

  /// Buổi này có rơi vào [date] không — chỉ đối chiếu thứ trong tuần và
  /// khoảng ngày bắt đầu/kết thúc học phần. KHÔNG giải mã `weeksPattern`
  /// (xem ghi chú đầu file) — nếu lớp học cách tuần, kết quả có thể hiện dư.
  bool occursOn(DateTime date) {
    if (dayCode != null && dayCode != dayCodeForWeekday(date.weekday)) {
      return false;
    }
    final d = DateTime(date.year, date.month, date.day);
    if (startDate != null && d.isBefore(startDate!)) return false;
    if (endDate != null && d.isAfter(endDate!)) return false;
    return true;
  }

  factory CrmScheduleItem.fromJson(Map<String, dynamic> j) => CrmScheduleItem(
    subjectCode: j['subject_code']?.toString() ?? '',
    subjectName: j['subject_name']?.toString() ?? '',
    semesterCode: j['semester_code']?.toString(),
    sectionCode: j['section_code']?.toString() ?? '',
    dayCode: j['day_code']?.toString(),
    dayName: j['day_name']?.toString(),
    periodStartName: j['period_start_name']?.toString(),
    startTime: j['start_time']?.toString(),
    endTime: j['end_time']?.toString(),
    numPeriods: (j['num_periods'] as num?)?.toInt(),
    room: j['room_name']?.toString() ?? '',
    teacherName: j['teacher_name']?.toString() ?? '',
    weeksPattern: j['weeks_pattern']?.toString(),
    startDate: DateTime.tryParse(j['start_date']?.toString() ?? ''),
    endDate: DateTime.tryParse(j['end_date']?.toString() ?? ''),
  );
}
