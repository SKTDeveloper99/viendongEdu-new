import '../../models/ems_attendance_models.dart';
import 'attendance_sender.dart' show marksToRemove;
import 'roster_view_model.dart';

/// Whether what the teacher sees is what the server holds. Shown at all
/// times next to "Lưu điểm danh": a toast alone left teachers pressing Lưu
/// 2–3 times, and a save that never left the phone looked the same as one
/// that did (Linh, 20MNC_N3 29/10/2026).
enum RosterSaveStatus { none, unsaved, saved }

/// Compares the marks on screen with the server's `status` of each student.
/// A server mark the teacher has cleared also counts as unsaved. An offline
/// roster is never shown as saved.
RosterSaveStatus rosterSaveStatus(
  List<EmsRosterStudent> students,
  Map<String, String> marks, {
  bool offline = false,
}) {
  if (students.isEmpty) return RosterSaveStatus.none;
  final differs =
      marksToRemove(students, marks).isNotEmpty ||
      students.any((s) {
        final m = marks[s.mssv];
        return m != null && m != s.status;
      });
  if (differs || offline) {
    return marks.isEmpty ? RosterSaveStatus.none : RosterSaveStatus.unsaved;
  }
  return students.any((s) => s.status != null)
      ? RosterSaveStatus.saved
      : RosterSaveStatus.none;
}

/// Latest server save time among [students], when known.
DateTime? latestMarkedAt(List<EmsRosterStudent> students) {
  DateTime? latest;
  for (final s in students) {
    final t = s.markedAt;
    if (t != null && (latest == null || t.isAfter(latest))) latest = t;
  }
  return latest;
}

extension RosterSaveState on RosterViewModel {
  RosterSaveStatus get saveStatus =>
      rosterSaveStatus(students, marks, offline: usingOfflineRoster);
  DateTime? get savedAt => latestMarkedAt(students);
}
