// Table-driven tests for the grade ladder and the pass rule the grades screen
// displays (lib/models/crm_student_grades.dart). Boundaries are exact.
import 'package:flutter_test/flutter_test.dart';
import 'package:viendongedu2_flutter/features/grades/grade_item.dart';
import 'package:viendongedu2_flutter/features/grades/widgets/grades_colors.dart';
import 'package:viendongedu2_flutter/models/crm_student_grades.dart';
import 'package:viendongedu2_flutter/theme/vd_tokens.dart';

void main() {
  test('letterGradeForScore: every threshold', () {
    final table = <double, String>{
      10: 'A', 8.5: 'A', 8.49: 'B+', 8.0: 'B+', 7.99: 'B', 7.0: 'B',
      6.99: 'C+', 6.5: 'C+', 6.49: 'C', 5.5: 'C', 5.49: 'D+', 5.0: 'D+',
      4.99: 'D', 4.0: 'D', 3.99: 'F', 0: 'F',
    };
    table.forEach((score, letter) {
      expect(letterGradeForScore(score), letter, reason: 'score $score');
    });
  });

  test('letterGradeForScore: unbandable input is null, never F', () {
    for (final s in <double?>[null, -0.01, 10.01, 54.2, double.nan]) {
      expect(letterGradeForScore(s), isNull, reason: 'score $s');
    }
  });

  test('letterGradeForDiem4: every threshold', () {
    final table = <double, String>{
      4.0: 'A', 3.99: 'B+', 3.5: 'B+', 3.49: 'B', 3.0: 'B', 2.99: 'C+',
      2.5: 'C+', 2.49: 'C', 2.0: 'C', 1.99: 'D+', 1.5: 'D+', 1.49: 'D',
      1.0: 'D', 0.99: 'F', 0: 'F',
    };
    table.forEach((d, letter) {
      expect(letterGradeForDiem4(d), letter, reason: 'diem4 $d');
    });
    expect(letterGradeForDiem4(null), isNull);
    expect(letterGradeForDiem4(-0.1), isNull);
  });

  test('isPassed: >= 5 or override; ungraded is not passed', () {
    bool passed(double? s, {bool override = false}) =>
        CrmStudentGrade(finalScore: s, overridePass: override).isPassed;
    expect(passed(5.0), isTrue);
    expect(passed(4.99), isFalse);
    expect(passed(null), isFalse);
    expect(passed(2.0, override: true), isTrue);
  });

  test('GradeItem shows a dash (never a fail) when there is no letter', () {
    expect(GradeItem(const CrmStudentGrade(finalScore: 54.2)).diemchu, '—');
    expect(GradeItem(const CrmStudentGrade()).diemchu, '—');
    expect(GradeItem(const CrmStudentGrade(finalScore: 3.0)).diemchu, 'F');
  });

  test('diem4 from the server is preferred over the raw score', () {
    const g = CrmStudentGrade(finalScore: 3.0, diem4: 4.0);
    expect(g.gradeLetter, 'A');
  });

  test('letter colours', () {
    const t = VdTokens.light;
    expect(gradeLetterColor('A', t), t.success);
    expect(gradeLetterColor('B+', t), t.info);
    expect(gradeLetterColor('B', t), t.info);
    expect(gradeLetterColor('C+', t), t.accent);
    expect(gradeLetterColor('C', t), t.accent);
    expect(gradeLetterColor('D+', t), t.inkMuted);
    expect(gradeLetterColor('D', t), t.inkMuted);
    expect(gradeLetterColor('F', t), t.danger);
    expect(gradeLetterColor('', t), t.inkMuted);
  });
}
