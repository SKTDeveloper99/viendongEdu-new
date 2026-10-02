import 'package:flutter/foundation.dart';

import '../../data/teacher_attendance_repository.dart';
import '../../services/ems_api_service.dart';
import 'draft_merge.dart';

/// Today's EMS sessions of the signed-in teacher.
class SessionListViewModel extends ChangeNotifier {
  SessionListViewModel(this.repository);

  final TeacherAttendanceRepository repository;

  bool _loading = true;
  String? _error;
  List<EmsSession> _sessions = const [];
  bool _disposed = false;

  bool get loading => _loading;
  String? get error => _error;
  List<EmsSession> get sessions => _sessions;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    _notify();
    try {
      final s = await repository.mySessions();
      if (_disposed) return;
      await Future.wait(s.map(_prefetchRoster));
      if (_disposed) return;
      _sessions = s;
      _loading = false;
      _notify();
    } on EmsException catch (e) {
      if (_disposed) return;
      _sessions = const [];
      _error = 'Không có kết nối. Kiểm tra mạng và thử lại. ${e.message}';
      _loading = false;
      _notify();
    }
  }

  Future<void> _prefetchRoster(EmsSession session) async {
    try {
      final roster = await repository.roster(session);
      if (roster.sessionKey.trim().isEmpty ||
          roster.sessionKey != session.sessionKey ||
          (session.rosterSize > 0 &&
              roster.students.length != session.rosterSize)) {
        return;
      }
      final seen = <String>{};
      if (roster.students.any((student) {
        final mssv = student.mssv.trim();
        return mssv.isEmpty ||
            student.fullName.trim().isEmpty ||
            !seen.add(mssv);
      })) {
        return;
      }
      final key = session.sessionKey.isNotEmpty
          ? session.sessionKey
          : '${session.sectionId}:${session.startTime ?? 'na'}:'
                '${session.sessionDate}';
      final existing = await repository.loadDraft(key);
      final merged = mergeDraftWithRoster(existing, roster.students);
      final keep = merged.draftToSave;
      await repository.saveDraft(
        key,
        keep?.marks ?? merged.marks,
        keep?.notes ?? merged.notes,
        queued: keep?.queued ?? merged.queued,
        students: keep?.students ?? roster.students,
        session: session,
      );
    } catch (_) {
      // The online session list remains usable when one roster cannot prefetch.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
