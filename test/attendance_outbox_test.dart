import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viendongedu2_flutter/data/teacher_attendance_repository.dart';
import 'package:viendongedu2_flutter/features/teacher_attendance/attendance_outbox.dart';
import 'package:viendongedu2_flutter/features/teacher_attendance/attendance_sender.dart';
import 'package:viendongedu2_flutter/features/teacher_attendance/roster_view_model.dart';
import 'package:viendongedu2_flutter/models/crm_identity.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';
import 'package:viendongedu2_flutter/services/ems_attendance_cache.dart';

const _a = 'TEST260001';
const _b = 'TEST260002';
const _session = EmsSession(
  sectionId: 'section-1',
  sectionCode: 'LOP-THU',
  sessionDate: '2026-09-08',
  sessionKey: 'k1',
);

EmsRosterStudent _s(String mssv, [String? status]) =>
    EmsRosterStudent(mssv: mssv, fullName: 'Học viên $mssv', status: status);

/// In-memory store. [server] is what the roster returns; a successful
/// saveMarks applies the marks to it so the read-back verification passes.
class _Repo implements TeacherAttendanceRepository {
  _Repo(this.server);
  List<EmsRosterStudent> server;
  final drafts = <String, EmsAttendanceDraft>{};
  int sends = 0;
  Object? nextError;
  bool rosterDown = false;

  @override
  Future<List<EmsSession>> mySessions({String? date}) async => const [];

  @override
  Future<EmsRoster> roster(EmsSession s) async {
    if (rosterDown) throw EmsException('offline');
    return EmsRoster(sessionKey: 'k1', students: server);
  }

  @override
  Future<EmsSaveResult> saveMarks(
    EmsSession s,
    List<EmsMark> marks, {
    List<String> remove = const [],
  }) async {
    sends++;
    final e = nextError;
    if (e != null) throw e;
    final m = {for (final x in marks) x.mssv: x.status};
    server = [
      for (final st in server)
        EmsRosterStudent(
          mssv: st.mssv,
          fullName: st.fullName,
          status: m[st.mssv],
        ),
    ];
    return EmsSaveResult(saved: marks.length);
  }

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
  Future<List<EmsStoredDraft>> listDrafts() async => [
    for (final e in drafts.entries) EmsStoredDraft(e.key, e.value),
  ];

  @override
  Future<void> clearDraft(String key) async => drafts.remove(key);
}

void _queue(_Repo r, {String key = 'k1', bool withSession = true}) {
  r.drafts[key] = EmsAttendanceDraft(
    marks: {_a: 'present', _b: 'absent'},
    notes: const {},
    queued: true,
    students: [_s(_a), _s(_b)],
    session: withSession ? _session : null,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Repo repo;
  late AttendanceOutbox outbox;

  setUp(() {
    repo = _Repo([_s(_a), _s(_b)]);
    outbox = AttendanceOutbox(repository: repo, isEligible: () => true);
  });

  test('drain sends a queued draft, clears it and announces the key', () async {
    _queue(repo);
    final done = <String>[];
    outbox.finished.listen(done.add);
    await outbox.drain();
    await Future<void>.delayed(Duration.zero);
    expect(repo.sends, 1);
    expect(repo.drafts, isEmpty);
    expect(outbox.pendingCount.value, 0);
    expect(done, ['k1']);
  });

  test('pendingCount reflects the queue and refreshCount recounts', () async {
    _queue(repo);
    _queue(repo, key: 'k2');
    await outbox.refreshCount();
    expect(outbox.pendingCount.value, 2);
    repo.drafts.remove('k2');
    await outbox.refreshCount();
    expect(outbox.pendingCount.value, 1);
  });

  test('server row changed under the draft: conflict, never sent', () async {
    _queue(repo);
    repo.server = [_s(_a, 'absent'), _s(_b)]; // baseline had _a unmarked
    await outbox.drain();
    expect(repo.sends, 0);
    expect(repo.drafts['k1']?.queued, isFalse);
    expect(repo.drafts['k1']?.marks, {_a: 'present', _b: 'absent'});
    expect(outbox.pendingCount.value, 0);
  });

  test('422 punch conflict: unqueued, kept, not retried', () async {
    _queue(repo);
    repo.nextError = EmsPunchConflict(
      'cần lý do',
      students: const [EmsPunchedStudent(mssv: _a)],
      statusCode: 422,
    );
    await outbox.drain();
    await outbox.drain();
    expect(repo.sends, 1);
    expect(repo.drafts['k1']?.queued, isFalse);
    expect(repo.drafts['k1']?.marks[_a], 'present');
  });

  test('4xx refusal: unqueued and not retried', () async {
    _queue(repo);
    repo.nextError = EmsException('cấm', statusCode: 403);
    await outbox.drain();
    await outbox.drain();
    expect(repo.sends, 1);
    expect(repo.drafts['k1']?.queued, isFalse);
  });

  for (final code in [500, 503, 401, 408, 429, null]) {
    test('status $code stays queued and retries next tick', () async {
      _queue(repo);
      repo.nextError = EmsException('x', statusCode: code);
      await outbox.drain();
      expect(repo.drafts['k1']?.queued, isTrue);
      expect(outbox.pendingCount.value, 1);
      repo.nextError = null;
      await outbox.drain();
      expect(repo.sends, 2);
      expect(repo.drafts, isEmpty);
    });
  }

  test('roster unreachable: stays queued, nothing sent', () async {
    _queue(repo);
    repo.rosterDown = true;
    await outbox.drain();
    expect(repo.sends, 0);
    expect(repo.drafts['k1']?.queued, isTrue);
  });

  test(
    'offline roster save queues; reconnect sends through outbox exactly once',
    () async {
      repo.drafts['k1'] = EmsAttendanceDraft(
        marks: const {_a: 'present', _b: 'absent'},
        notes: const {},
        queued: false,
        students: [_s(_a), _s(_b)],
        session: _session,
        savedAt: DateTime(2026, 9, 8, 7, 5),
      );
      repo.rosterDown = true;
      final vm = RosterViewModel(repo, _session, outbox: outbox);
      await vm.load();

      await vm.save(
        RosterPrompts(
          confirmUnmarked: (_, _) async => true,
          askReasons: (_, _, _) async => null,
          toast: (_, {good = false}) {},
        ),
      );

      expect(repo.sends, 0);
      expect(repo.drafts['k1']?.queued, isTrue);
      expect(outbox.pendingCount.value, 1);

      repo.rosterDown = false;
      await outbox.drain();
      await Future<void>.delayed(Duration.zero);
      expect(repo.sends, 1);

      await outbox.drain();
      expect(repo.sends, 1);
      vm.dispose();
    },
  );

  test('old draft without session identity is left for the screen', () async {
    _queue(repo, withSession: false);
    await outbox.drain();
    expect(repo.sends, 0);
    expect(repo.drafts['k1']?.queued, isTrue);
  });

  test('lock held (screen saving): drainer skips that key', () async {
    _queue(repo);
    expect(AttendanceSendLock.tryAcquire('k1'), isTrue);
    await outbox.drain();
    expect(repo.sends, 0);
    AttendanceSendLock.release('k1');
    await outbox.drain();
    expect(repo.sends, 1);
  });

  test(
    'lock held (drainer sending): screen save does not double-send',
    () async {
      final vm = RosterViewModel(repo, _session);
      await vm.load();
      vm.select(_a, 'present');
      expect(AttendanceSendLock.tryAcquire('k1'), isTrue);
      final toasts = <String>[];
      await vm.save(
        RosterPrompts(
          confirmUnmarked: (_, _) async => true,
          askReasons: (_, _, _) async => null,
          toast: (m, {good = false}) => toasts.add(m),
        ),
      );
      AttendanceSendLock.release('k1');
      expect(repo.sends, 0);
      expect(toasts, isNotEmpty);
      vm.dispose();
    },
  );

  test('not eligible (logout / student): nothing runs', () async {
    _queue(repo);
    final off = AttendanceOutbox(repository: repo, isEligible: () => false);
    await off.drain();
    expect(repo.sends, 0);
    expect(off.pendingCount.value, 0);
  });

  test('stop() zeroes the count', () async {
    _queue(repo);
    await outbox.refreshCount();
    expect(outbox.pendingCount.value, 1);
    outbox.stop();
    expect(outbox.pendingCount.value, 0);
  });

  group('account scoping (real cache)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      AppSession.instance.emsToken = 't';
      AppSession.instance.role = CrmRole.teacher;
      AppSession.instance.teacherId = 'teacher-1';
    });
    tearDown(() {
      AppSession.instance.emsToken = null;
      AppSession.instance.role = null;
      AppSession.instance.teacherId = null;
    });

    test('listDrafts returns only the current account, with session', () async {
      await EmsAttendanceCache.saveDraft(
        'k1',
        {_a: 'present'},
        {},
        queued: true,
        session: _session,
      );
      AppSession.instance.teacherId = 'teacher-2';
      expect(await EmsAttendanceCache.listDrafts(), isEmpty);
      await EmsAttendanceCache.saveDraft(
        'k9',
        {_b: 'absent'},
        {},
        queued: true,
      );
      final mine = await EmsAttendanceCache.listDrafts();
      expect(mine.map((d) => d.draftKey), ['k9']);
      expect(mine.single.draft.session, isNull);
      AppSession.instance.teacherId = 'teacher-1';
      final first = await EmsAttendanceCache.listDrafts();
      expect(first.single.draftKey, 'k1');
      expect(first.single.draft.session?.sectionId, 'section-1');
    });
  });
}
