import '../models/teacher_care_student.dart';
import '../services/crm_teacher_api.dart';

typedef CachedCareStudents = ({
  List<TeacherCareStudent> data,
  DateTime savedAt,
  bool fresh,
});

/// Wraps the teacher student-care calls (`GET /api/student-care` and
/// `GET /api/student-care/student/:mssv`). Any failure surfaces as the
/// original exception.
class TeacherStudentsRepository {
  const TeacherStudentsRepository();

  /// Every student this teacher looks after; the last good copy when offline.
  Future<CachedCareStudents> students() => CrmTeacherApi.studentCare();

  /// One student, fresh from the server.
  Future<TeacherCareStudent> student(String mssv) =>
      CrmTeacherApi.studentCareOne(mssv);
}
