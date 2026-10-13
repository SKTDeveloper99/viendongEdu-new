import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:viendongedu2_flutter/data/teacher_students_repository.dart';
import 'package:viendongedu2_flutter/features/teacher_students/student_detail_view_model.dart';
import 'package:viendongedu2_flutter/features/teacher_students/teacher_students_view_model.dart';
import 'package:viendongedu2_flutter/models/teacher_care_student.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';

import 'helpers/teacher_care_fixture.dart';

class CareStateRepository extends TeacherStudentsRepository {
  Future<CachedCareStudents> Function()? listRead;
  Future<TeacherCareStudent> Function()? oneRead;
  @override
  Future<CachedCareStudents> students() => listRead!();
  @override
  Future<TeacherCareStudent> student(String mssv) => oneRead!();
}

void main() {
  final savedAt = DateTime(2026, 10, 13, 10);

  test(
    'summary counts unique students, including overlapping classes, never money',
    () async {
      final owing = careStudentJson();
      owing['dossier']['money_one'] = careMoneyJson(owes: true);
      owing['dossier']['sections'][0]['absent'] = 1;
      final extra = Map<String, dynamic>.from(
        owing['dossier']['sections'][0] as Map,
      )..['section_id'] = 'another-section';
      owing['dossier']['sections'].add(extra);
      owing['can_review_sections'].add('another-section');
      final repo = CareStateRepository()
        ..listRead = () async => (
          data: [TeacherCareStudent.fromJson(owing), careStudent(1)],
          savedAt: savedAt,
          fresh: true,
        );
      final vm = TeacherStudentsViewModel(repo);
      addTearDown(vm.dispose);
      await vm.load();
      expect(vm.owingCount, 1);
      expect(vm.attentionCount, 1);
      expect(vm.students, hasLength(2));
      expect(vm.classes, hasLength(2));
    },
  );

  for (final status in [401, 403, 404]) {
    test(
      'list $status removes the in-memory copy and hides raw error wording',
      () async {
        final repo = CareStateRepository()
          ..listRead = () async =>
              (data: [careStudent()], savedAt: savedAt, fresh: true);
        final vm = TeacherStudentsViewModel(repo);
        addTearDown(vm.dispose);
        await vm.load();
        repo.listRead = () async => throw EmsException(
          'IMS CRM bảng kê Kế toán staff_reason',
          statusCode: status,
        );
        await vm.load();
        expect(vm.students, isEmpty);
        expect(vm.classes, isEmpty);
        expect(vm.staleSince, isNull);
        expect(vm.error, isNot(contains('staff_reason')));
        expect(vm.unauthorized, status == 401);
        repo.listRead = () async =>
            (data: [careStudent()], savedAt: savedAt, fresh: false);
        await vm.load();
        expect(vm.students, isEmpty);
      },
    );
    test(
      'detail $status blocks the copy and stays blocked until a good read',
      () async {
        final repo = CareStateRepository()
          ..oneRead = () async =>
              throw EmsException('CRM staff_reason', statusCode: status);
        final vm = StudentDetailViewModel(
          repo,
          careStudent(),
          savedAt: savedAt,
        );
        addTearDown(vm.dispose);
        await vm.refresh();
        expect(vm.blocked, isTrue);
        expect(vm.error, isNot(contains('CRM')));
        expect(vm.authError != null, status == 401);
        repo.oneRead = () async => throw StateError('offline');
        await vm.refresh();
        expect(vm.blocked, isTrue);
        repo.oneRead = () async => careStudent();
        await vm.refresh();
        expect(vm.blocked, isFalse);
      },
    );
  }

  test('failed list refresh labels its in-memory last good copy', () async {
    final repo = CareStateRepository()
      ..listRead = () async =>
          (data: [careStudent()], savedAt: savedAt, fresh: true);
    final vm = TeacherStudentsViewModel(repo);
    addTearDown(vm.dispose);
    await vm.load();
    repo.listRead = () async => throw StateError('network');
    await vm.load();
    expect(vm.students, hasLength(1));
    expect(vm.staleSince, savedAt);
    expect(vm.error, isNotNull);
  });

  test(
    'slow read keeps list loading; repeated loads do not race; dispose is safe',
    () async {
      final pending = Completer<CachedCareStudents>();
      var calls = 0;
      final repo = CareStateRepository()
        ..listRead = () {
          calls++;
          return pending.future;
        };
      final vm = TeacherStudentsViewModel(repo);
      final read = vm.load();
      await vm.load();
      expect(calls, 1);
      expect(vm.loading, isTrue);
      expect(vm.refreshing, isTrue);
      vm.dispose();
      pending.complete((
        data: <TeacherCareStudent>[],
        savedAt: savedAt,
        fresh: true,
      ));
      await read;
    },
  );

  test(
    'slow detail refresh keeps the last copy; failure marks it old; retry recovers',
    () async {
      final pending = Completer<TeacherCareStudent>();
      var calls = 0;
      final repo = CareStateRepository()
        ..oneRead = () {
          calls++;
          return pending.future;
        };
      final vm = StudentDetailViewModel(repo, careStudent(), savedAt: savedAt);
      addTearDown(vm.dispose);
      final read = vm.refresh();
      await vm.refresh();
      expect(calls, 1);
      expect(vm.refreshing, isTrue);
      expect(vm.student.money.known, isTrue);
      pending.completeError(StateError('offline'));
      await read;
      expect(vm.staleSince, savedAt);
      expect(vm.error, isNotNull);
      repo.oneRead = () async => TeacherCareStudent.fromJson(
        careStudentJson()..['can_review_sections'] = [],
      );
      await vm.refresh();
      expect(vm.staleSince, isNull);
      expect(vm.error, isNull);
      expect(vm.student.mySectionIds, isEmpty);
    },
  );

  test(
    'mismatched detail identity preserves and labels the right copy',
    () async {
      final repo = CareStateRepository()..oneRead = () async => careStudent(1);
      final vm = StudentDetailViewModel(repo, careStudent(), savedAt: savedAt);
      addTearDown(vm.dispose);
      await vm.refresh();
      expect(vm.student.mssv, 'TEST25-0');
      expect(vm.staleSince, savedAt);
      expect(vm.error, isNotNull);
    },
  );
}
