import 'package:flutter_test/flutter_test.dart';
import 'package:viendongedu2_flutter/models/crm_teacher_class.dart';

void main() {
  test('teacher class accepts PostgreSQL numeric strings', () {
    final row = CrmTeacherClass.fromJson({
      'section_id': 'section-uuid',
      'section_code': 'TN261A',
      'si_so': '35.0',
      'credits': '3.0',
      'enrolled_students': '28',
      'sessions': 12,
      'attendance_rows': '336.0',
      'grade_rows': null,
    });

    expect(row.sectionId, 'section-uuid');
    expect(row.siSo, 35);
    expect(row.credits, 3);
    expect(row.enrolledStudents, 28);
    expect(row.sessions, 12);
    expect(row.attendanceRows, 336);
    expect(row.gradeRows, 0);
  });

  test('related roster, schedule and exam numeric fields tolerate strings', () {
    final student = CrmClassStudent.fromJson({
      'mssv': 'TEST260001',
      'midterm_score': '8.5',
      'final_exam_score': '9.0',
      'final_score': 8.8,
      'attendance_rows': '10.0',
    });
    expect(student.midtermScore, 8.5);
    expect(student.finalExamScore, 9);
    expect(student.finalScore, 8.8);
    expect(student.attendanceRows, 10);

    final exam = CrmTeacherExam.fromJson({
      'exam_id': 'exam-1',
      'duration_minutes': '90.0',
      'class_size': '35.0',
      'credits': '3.0',
    });
    expect(exam.durationMinutes, 90);
    expect(exam.classSize, 35);
    expect(exam.credits, 3);

    final slot = CrmScheduleSlot.fromJson({'lmhid': '42', 'sotinchi': '3.0'});
    expect(slot.soTinChi, 3);
  });

  test(
    'malformed numeric strings degrade to null or zero without throwing',
    () {
      final row = CrmTeacherClass.fromJson({
        'section_id': 'section-uuid',
        'credits': 'unknown',
        'sessions': 'unknown',
      });
      expect(row.credits, isNull);
      expect(row.sessions, 0);
    },
  );
}
