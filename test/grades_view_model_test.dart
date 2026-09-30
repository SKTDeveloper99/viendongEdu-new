import 'package:flutter_test/flutter_test.dart';
import 'package:viendongedu2_flutter/data/grades_repository.dart';
import 'package:viendongedu2_flutter/features/grades/grades_view_model.dart';
import 'package:viendongedu2_flutter/models/crm_student_grades.dart';
import 'package:viendongedu2_flutter/models/crm_student_graduation_summary.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';

class _FakeRepo extends GradesRepository {
  final Future<GradesData> Function() _load;
  int calls = 0;
  _FakeRepo(this._load);

  @override
  Future<GradesData> load() {
    calls++;
    return _load();
  }
}

CrmStudentGrade _g(int id, String sem, String code, double? score) =>
    CrmStudentGrade(
      gradeId: id,
      semesterCode: sem,
      subjectCode: code,
      subjectName: 'Môn $code',
      credits: 2,
      finalScore: score,
      recordedAt: DateTime(2026, 1, id),
    );

GradesData _data({
  List<CrmStudentGrade> grades = const [],
  List<CrmRemainingSubject> remaining = const [],
}) =>
    GradesData(
      grades: CrmStudentGradesView(
        mssv: 'TEST260001',
        summary: const CrmStudentGradesSummary(),
        grades: grades,
      ),
      summary: CrmGraduationSummary(
        academic: const CrmAcademicSummary(requiredSubjects: 5),
        remainingSubjects: remaining,
      ),
    );

void main() {
  test('starts in loading state', () {
    final vm = GradesViewModel(_FakeRepo(() async => _data()));
    expect(vm.loading, isTrue);
    expect(vm.error, isNull);
    expect(vm.unauthorized, isFalse);
    vm.dispose();
  });

  test('loaded: scored sorted best first, unscored split, retakes numbered, '
      'remaining statuses mapped', () async {
    final vm = GradesViewModel(_FakeRepo(() async => _data(
          grades: [
            _g(1, '251', 'TN1', 9.0),
            _g(2, '251', 'TN2', 3.0),
            _g(3, '252', 'TN2', 6.0),
            _g(4, '252', 'TN3', null),
          ],
          remaining: const [
            CrmRemainingSubject(
                subjectCode: 'R1', credits: 2, completionStatus: 'pending'),
            CrmRemainingSubject(
                subjectCode: 'R2', credits: 3, completionStatus: 'failed'),
            CrmRemainingSubject(subjectCode: 'R3', credits: 1),
          ],
        )));
    var notified = 0;
    vm.addListener(() => notified++);

    await vm.refresh();

    expect(vm.loading, isFalse);
    expect(vm.error, isNull);
    expect(vm.stats!.requiredSubjects, 5);
    expect(vm.grades.map((g) => g.tongdiem), [9.0, 6.0, 3.0]);
    expect(vm.grades.map((g) => g.solan), [1, 2, 1]);
    expect(vm.ungraded.map((g) => g.mhma), ['TN3']);
    expect(vm.remaining.map((r) => r.status), [1, 2, 0]);
    expect(vm.remaining.map((r) => r.code), ['R1', 'R2', 'R3']);
    expect(notified, greaterThanOrEqualTo(2)); // loading, then result
    vm.dispose();
  });

  test('empty account: loaded with nothing to show', () async {
    final vm = GradesViewModel(_FakeRepo(() async => _data()));
    await vm.refresh();
    expect(vm.loading, isFalse);
    expect(vm.error, isNull);
    expect(vm.grades, isEmpty);
    expect(vm.ungraded, isEmpty);
    expect(vm.remaining, isEmpty);
    vm.dispose();
  });

  test('error: message kept, not unauthorized; retry recovers', () async {
    var fail = true;
    final repo = _FakeRepo(() async {
      if (fail) throw EmsException('Máy chủ lỗi', statusCode: 500);
      return _data(grades: [_g(1, '251', 'TN1', 8.0)]);
    });
    final vm = GradesViewModel(repo);

    await vm.refresh();
    expect(vm.loading, isFalse);
    expect(vm.error, 'Máy chủ lỗi');
    expect(vm.unauthorized, isFalse);

    fail = false;
    await vm.refresh();
    expect(vm.error, isNull);
    expect(vm.grades, hasLength(1));
    expect(repo.calls, 2);
    vm.dispose();
  });

  test('401 raises the unauthorized flag with the original error; '
      'a later success clears it', () async {
    final auth = EmsException('Hết phiên', statusCode: 401);
    var fail = true;
    final vm = GradesViewModel(_FakeRepo(() async {
      if (fail) throw auth;
      return _data();
    }));

    await vm.refresh();
    expect(vm.unauthorized, isTrue);
    expect(vm.authError, same(auth));
    expect(vm.loading, isFalse);

    fail = false;
    await vm.refresh();
    expect(vm.unauthorized, isFalse);
    expect(vm.authError, isNull);
    vm.dispose();
  });

  test('a load finishing after dispose does not notify', () async {
    final vm = GradesViewModel(_FakeRepo(() async => _data()));
    final future = vm.refresh();
    vm.dispose();
    await future; // would throw "used after being disposed" if it notified
  });
}
