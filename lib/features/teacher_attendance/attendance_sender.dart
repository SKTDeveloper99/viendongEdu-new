import '../../data/teacher_attendance_repository.dart';
import '../../services/ems_api_service.dart';

/// Per-draftKey mutex shared by the roster screen and the background outbox:
/// the same session is never sent twice concurrently.
class AttendanceSendLock {
  AttendanceSendLock._();
  static final Set<String> _held = {};

  static bool tryAcquire(String draftKey) => _held.add(draftKey);
  static void release(String draftKey) => _held.remove(draftKey);
  static bool isHeld(String draftKey) => _held.contains(draftKey);
}

/// 401 = token expired (retryable). Other 4xx = the server said "no";
/// resending the identical request only adds refusal rows to its log.
bool isClientRefusal(EmsException e) {
  final c = e.statusCode;
  return c != null && c >= 400 && c < 500 && c != 401 && c != 408 && c != 429;
}

/// Students that have a server mark but were deselected: sent so the server
/// removes them (otherwise the old mark survives).
List<String> marksToRemove(
  List<EmsRosterStudent> students,
  Map<String, String> marks,
) => students
    .where((s) => s.status != null && !marks.containsKey(s.mssv))
    .map((s) => s.mssv)
    .toList();

/// POST the marks, then read the session back and prove every row survived
/// and every removed one is gone. Throws [EmsException] otherwise. Returns
/// the confirmed roster. Does NOT touch the draft.
Future<({EmsSaveResult result, EmsRoster confirmed})> sendAndVerify(
  TeacherAttendanceRepository repository,
  EmsSession session,
  Map<String, String> marksMap,
  Map<String, String> notes,
  List<EmsRosterStudent> students,
) async {
  final marks = marksMap.entries.map((e) {
    final student = students.where((s) => s.mssv == e.key).firstOrNull;
    return EmsMark(
      mssv: e.key,
      status: e.value,
      note: notes[e.key],
      punchId: student?.punchId,
    );
  }).toList();
  final removeList = marksToRemove(students, marksMap);
  final res = await repository.saveMarks(session, marks, remove: removeList);
  final confirmed = await repository.roster(session);
  final byMssv = {for (final s in confirmed.students) s.mssv: s.status};
  final missing = marks.where((m) => byMssv[m.mssv] != m.status).toList();
  final stillThere = removeList.where((m) => byMssv[m] != null).toList();
  if (stillThere.isNotEmpty) {
    throw EmsException(
      'Máy chủ chưa bỏ điểm danh ${stillThere.length} học viên; ứng dụng sẽ gửi lại.',
    );
  }
  if (missing.isNotEmpty) {
    throw EmsException(
      'Máy chủ chưa xác nhận đủ ${missing.length} học viên; ứng dụng sẽ gửi lại.',
    );
  }
  return (result: res, confirmed: confirmed);
}
