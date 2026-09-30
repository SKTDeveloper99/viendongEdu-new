import 'package:flutter_test/flutter_test.dart';
import 'package:viendongedu2_flutter/data/classes_repository.dart';
import 'package:viendongedu2_flutter/features/classes/class_detail_view_model.dart';
import 'package:viendongedu2_flutter/features/classes/classes_view_model.dart';
import 'package:viendongedu2_flutter/models/crm_student_grades.dart';
import 'package:viendongedu2_flutter/models/crm_student_schedule.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';

class _FakeRepo extends ClassesRepository {
  Future<List<CrmStudentSection>> Function() all;
  Future<SemesterClassesData> Function(String) semester;
  Future<List<EmsStudentMark>> Function() marks;
  final semesterCalls = <String>[];

  _FakeRepo({
    Future<List<CrmStudentSection>> Function()? all,
    Future<SemesterClassesData> Function(String)? semester,
    Future<List<EmsStudentMark>> Function()? marks,
  })  : all = all ?? (() async => const []),
        semester = semester ??
            ((_) async => const SemesterClassesData(sections: [], grades: [])),
        marks = marks ?? (() async => const []);

  @override
  Future<List<CrmStudentSection>> allSections() => all();

  @override
  Future<SemesterClassesData> semesterClasses(String s) {
    semesterCalls.add(s);
    return semester(s);
  }

  @override
  Future<List<EmsStudentMark>> attendance() => marks();
}

CrmStudentSection _s(String sem, String code, String subj) =>
    CrmStudentSection(
      semesterCode: sem,
      sectionCode: code,
      subjectCode: subj,
      subjectName: 'Môn $subj',
      credits: 2,
      teacherName: 'GV Thử Nghiệm',
    );

CrmStudentGrade _g(String? section, String subj, String sem, double? total,
        {double? mid, double? fin}) =>
    CrmStudentGrade(
      sectionCode: section,
      subjectCode: subj,
      semesterCode: sem,
      finalScore: total,
      midtermScore: mid,
      finalExamScore: fin,
    );

EmsStudentMark _m(String date, String status, String section) =>
    EmsStudentMark(sessionDate: date, status: status, sectionCode: section);

void main() {
  group('ClassesViewModel', () {
    test('starts loading', () {
      final vm = ClassesViewModel(_FakeRepo());
      expect(vm.loading, isTrue);
      expect(vm.error, isNull);
      vm.dispose();
    });

    test('loaded: semesters newest first, newest opened, scores attached '
        '(section match, then subject+semester fallback)', () async {
      final repo = _FakeRepo(
        all: () async => [
          _s('251', 'A1', 'TN1'),
          _s('252', 'B1', 'TN2'),
          _s('252', 'B2', 'TN3'),
          _s('', 'X', 'TN9'), // blank semester ignored
        ],
        semester: (sem) async => SemesterClassesData(
          sections: [_s('252', 'B1', 'TN2'), _s('252', 'B2', 'TN3')],
          grades: [
            _g('B1', 'TN2', '252', 8.5, mid: 7.0, fin: 9.0),
            _g(null, 'TN3', '252', 6.0),
            _g(null, 'TN3', '251', 1.0), // other semester: not matched
          ],
        ),
      );
      final vm = ClassesViewModel(repo);

      await vm.fetchSemesters();

      expect(vm.loading, isFalse);
      expect(vm.loadingClasses, isFalse);
      expect(vm.error, isNull);
      expect(vm.semesters.map((s) => s.code), ['252', '251']);
      expect(vm.semesters.first.ten, 'Học kỳ 2, 2025 - 2026');
      expect(vm.selected!.code, '252');
      expect(repo.semesterCalls, ['252']);
      expect(vm.classes.map((c) => c.lmhma), ['B1', 'B2']);
      expect(vm.classes[0].tongdiem, 8.5);
      expect(vm.classes[0].diemgk, 7.0);
      expect(vm.classes[0].diemck, 9.0);
      expect(vm.classes[1].tongdiem, 6.0);
      expect(vm.classes[1].diemgk, isNull);
      vm.dispose();
    });

    test('selectSemester swaps the class list; refreshSelected reloads it',
        () async {
      final repo = _FakeRepo(
        all: () async => [_s('251', 'A1', 'TN1'), _s('252', 'B1', 'TN2')],
        semester: (sem) async => SemesterClassesData(
            sections: [_s(sem, sem == '251' ? 'A1' : 'B1', 'TN')], grades: []),
      );
      final vm = ClassesViewModel(repo);
      await vm.fetchSemesters();

      await vm.selectSemester(vm.semesters.last);
      expect(vm.selected!.code, '251');
      expect(vm.classes.single.lmhma, 'A1');

      await vm.refreshSelected();
      expect(repo.semesterCalls, ['252', '251', '251']);
      vm.dispose();
    });

    test('empty: no enrolments → nothing selected, empty list', () async {
      final vm = ClassesViewModel(_FakeRepo());
      await vm.fetchSemesters();
      expect(vm.loading, isFalse);
      expect(vm.error, isNull);
      expect(vm.semesters, isEmpty);
      expect(vm.selected, isNull);
      expect(vm.classes, isEmpty);
      vm.dispose();
    });

    test('semester list error: message kept, not unauthorized; retry recovers',
        () async {
      var fail = true;
      final vm = ClassesViewModel(_FakeRepo(all: () async {
        if (fail) throw EmsException('Máy chủ lỗi', statusCode: 500);
        return [_s('252', 'B1', 'TN2')];
      }));

      await vm.fetchSemesters();
      expect(vm.loading, isFalse);
      expect(vm.error, 'Máy chủ lỗi');
      expect(vm.unauthorized, isFalse);

      fail = false;
      await vm.fetchSemesters();
      expect(vm.error, isNull);
      expect(vm.semesters, hasLength(1));
      vm.dispose();
    });

    test('a failing class load leaves an empty list, no error state',
        () async {
      final vm = ClassesViewModel(_FakeRepo(
        all: () async => [_s('252', 'B1', 'TN2')],
        semester: (_) async => throw EmsException('boom', statusCode: 500),
      ));
      await vm.fetchSemesters();
      expect(vm.error, isNull);
      expect(vm.loadingClasses, isFalse);
      expect(vm.classes, isEmpty);
      expect(vm.unauthorized, isFalse);
      vm.dispose();
    });

    test('401 raises the unauthorized flag; a later success clears it',
        () async {
      final auth = EmsException('Hết phiên', statusCode: 401);
      var fail = true;
      final vm = ClassesViewModel(_FakeRepo(all: () async {
        if (fail) throw auth;
        return [];
      }));

      await vm.fetchSemesters();
      expect(vm.unauthorized, isTrue);
      expect(vm.authError, same(auth));
      expect(vm.loading, isFalse);

      fail = false;
      await vm.fetchSemesters();
      expect(vm.unauthorized, isFalse);
      expect(vm.authError, isNull);
      vm.dispose();
    });

    test('401 while loading a semester also raises the flag', () async {
      final auth = EmsException('Hết phiên', statusCode: 401);
      final vm = ClassesViewModel(_FakeRepo(
        all: () async => [_s('252', 'B1', 'TN2')],
        semester: (_) async => throw auth,
      ));
      await vm.fetchSemesters();
      expect(vm.authError, same(auth));
      vm.dispose();
    });

    test('a load finishing after dispose does not notify', () async {
      final vm = ClassesViewModel(_FakeRepo());
      final future = vm.fetchSemesters();
      vm.dispose();
      await future;
    });
  });

  group('ClassDetailViewModel', () {
    test('loaded: only this section, oldest first, statuses mapped',
        () async {
      final vm = ClassDetailViewModel(
        _FakeRepo(marks: () async => [
              _m('2026-03-16T00:00:00.000Z', 'excused', 'B1'),
              _m('2026-03-02T00:00:00.000Z', 'present', 'B1'),
              _m('2026-03-09T00:00:00.000Z', 'absent', 'B1'),
              _m('2026-03-23T00:00:00.000Z', 'late', 'B1'),
              _m('2026-03-02T00:00:00.000Z', 'present', 'OTHER'),
            ]),
        sectionCode: 'B1',
      );
      expect(vm.loading, isTrue);

      await vm.load();

      expect(vm.loading, isFalse);
      expect(vm.sessions.map((s) => s.ngay),
          ['2026-03-02', '2026-03-09', '2026-03-16', '2026-03-23']);
      expect(vm.present, 2); // present + late
      expect(vm.absent, 1);
      expect(vm.pending, 1); // excused has no hiendien
      expect(vm.sessions[2].baonghi, isTrue);
      vm.dispose();
    });

    test('empty: no marks for the section', () async {
      final vm = ClassDetailViewModel(_FakeRepo(), sectionCode: 'B1');
      await vm.load();
      expect(vm.loading, isFalse);
      expect(vm.sessions, isEmpty);
      vm.dispose();
    });

    test('error: stops loading with no sessions, not unauthorized', () async {
      final vm = ClassDetailViewModel(
        _FakeRepo(marks: () async => throw EmsException('x', statusCode: 500)),
        sectionCode: 'B1',
      );
      await vm.load();
      expect(vm.loading, isFalse);
      expect(vm.sessions, isEmpty);
      expect(vm.unauthorized, isFalse);
      vm.dispose();
    });

    test('401 raises the unauthorized flag', () async {
      final auth = EmsException('Hết phiên', statusCode: 401);
      final vm = ClassDetailViewModel(
        _FakeRepo(marks: () async => throw auth),
        sectionCode: 'B1',
      );
      await vm.load();
      expect(vm.unauthorized, isTrue);
      expect(vm.authError, same(auth));
      expect(vm.loading, isFalse);
      vm.dispose();
    });
  });
}
