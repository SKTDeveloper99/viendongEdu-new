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
  const ClassSemester({required this.code, required this.ten});
}

// CRM /me/sections has no per-class evaluation weights (tylecc/tylegk/tyleck)
// or syllabus text (decuong) — those were already dead fields in the old
// screen and are not modelled. Score breakdown (diemgk/diemck/tongdiem) is
// filled in from /me/grades, matched by section_code.
class ClassItem {
  final int? sectionId;
  final String lmhma; // section_code
  final String mhma; // subject_code
  final String mhten; // subject_name
  final int sotinchi; // credits
  final String gvten; // teacher_name
  final double? tongdiem;
  final double? diemgk; // midterm_score
  final double? diemck; // final_exam_score

  const ClassItem({
    required this.sectionId,
    required this.lmhma,
    required this.mhma,
    required this.mhten,
    required this.sotinchi,
    required this.gvten,
    this.tongdiem,
    this.diemgk,
    this.diemck,
  });

  factory ClassItem.fromSection(CrmStudentSection s, {CrmStudentGrade? grade}) =>
      ClassItem(
        sectionId: s.sectionId,
        lmhma: s.sectionCode,
        mhma: s.subjectCode,
        mhten: s.subjectName,
        sotinchi: s.credits,
        gvten: s.teacherName,
        tongdiem: grade?.finalScore,
        diemgk: grade?.midtermScore,
        diemck: grade?.finalExamScore,
      );

  // CRM không có điểm "chuyên cần" (diemcc) riêng — chỉ midterm/final.
  double? get diemcc => null;

  bool get hasGrades =>
      tongdiem != null || diemcc != null || diemgk != null || diemck != null;
}

/// One attendance session of a class, as shown on the detail page.
class AttendanceSession {
  /// Date-only text (`yyyy-MM-dd`) to avoid day shifts from UTC midnight.
  final String ngay;

  /// true = present/late, false = absent, null = not yet marked.
  final bool? hiendien;
  final bool baonghi;
  const AttendanceSession(
      {required this.ngay, required this.hiendien, required this.baonghi});

  DateTime? get date => DateTime.tryParse(ngay);
}
