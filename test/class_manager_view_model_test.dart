import 'package:flutter_test/flutter_test.dart';
import 'package:viendongedu2_flutter/data/class_manager_repository.dart';
import 'package:viendongedu2_flutter/features/class_manager/class_detail_sheet_view_model.dart';
import 'package:viendongedu2_flutter/features/class_manager/class_manager_view_model.dart';
import 'package:viendongedu2_flutter/features/class_manager/session_detail_view_model.dart';
import 'package:viendongedu2_flutter/models/crm_teacher_class.dart';
import 'package:viendongedu2_flutter/models/crm_teacher_profile.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';

CrmTeacherClass _lop(String id, String code, {int enrolled = 3}) =>
    CrmTeacherClass(
      sectionId: id,
      sectionCode: code,
      subjectCode: 'TN101',
      subjectName: 'Môn thử nghiệm',
      enrolledStudents: enrolled,
    );

CrmAttendanceRow _row(String sid, String date, String mssv, String status) =>
    CrmAttendanceRow(
      sessionId: sid,
      date: date,
      startTime: '07:00',
      endTime: '09:30',
      mssv: mssv,
      fullName: 'SV $mssv',
      status: status,
    );

class _FakeRepo extends ClassManagerRepository {
  Future<List<CrmSemester>> Function() semestersFn = () async => [
    const CrmSemester(id: 252, ma: '252', ten: 'HK2'),
    const CrmSemester(id: 261, ma: '261', ten: 'HK1'),
  ];
  Future<CachedTeacherClasses> Function(
    String semester,
    void Function(List<CrmTeacherClass>, DateTime)? onStored,
  )
  classesFn = (sem, _) async => (
    data: [_lop('sec-$sem', 'TN$sem')],
    savedAt: DateTime(2026),
    fresh: true,
  );
  Future<List<CrmScheduleSlot>> Function(String) scheduleFn = (sem) async => [
    CrmScheduleSlot(lmhId: '900', lmhMa: 'TN$sem'),
  ];
  Future<List<CrmClassStudent>> Function(String) studentsFn = (_) async => [
    const CrmClassStudent(
      enrollmentId: 'e1',
      mssv: 'TEST260001',
      fullName: 'An Thử Nghiệm',
    ),
  ];
  Future<List<CrmAttendanceRow>> Function(String) attendanceFn = (_) async => [
    _row('s2', '2026-03-09', 'TEST260002', 'present'),
    _row('s1', '2026-03-02', 'TEST260001', 'present'),
    _row('s1', '2026-03-02', 'TEST260002', 'absent'),
  ];
  Future<Map<String, String>> Function(String) marksFn = (_) async => {
    'TEST260001': 'present',
    'TEST260002': 'late',
  };
  final requestedKeys = <String>[];

  @override
  Future<List<CrmSemester>> semesters() => semestersFn();
  @override
  Future<CachedTeacherClasses> classes({
    required String semester,
    void Function(List<CrmTeacherClass>, DateTime)? onStored,
  }) => classesFn(semester, onStored);
  @override
  Future<List<CrmScheduleSlot>> schedule(String semester) =>
      scheduleFn(semester);
  @override
  Future<List<CrmClassStudent>> students(String sectionId) =>
      studentsFn(sectionId);
  @override
  Future<List<CrmAttendanceRow>> attendance(String sectionId) =>
      attendanceFn(sectionId);
  @override
  Future<Map<String, String>> sessionMarks(String sessionKey) {
    requestedKeys.add(sessionKey);
    return marksFn(sessionKey);
  }
}

void main() {
  group('ClassManagerViewModel', () {
    test(
      'loads semesters newest first and the first semester classes',
      () async {
        final vm = ClassManagerViewModel(_FakeRepo());
        await vm.fetchSemesters();

        expect(vm.semesters.map((s) => s.ma), ['261', '252']);
        expect(vm.selected, same(vm.semesters.first));
        expect(vm.classes.map((c) => c.sectionCode), ['TN261']);
        expect(vm.lmhIdOf(vm.classes.first), '900');
        expect(vm.loadingSemesters, isFalse);
        expect(vm.loadingClasses, isFalse);
        expect(vm.staleAt, isNull);
        expect(vm.error, isNull);
      },
    );

    test('selecting another semester reloads its classes', () async {
      final vm = ClassManagerViewModel(_FakeRepo());
      await vm.fetchSemesters();
      await vm.selectSemester(vm.semesters.last);

      expect(vm.selected!.ma, '252');
      expect(vm.classes.map((c) => c.sectionCode), ['TN252']);
    });

    test('stored copy: staleAt set when refresh was not fresh', () async {
      final repo = _FakeRepo()
        ..classesFn = (sem, onStored) async {
          onStored?.call([_lop('s', 'OLD')], DateTime(2026, 1, 1));
          return (
            data: [_lop('s', 'OLD')],
            savedAt: DateTime(2026, 1, 1),
            fresh: false,
          );
        };
      final vm = ClassManagerViewModel(repo);
      await vm.fetchSemesters();

      expect(vm.staleAt, DateTime(2026, 1, 1));
      expect(vm.classes.single.sectionCode, 'OLD');
    });

    test('semesters error is shown; retry reloads', () async {
      final repo = _FakeRepo()..semestersFn = () async => throw 'boom';
      final vm = ClassManagerViewModel(repo);
      await vm.fetchSemesters();

      expect(vm.error, 'boom');
      expect(vm.loadingSemesters, isFalse);
      expect(vm.unauthorized, isFalse);

      repo.semestersFn = () async => [
        const CrmSemester(id: 261, ma: '261', ten: 'HK1'),
      ];
      vm.retry();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(vm.error, isNull);
      expect(vm.classes, isNotEmpty);
    });

    test('classes error keeps the selected semester', () async {
      final repo = _FakeRepo();
      final vm = ClassManagerViewModel(repo);
      await vm.fetchSemesters();
      repo.scheduleFn = (_) async => throw 'net';
      await vm.selectSemester(vm.semesters.last);
      expect(vm.error, 'net');
      expect(vm.loadingClasses, isFalse);
      expect(vm.selected!.ma, '252');
    });

    test('401 raises the auth flag instead of an error', () async {
      final repo = _FakeRepo()
        ..semestersFn = () async => throw EmsException('no', statusCode: 401);
      final vm = ClassManagerViewModel(repo);
      await vm.fetchSemesters();

      expect(vm.unauthorized, isTrue);
      expect(vm.error, isNull);
    });
  });

  group('ClassDetailSheetViewModel', () {
    test('students tab loads lazily and once', () async {
      var calls = 0;
      final repo = _FakeRepo();
      final inner = repo.studentsFn;
      repo.studentsFn = (id) {
        calls++;
        return inner(id);
      };
      final vm = ClassDetailSheetViewModel(
        repo,
        lop: _lop('sec-a', 'TN261A'),
        lmhId: '900',
      );
      vm.onTabSelected(0);
      expect(calls, 0);
      vm.onTabSelected(1);
      await Future<void>.delayed(Duration.zero);

      expect(vm.students.single.mssv, 'TEST260001');
      expect(vm.loadingStudents, isFalse);
      vm.onTabSelected(1);
      expect(calls, 1);
    });

    test('attendance groups by session, totals by name, EMS counts', () async {
      final repo = _FakeRepo();
      final vm = ClassDetailSheetViewModel(
        repo,
        lop: _lop('sec-a', 'TN261A', enrolled: 3),
        lmhId: '900',
        now: () => DateTime.utc(2026, 3, 5),
      );
      await vm.loadAttendance();

      // Sorted by date; s2 (03-09) is in the future and never asked.
      expect(vm.sessions.map((s) => s.sessionId), ['s1', 's2']);
      expect(repo.requestedKeys, ['900:07-00:2026-03-02']);
      expect(vm.totals.map((t) => '${t.mssv} ${t.present}/${t.total}'), [
        'TEST260001 1/1',
        'TEST260002 1/2',
      ]);
      final s1 = vm.summaryOf(vm.sessions[0]);
      expect(s1.marked, isTrue);
      expect(s1.countText, '2 / 3 có mặt (EMS)');
      final s2 = vm.summaryOf(vm.sessions[1]);
      expect(s2.marked, isFalse);
      expect(s2.countText, '1 / 3 có mặt trên CRM — chưa xác nhận trên EMS');
    });

    test('no lmhid: EMS is never asked', () async {
      final repo = _FakeRepo();
      final vm = ClassDetailSheetViewModel(
        repo,
        lop: _lop('sec-a', 'TN261A'),
        lmhId: null,
        now: () => DateTime.utc(2026, 12, 1),
      );
      await vm.loadAttendance();

      expect(repo.requestedKeys, isEmpty);
      expect(vm.sessionKeyOf(vm.sessions.first), isNull);
      expect(
        vm.summaryOf(vm.sessions.first).countText,
        '1 / 3 có mặt trên CRM — chưa xác nhận trên EMS',
      );
    });

    test(
      'EMS failure is swallowed; attendance error and 401 surface',
      () async {
        final repo = _FakeRepo()..marksFn = (_) async => throw 'ems down';
        final vm = ClassDetailSheetViewModel(
          repo,
          lop: _lop('sec-a', 'TN261A'),
          lmhId: '900',
          now: () => DateTime.utc(2026, 12, 1),
        );
        await vm.loadAttendance();
        expect(vm.attendanceError, isNull);
        expect(vm.summaryOf(vm.sessions.first).marked, isFalse);

        repo.attendanceFn = (_) async => throw 'boom';
        await vm.loadAttendance();
        expect(vm.attendanceError, 'boom');

        repo.attendanceFn = (_) async =>
            throw EmsException('no', statusCode: 401);
        await vm.loadAttendance();
        expect(vm.unauthorized, isTrue);
      },
    );

    test('students error is exposed', () async {
      final repo = _FakeRepo()..studentsFn = (_) async => throw 'boom';
      final vm = ClassDetailSheetViewModel(
        repo,
        lop: _lop('sec-a', 'TN261A'),
        lmhId: '900',
      );
      await vm.loadStudents();
      expect(vm.studentsError, 'boom');
      expect(vm.loadingStudents, isFalse);
    });
  });

  group('SessionDetailViewModel', () {
    final rows = [
      _row('s1', '2026-03-02', 'TEST260001', 'present'),
      _row('s1', '2026-03-02', 'TEST260002', 'present'),
      _row('s1', '2026-03-02', 'TEST260003', 'present'),
    ];
    SessionDetailViewModel make(_FakeRepo repo, {String? key = 'k'}) {
      final s = ClassDetailSheetViewModel.groupBySession(rows).single;
      return SessionDetailViewModel(repo, session: s, sessionKey: key);
    }

    test('marks loaded: present/late/excused count as present', () async {
      final repo = _FakeRepo()
        ..marksFn = (_) async => {'TEST260001': 'late', 'TEST260002': 'absent'};
      final vm = make(repo);
      await vm.load();

      expect(vm.loading, isFalse);
      expect(vm.presentCount, 1);
      expect(vm.absentCount, 1);
      expect(vm.unmarkedCount, 1);
      expect(vm.presentOf(vm.students[2]), isNull);
    });

    test('no session key: nobody marked, EMS not called', () async {
      final repo = _FakeRepo();
      final vm = make(repo, key: null);
      await vm.load();

      expect(repo.requestedKeys, isEmpty);
      expect(vm.unmarkedCount, 3);
    });

    test('error is exposed and retry recovers', () async {
      final repo = _FakeRepo()..marksFn = (_) async => throw 'boom';
      final vm = make(repo);
      await vm.load();
      expect(vm.error, 'boom');

      repo.marksFn = (_) async => {'TEST260001': 'present'};
      await vm.load();
      expect(vm.error, isNull);
      expect(vm.presentCount, 1);
    });
  });
}
