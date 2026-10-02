import 'package:flutter_test/flutter_test.dart';
import 'package:viendongedu2_flutter/data/teacher_attendance_repository.dart';
import 'package:viendongedu2_flutter/features/teacher_attendance/roster_view_model.dart';
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

/// Records every call in order. [rosters] are served one per roster() call
/// (the last one repeats); [posts] answer saveMarks in order.
class _FakeRepo implements TeacherAttendanceRepository {
  _FakeRepo({
    required this.rosters,
    this.posts = const [],
    this.rosterSessionKey = 'k1',
    this.rosterError,
  });

  final List<List<EmsRosterStudent>> rosters;
  final List<Object> posts; // EmsSaveResult or an exception to throw
  final String rosterSessionKey;
  final EmsException? rosterError;
  EmsAttendanceDraft? draft;
  final log = <String>[];
  final sent = <List<EmsMark>>[];
  final removed = <List<String>>[];
  int _r = 0;
  int _p = 0;

  @override
  Future<List<EmsSession>> mySessions({String? date}) async => const [];

  @override
  Future<EmsRoster> roster(EmsSession s) async {
    log.add('roster');
    if (rosterError != null) throw rosterError!;
    final list = rosters[_r < rosters.length ? _r : rosters.length - 1];
    _r++;
    return EmsRoster(sessionKey: rosterSessionKey, students: list);
  }

  @override
  Future<EmsSaveResult> saveMarks(
    EmsSession s,
    List<EmsMark> marks, {
    List<String> remove = const [],
  }) async {
    log.add('saveMarks');
    sent.add(marks);
    removed.add(remove);
    final p = posts[_p++];
    if (p is Exception) throw p;
    return p as EmsSaveResult;
  }

  @override
  Future<EmsAttendanceDraft?> loadDraft(String key) async {
    log.add('loadDraft:$key');
    return draft;
  }

  @override
  Future<void> saveDraft(
    String key,
    Map<String, String> marks,
    Map<String, String> notes, {
    required bool queued,
    List<EmsRosterStudent> students = const [],
    EmsSession? session,
  }) async {
    log.add('saveDraft:queued=$queued');
    draft = EmsAttendanceDraft(
      marks: Map.of(marks),
      notes: Map.of(notes),
      queued: queued,
      students: students,
      session: session,
    );
  }

  @override
  Future<List<EmsStoredDraft>> listDrafts() async => const [];

  @override
  Future<void> clearDraft(String key) async {
    log.add('clearDraft');
    draft = null;
  }
}

EmsRosterStudent _s(String mssv, [String? status, String? note]) =>
    EmsRosterStudent(
      mssv: mssv,
      fullName: 'Học viên $mssv',
      status: status,
      note: note,
    );

EmsPunchConflict _conflict() => EmsPunchConflict(
  'cần lý do',
  students: const [EmsPunchedStudent(mssv: _a)],
  statusCode: 422,
);

class _Ui {
  _Ui({this.confirm = true, this.reasons});
  final bool confirm;
  final Map<String, String>? reasons;
  final toasts = <String>[];
  int confirms = 0;
  int asks = 0;
  RosterPrompts get prompts => RosterPrompts(
    confirmUnmarked: (undecided, chosen) async {
      confirms++;
      return confirm;
    },
    askReasons: (people, initial, nameOf) async {
      asks++;
      return reasons;
    },
    toast: (m, {good = false}) => toasts.add(m),
  );
}

void main() {
  test(
    'invariant 1: draft is read before the roster, then persisted',
    () async {
      final repo = _FakeRepo(
        rosters: [
          [_s(_a)],
        ],
      );
      await RosterViewModel(repo, _session).load();
      expect(repo.log, ['loadDraft:k1', 'roster', 'saveDraft:queued=false']);
    },
  );

  test('invariant 2: every mark change persists the draft', () async {
    final repo = _FakeRepo(
      rosters: [
        [_s(_a), _s(_b)],
      ],
    );
    final vm = RosterViewModel(repo, _session);
    await vm.load();
    repo.log.clear();
    vm.select(_a, 'present');
    vm.select(_a, null);
    vm.markAllPresent();
    vm.resetToScanned();
    vm.markScannedPresent();
    await Future<void>.delayed(Duration.zero);
    expect(repo.log, List.filled(5, 'saveDraft:queued=false'));
  });

  test(
    'offline open uses matching draft students, marks and saved time',
    () async {
      final repo =
          _FakeRepo(rosters: const [], rosterError: EmsException('offline'))
            ..draft = EmsAttendanceDraft(
              marks: const {_a: 'present'},
              notes: const {_a: 'từ bản nháp'},
              queued: false,
              students: [_s(_a), _s(_b)],
              session: _session,
              savedAt: DateTime(2026, 9, 8, 7, 5),
            );
      final vm = RosterViewModel(repo, _session);

      await vm.load();

      expect(vm.error, isNull);
      expect(vm.students.map((s) => s.mssv), [_a, _b]);
      expect(vm.marks, {_a: 'present'});
      expect(
        vm.offlineBanner,
        'Đang ngoại tuyến – danh sách lưu lúc 07:05. '
        'Điểm danh sẽ tự gửi khi có mạng.',
      );
    },
  );

  test(
    'offline without a usable draft keeps the current error state',
    () async {
      final repo = _FakeRepo(
        rosters: const [],
        rosterError: EmsException('offline'),
      );
      final vm = RosterViewModel(repo, _session);

      await vm.load();

      expect(vm.students, isEmpty);
      expect(vm.offlineBanner, isNull);
      expect(vm.error, contains('Không có kết nối'));
    },
  );

  test(
    'online session-key mismatch never falls back to a saved draft',
    () async {
      final repo =
          _FakeRepo(
              rosterSessionKey: 'wrong-session',
              rosters: [
                [_s(_a)],
              ],
            )
            ..draft = EmsAttendanceDraft(
              marks: const {_a: 'present'},
              notes: const {},
              queued: false,
              students: [_s(_a)],
              session: _session,
            );
      final vm = RosterViewModel(repo, _session);

      await vm.load();

      expect(vm.students, isEmpty);
      expect(vm.offlineBanner, isNull);
      expect(vm.error, contains('một buổi học khác'));
    },
  );

  test('offline draft for a different session is never rendered', () async {
    final repo =
        _FakeRepo(rosters: const [], rosterError: EmsException('offline'))
          ..draft = EmsAttendanceDraft(
            marks: const {_a: 'present'},
            notes: const {},
            queued: false,
            students: [_s(_a)],
            session: const EmsSession(
              sectionId: 'other',
              sectionCode: 'OTHER',
              sessionDate: '2026-09-08',
              sessionKey: 'other-key',
            ),
          );
    final vm = RosterViewModel(repo, _session);

    await vm.load();

    expect(vm.students, isEmpty);
    expect(vm.offlineBanner, isNull);
    expect(vm.error, contains('Không có kết nối'));
  });

  for (final status in [400, 401, 403, 404, 408, 409, 422, 429]) {
    test('a $status roster answer never falls back to a saved draft', () async {
      final repo =
          _FakeRepo(
              rosters: const [],
              rosterError: EmsException('máy chủ trả lời', statusCode: status),
            )
            ..draft = EmsAttendanceDraft(
              marks: const {_a: 'present'},
              notes: const {},
              queued: false,
              students: [_s(_a)],
              session: _session,
            );
      final vm = RosterViewModel(repo, _session);

      await vm.load();

      expect(vm.students, isEmpty);
      expect(vm.offlineBanner, isNull);
      expect(vm.error, contains('máy chủ trả lời'));
    });
  }

  group('invariant 3: save', () {
    test('cancelled unmarked confirm sends nothing', () async {
      final repo = _FakeRepo(
        rosters: [
          [_s(_a), _s(_b)],
        ],
      );
      final vm = RosterViewModel(repo, _session);
      await vm.load();
      vm.select(_a, 'present');
      repo.log.clear();
      final ui = _Ui(confirm: false);
      await vm.save(ui.prompts);
      expect(ui.confirms, 1);
      expect(repo.log, isEmpty);
    });

    test('draft queued before send; cleared only after read-back', () async {
      final repo = _FakeRepo(
        rosters: [
          [_s(_a, 'absent')],
          [_s(_a, 'present')],
        ],
        posts: [const EmsSaveResult(saved: 1, late: true)],
      );
      final vm = RosterViewModel(repo, _session);
      await vm.load();
      vm.select(_a, 'present');
      await Future<void>.delayed(Duration.zero);
      repo.log.clear();
      final ui = _Ui();
      await vm.save(ui.prompts);
      expect(repo.log, [
        'saveDraft:queued=true',
        'saveMarks',
        'roster',
        'clearDraft',
      ]);
      expect(ui.toasts, ['Đã lưu 1 dòng (ghi muộn)']);
      expect(vm.queued, isFalse);
      expect(vm.saving, isFalse);
    });

    test('still-present removal keeps the draft queued', () async {
      final repo = _FakeRepo(
        rosters: [
          [_s(_a, 'present')],
        ],
        posts: [const EmsSaveResult(saved: 0)],
      );
      final vm = RosterViewModel(repo, _session);
      await vm.load();
      vm.select(_a, null);
      final ui = _Ui();
      await vm.save(ui.prompts);
      expect(repo.removed.single, [_a]);
      expect(repo.log, isNot(contains('clearDraft')));
      expect(repo.draft?.queued, isTrue);
      expect(
        ui.toasts.single,
        contains('Máy chủ chưa bỏ điểm danh 1 học viên'),
      );
      expect(ui.toasts.single, startsWith('CHƯA GỬI. Đã giữ trên máy'));
    });
  });

  group('invariant 4: punch conflict', () {
    test('dismissed dialog holds without resending', () async {
      final repo = _FakeRepo(
        rosters: [
          [_s(_a)],
        ],
        posts: [_conflict()],
      );
      final vm = RosterViewModel(repo, _session);
      await vm.load();
      vm.select(_a, 'absent');
      final ui = _Ui(reasons: null);
      await vm.save(ui.prompts);
      await Future<void>.delayed(Duration.zero);
      expect(repo.sent, hasLength(1));
      expect(ui.asks, 1);
      expect(vm.queued, isFalse);
      expect(vm.needsReason?.single.mssv, _a);
      expect(repo.draft?.queued, isFalse);
      expect(ui.toasts.single, startsWith('CHƯA LƯU — 1 học viên'));
    });

    test('second conflict after reasons holds; asked once', () async {
      final repo = _FakeRepo(
        rosters: [
          [_s(_a)],
        ],
        posts: [_conflict(), _conflict()],
      );
      final vm = RosterViewModel(repo, _session);
      await vm.load();
      vm.select(_a, 'absent');
      final ui = _Ui(reasons: {_a: 'không vào lớp'});
      await vm.save(ui.prompts);
      await Future<void>.delayed(Duration.zero);
      expect(repo.sent, hasLength(2));
      expect(repo.sent.last.single.note, 'không vào lớp');
      expect(ui.asks, 1);
      expect(vm.needsReason, isNotNull);
      expect(repo.draft?.queued, isFalse);
      expect(repo.draft?.notes, {_a: 'không vào lớp'});
    });
  });

  test('invariant 5: client refusal classification', () {
    bool r(int? c) =>
        RosterViewModel.isClientRefusal(EmsException('x', statusCode: c));
    expect([400, 403, 404, 409, 422].every(r), isTrue);
    expect([null, 401, 408, 429, 500, 503].any(r), isFalse);
  });

  test(
    'wrong generic 45-student roster is rejected before rendering',
    () async {
      const selected = EmsSession(
        sectionId: 'section-linh',
        sectionCode: 'MON-A',
        sessionDate: '2026-10-05',
        startTime: '09:00',
        endTime: '10:00',
        sessionKey: '101:09-00:2026-10-05',
        rosterSize: 2,
      );
      final repo = _FakeRepo(
        rosterSessionKey: selected.sessionKey,
        rosters: [
          [
            for (var i = 0; i < 45; i++)
              _s('OLD${i.toString().padLeft(2, '0')}'),
          ],
        ],
      );
      final vm = RosterViewModel(repo, selected);

      await vm.load();

      expect(vm.students, isEmpty);
      expect(vm.error, contains('45/2'));
      expect(repo.log, ['loadDraft:${selected.sessionKey}', 'roster']);
    },
  );

  test('roster with missing or duplicate identity is rejected', () async {
    final invalidRosters = [
      [_s(_a), EmsRosterStudent(mssv: _b, fullName: '  ')],
      [_s(_a), EmsRosterStudent(mssv: _a, fullName: 'Tên trùng mã')],
      [_s(_a), EmsRosterStudent(mssv: '  ', fullName: 'Thiếu mã')],
    ];
    for (final students in invalidRosters) {
      final repo = _FakeRepo(rosters: [students]);
      final vm = RosterViewModel(repo, _session);

      await vm.load();

      expect(vm.students, isEmpty);
      expect(vm.error, contains('thiếu tên/mã học viên hoặc có mã bị trùng'));
      vm.dispose();
    }
  });
}
