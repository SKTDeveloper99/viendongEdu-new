import '../../services/ems_api_service.dart';
import '../../services/ems_attendance_cache.dart';

/// Outcome of reconciling an offline draft with the roster the server
/// returned. [draftToSave] is non-null only on a conflict: the original draft,
/// kept as it was but no longer queued. Otherwise the caller persists the
/// merged state as the new draft.
class DraftMergeResult {
  const DraftMergeResult({
    required this.marks,
    required this.notes,
    required this.needsReview,
    required this.queued,
    required this.draftToSave,
  });

  final Map<String, String> marks;
  final Map<String, String> notes;
  final bool needsReview;
  final bool queued;
  final EmsAttendanceDraft? draftToSave;
}

/// Server marks/notes with the draft's intended changes laid over them.
///
/// A draft change is applied only when the server row still equals the
/// draft's baseline (or already equals the intended value). A student missing
/// from the roster, a changed server row, or a draft with marks but no
/// baseline is a conflict: nothing is sent automatically and the teacher
/// reviews the current list.
DraftMergeResult mergeDraftWithRoster(
  EmsAttendanceDraft? draft,
  List<EmsRosterStudent> roster,
) {
  var conflict = false;
  final serverMarks = <String, String>{
    for (final s in roster)
      if (s.status != null) s.mssv: s.status!,
  };
  final serverNotes = <String, String>{
    for (final s in roster)
      if (s.note != null) s.mssv: s.note!,
  };
  if (draft != null) {
    final baseline = {for (final s in draft.students) s.mssv: s};
    if (baseline.isEmpty && draft.marks.isNotEmpty) conflict = true;
    for (final old in draft.students) {
      final current = roster.where((s) => s.mssv == old.mssv).firstOrNull;
      if (current == null) {
        conflict = true;
        continue;
      }
      final intended = draft.marks[old.mssv];
      final intendedNote = draft.notes[old.mssv];
      if (intended != old.status || intendedNote != old.note) {
        if ((current.status != old.status && current.status != intended) ||
            (current.note != old.note && current.note != intendedNote)) {
          conflict = true;
        } else {
          if (intended == null) {
            serverMarks.remove(old.mssv);
          } else {
            serverMarks[old.mssv] = intended;
          }
          if (intendedNote == null) {
            serverNotes.remove(old.mssv);
          } else {
            serverNotes[old.mssv] = intendedNote;
          }
        }
      }
    }
  }
  return DraftMergeResult(
    marks: serverMarks,
    notes: serverNotes,
    needsReview: conflict,
    queued: draft?.queued == true && !conflict,
    draftToSave: conflict && draft != null
        ? EmsAttendanceDraft(
            marks: draft.marks,
            notes: draft.notes,
            queued: false,
            students: draft.students,
            session: draft.session,
          )
        : null,
  );
}
