import '../services/ems_api_service.dart';
import '../services/ems_attendance_cache.dart';
import 'api/attendance_api.dart';

/// Wraps what the teacher "Điểm danh EMS" screens use, unchanged: the EMS
/// `my-sessions`, `roster` and `marks` calls and the account-scoped offline
/// draft store. Any failure surfaces as the original exception.
class TeacherAttendanceRepository {
  const TeacherAttendanceRepository();

  Future<List<EmsSession>> mySessions() => AttendanceApi.mySessions();

  Future<EmsRoster> roster(EmsSession session) => AttendanceApi.roster(session);

  Future<EmsSaveResult> saveMarks(
    EmsSession session,
    List<EmsMark> marks, {
    List<String> remove = const [],
  }) => AttendanceApi.saveMarks(session, marks, remove: remove);

  Future<EmsAttendanceDraft?> loadDraft(String draftKey) =>
      EmsAttendanceCache.loadDraft(draftKey);

  Future<void> saveDraft(
    String draftKey,
    Map<String, String> marks,
    Map<String, String> notes, {
    required bool queued,
    List<EmsRosterStudent> students = const [],
    EmsSession? session,
  }) => EmsAttendanceCache.saveDraft(
    draftKey,
    marks,
    notes,
    queued: queued,
    students: students,
    session: session,
  );

  Future<List<EmsStoredDraft>> listDrafts() => EmsAttendanceCache.listDrafts();

  Future<void> clearDraft(String draftKey) =>
      EmsAttendanceCache.clearDraft(draftKey);
}
