import '../../models/crm_student_grades.dart';
import '../../models/crm_student_schedule.dart';

// CRM has no dedicated "danh sách học kỳ" endpoint for students (only
// GET /api/teacher/me/semesters exists, teacher-only — verified by reading
// routes/portals/teacher-portal.js and routes/portals/student-portal.js).
// The list is DERIVED from the distinct semester_code values seen in
// /api/student/me/sections, exactly as documented in
// docs/ims_to_crm_student_academic_map.md.
class ClassSemester {
  final String code;
  final String ten;

  /// Earliest section start in this semester (null when unknown).
  final DateTime? start;
  const ClassSemester({required this.code, required this.ten, this.start});
}

// CRM /me/sections has no per-class evaluation weights (tylecc/tylegk/tyleck)
// or syllabus text (decuong) — those were already dead fields in the old
// screen and are not modelled. Score breakdown (diemgk/diemck/tongdiem) is
// filled in from /me/grades, matched by section_code.
class ClassItem {
  final String? semesterCode;
  final int? sectionId;
  final String lmhma; // section_code
  final String mhma; // subject_code
  final String mhten; // subject_name
  final int? sotinchi; // credits
  final String gvten; // teacher_name
  final double? tongdiem;
  final double? diemgk; // midterm_score
  final double? diemck; // final_exam_score
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? examDate;
  final String? room;

  const ClassItem({
    this.semesterCode,
    required this.sectionId,
    required this.lmhma,
    required this.mhma,
    required this.mhten,
    required this.sotinchi,
    required this.gvten,
    this.tongdiem,
    this.diemgk,
    this.diemck,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? ngayBatDau,
    DateTime? ngayKetThuc,
    this.examDate,
    this.room,
  }) : startDate = startDate ?? ngayBatDau,
       endDate = endDate ?? ngayKetThuc;

  DateTime? get ngayBatDau => startDate;
  DateTime? get ngayKetThuc => endDate;
  String get batDauText => fmtCalendarDay(startDate);
  String get ketThucText => fmtCalendarDay(endDate);

  factory ClassItem.fromSection(
    CrmStudentSection s, {
    CrmStudentGrade? grade,
    DateTime? timetableEnd,
  }) => ClassItem(
    semesterCode: s.semesterCode,
    sectionId: s.sectionId,
    lmhma: s.sectionCode,
    mhma: s.subjectCode,
    mhten: s.subjectName,
    sotinchi: s.credits,
    gvten: s.teacherName,
    tongdiem: grade?.finalScore,
    diemgk: grade?.midtermScore,
    diemck: grade?.finalExamScore,
    startDate: _placeholder(s) ? null : s.ngayBatDau,
    endDate: timetableEnd ?? (_placeholder(s) ? null : s.ngayKetThuc),
    examDate: s.examDate,
    room: s.room,
  );

  static bool _placeholder(CrmStudentSection s) =>
      s.ngayBatDau != null && s.ngayBatDau == s.ngayKetThuc;

  // CRM không có điểm "chuyên cần" (diemcc) riêng — chỉ midterm/final.
  double? get diemcc => null;

  bool get hasGrades =>
      tongdiem != null || diemcc != null || diemgk != null || diemck != null;
}

/// A calendar date, with an explicit unknown state.
String fmtCalendarDay(DateTime? d) => d == null
    ? 'N/A'
    : '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/${d.year}';

/// One attendance session of a class, as shown on the detail page.
class AttendanceSession {
  /// Date-only text (`yyyy-MM-dd`) to avoid day shifts from UTC midnight.
  final String ngay;

  /// true = present/late, false = absent, null = not yet marked.
  final bool? hiendien;
  final bool baonghi;
  const AttendanceSession({
    required this.ngay,
    required this.hiendien,
    required this.baonghi,
  });

  DateTime? get date => DateTime.tryParse(ngay);
}
