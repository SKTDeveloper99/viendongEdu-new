import 'package:flutter_test/flutter_test.dart';
import 'package:viendongedu2_flutter/data/teacher_attendance_repository.dart';
import 'package:viendongedu2_flutter/features/teacher_attendance/session_list_view_model.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';
import 'package:viendongedu2_flutter/services/ems_attendance_cache.dart';

class _Repo implements TeacherAttendanceRepository {
  _Repo(this.sessions, this.rosters);

  final List<EmsSession> sessions;
  final Map<String, EmsRoster> rosters;
  final drafts = <String, EmsAttendanceDraft>{};

  @override
  Future<List<EmsSession>> mySessions({String? date}) async => sessions;

  @override
  Future<EmsRoster> roster(EmsSession session) async =>
      rosters[session.sessionKey]!;

  @override
  Future<EmsAttendanceDraft?> loadDraft(String key) async => drafts[key];

  @override
  Future<void> saveDraft(
    String key,
    Map<String, String> marks,
    Map<String, String> notes, {
    required bool queued,
    List<EmsRosterStudent> students = const [],
    EmsSession? session,
  }) async {
    drafts[key] = EmsAttendanceDraft(
      marks: Map.of(marks),
      notes: Map.of(notes),
      queued: queued,
      students: students,
      session: session,
      savedAt: DateTime.now(),
    );
  }

  @override
  Future<EmsSaveResult> saveMarks(
    EmsSession session,
    List<EmsMark> marks, {
    List<String> remove = const [],
  }) => throw UnimplementedError();

  @override
  Future<List<EmsStoredDraft>> listDrafts() async => const [];

  @override
  Future<void> clearDraft(String key) async => drafts.remove(key);
}

EmsSession _session(String section, String key) => EmsSession(
  sectionId: section,
  sectionCode: section,
  sessionDate: '2026-10-02',
  sessionKey: key,
  startTime: '09:00',
  endTime: '10:00',
  rosterSize: 1,
);

EmsRosterStudent _student(String id) =>
    EmsRosterStudent(mssv: id, fullName: 'Học viên $id');

void main() {
  test(
    'prefetch keeps three same-slot combined sessions in separate drafts',
    () async {
      final sessions = [
        _session('COMBINED-A', 'key-a'),
        _session('COMBINED-B', 'key-b'),
        _session('COMBINED-C', 'key-c'),
      ];
      final repo = _Repo(sessions, {
        for (final s in sessions)
          s.sessionKey: EmsRoster(
            sessionKey: s.sessionKey,
            students: [_student('student-${s.sectionId}')],
          ),
      });
      repo.drafts['key-b'] = EmsAttendanceDraft(
        marks: const {'student-COMBINED-B': 'absent'},
        notes: const {'student-COMBINED-B': 'đã có'},
        queued: true,
        students: [_student('student-COMBINED-B')],
        session: sessions[1],
      );

      final vm = SessionListViewModel(repo);
      await vm.load();

      expect(vm.error, isNull);
      expect(repo.drafts.keys, unorderedEquals(['key-a', 'key-b', 'key-c']));
      for (final s in sessions) {
        expect(
          repo.drafts[s.sessionKey]!.students.single.mssv,
          'student-${s.sectionId}',
        );
        expect(repo.drafts[s.sessionKey]!.session?.sessionKey, s.sessionKey);
      }
      expect(repo.drafts['key-b']!.marks, {'student-COMBINED-B': 'absent'});
      expect(repo.drafts['key-b']!.notes, {'student-COMBINED-B': 'đã có'});
      expect(repo.drafts['key-b']!.queued, isTrue);
    },
  );
}
