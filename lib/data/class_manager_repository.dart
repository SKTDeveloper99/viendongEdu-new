import '../models/crm_teacher_class.dart';
import '../models/crm_teacher_profile.dart';
import '../services/crm_teacher_api.dart';
import 'api/attendance_api.dart';

typedef CachedTeacherClasses = ({
  List<CrmTeacherClass> data,
  DateTime savedAt,
  bool fresh,
});

/// Wraps the calls the teacher "Quản lý lớp" screens make, unchanged:
/// `GET /api/teacher/me/semesters`, `/classes` (ETag-cached),
/// `/schedule/semester`, `/classes/:id/students`, `/classes/:id/attendance`
/// and the EMS `session-marks` read. Any failure surfaces as the original
/// exception.
class ClassManagerRepository {
  const ClassManagerRepository();

  Future<List<CrmSemester>> semesters() => CrmTeacherApi.semesters();

  /// Classes of [semester]; [onStored] paints the stored copy first.
  Future<CachedTeacherClasses> classes({
    required String semester,
    void Function(List<CrmTeacherClass> c, DateTime savedAt)? onStored,
  }) => CrmTeacherApi.classesCached(semester: semester, onStored: onStored);

  /// Schedule slots of [semester]; the only CRM source of `lmhid`.
  Future<List<CrmScheduleSlot>> schedule(String semester) =>
      CrmTeacherApi.scheduleForSemester(semester);

  Future<List<CrmClassStudent>> students(String sectionId) =>
      CrmTeacherApi.classStudents(sectionId);

  Future<List<CrmAttendanceRow>> attendance(String sectionId) =>
      CrmTeacherApi.classAttendance(sectionId);

  /// mssv -> EMS status ('present' | 'late' | 'absent' | 'excused').
  Future<Map<String, String>> sessionMarks(String sessionKey) =>
      AttendanceApi.sessionMarks(sessionKey);

  /// `<lmhid>:<HH-MM>:<yyyy-MM-dd>`, exactly as the server builds it.
  String sessionKey({
    required String lmhId,
    required String date,
    required String startTime,
  }) => AttendanceApi.sessionKeyFor(
    lmhId: lmhId,
    date: date,
    startTime: startTime,
  );
}
