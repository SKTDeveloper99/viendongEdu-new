import 'package:flutter_test/flutter_test.dart';
import 'package:viendongedu2_flutter/features/teacher_students/care_format.dart';
import 'package:viendongedu2_flutter/features/teacher_students/teacher_students_view_model.dart';
import 'package:viendongedu2_flutter/models/teacher_care_student.dart';

import 'helpers/teacher_care_fixture.dart';

void main() {
  test('M-54 positive lawful balance does not invent an M-32 reminder', () {
    final m = CareMoney.fromJson(careMoneyJson());
    expect(m.known, isTrue);
    expect(m.balance, 1500000);
    expect(m.owes, isFalse);
    expect(CareMoney.fromJson(careMoneyJson(owes: true)).owes, isTrue);
  });

  for (final key in ['owedTotal', 'paid', 'balance']) {
    for (final invalid in [null, 'bad', double.nan, double.infinity, -1, 1.5]) {
      test('invalid $key ($invalid) is unknown with no partial figures', () {
        final m = CareMoney.fromJson({
          ...careMoneyJson(owes: true),
          key: invalid,
        });
        expect(m.known, isFalse);
        expect(m.owedTotal, isNull);
        expect(m.paid, isNull);
        expect(m.balance, isNull);
        expect(m.owes, isFalse);
      });
    }
  }
  test('numeric strings accepted; staff ledger and explanation ignored', () {
    final json = careStudentJson();
    final d = json['dossier'] as Map<String, dynamic>;
    d['money_one'] = {
      ...careMoneyJson(),
      'owedTotal': '4000000',
      'paid': '2500000',
    };
    expect(TeacherCareStudent.fromJson(json).money.known, isTrue);
    d.remove('money_one');
    final student = TeacherCareStudent.fromJson(json);
    expect(student.money, CareMoney.unknown);
    d['money_one'] = {...careMoneyJson(owes: true), 'money_known': false};
    expect(TeacherCareStudent.fromJson(json).money, CareMoney.unknown);
  });

  test(
    'M-52 overpayment is retained as a word status with Vietnam as-of time',
    () {
      final m = CareMoney.fromJson({
        ...careMoneyJson(),
        'paid': 4500000,
        'balance': 0,
      });
      expect(m.overpaid, isTrue);
      expect(m.owes, isFalse);
      expect(formatCareTime(m.asOf!), '10:15 13/10');
      final copy = CareMoney.fromJson(m.toJson());
      expect(copy.overpaid, isTrue);
      expect(copy.asOf, m.asOf);
    },
  );

  for (final invalid in [null, -1, 1.5, 'not-a-count']) {
    test('A-23 invalid/null absence ($invalid) never creates an absence', () {
      final json = careStudentJson();
      final section = (json['dossier']['sections'] as List).single as Map;
      section['absent'] = invalid;
      final student = TeacherCareStudent.fromJson(json);
      expect(student.sections.single.absent, isNull);
      expect(student.sections.single.attendanceKnown, isFalse);
      expect(student.myAbsences, 0);
      expect(student.needsAttention, isFalse);
      final copy = TeacherCareStudent.fromJson(student.toJson());
      expect(copy.sections.single.absent, isNull);
    });
  }

  test('A-23 unmarked and conflicting sessions never become absences', () {
    final json = careStudentJson();
    final section = (json['dossier']['sections'] as List).single as Map;
    section['conflicts'] = 3;
    final student = TeacherCareStudent.fromJson(json);
    expect(student.myAbsences, 0);
    expect(student.attentionReasons, isEmpty);
    expect(student.sections.single.unrecorded, 2);
    expect(student.sections.single.conflicts, 3);
  });

  test('stale grades/attendance cannot create current attention claims', () {
    final json = careStudentJson();
    json['checks'] = [
      {'kind': 'progression'},
    ];
    json['dossier']['freshness'] = {'attendance': false, 'grades': false};
    json['dossier']['sections'][0]['absent'] = 2;
    expect(TeacherCareStudent.fromJson(json).needsAttention, isFalse);
  });

  test('unreadable score stays unknown after an offline round trip', () {
    final json = careStudentJson();
    json['dossier']['sections'][0]['midterm_score'] = 'not-a-score';
    final s = TeacherCareStudent.fromJson(json);
    expect(s.sections.single.scoresReadable, isFalse);
    expect(
      TeacherCareStudent.fromJson(s.toJson()).sections.single.scoresReadable,
      isFalse,
    );
    expect(formatScore(7.555), '7.555');
    expect(formatScore(10), '10');
    expect(formatScore(1.1e-10), '1.1e-10');
    expect(formatScore(null), 'Chưa có điểm');
  });

  test(
    'grouping places every student and never duplicates a section permission',
    () {
      final json = careStudentJson();
      json['can_review_sections'] = [careSectionId, careSectionId];
      final other = careStudentJson(1)
        ..['can_review_sections'] = ['missing-section'];
      final classes = TeacherStudentsViewModel.groupByClass([
        TeacherCareStudent.fromJson(json),
        TeacherCareStudent.fromJson(other),
      ]);
      expect(classes, hasLength(2));
      expect(classes.first.students, hasLength(1));
      expect(classes.last.isOther, isTrue);
      expect(classes.last.students.single.mssv, 'TEST25-1');
    },
  );
}
