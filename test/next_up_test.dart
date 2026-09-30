import 'package:flutter_test/flutter_test.dart';
import 'package:viendongedu2_flutter/core/greeting.dart';
import 'package:viendongedu2_flutter/core/schedule/next_up.dart';
import 'package:viendongedu2_flutter/features/student_home/next_up.dart'
    as student;
import 'package:viendongedu2_flutter/features/teacher_home/next_up.dart'
    as teacher;
import 'package:viendongedu2_flutter/models/crm_student_schedule.dart';

DateTime at(int h, int m, [int s = 0]) => DateTime(2026, 9, 30, h, m, s);

CrmScheduleItem s(String name, String start, String end) => CrmScheduleItem(
  subjectName: name,
  startTime: start,
  endTime: end,
  room: ' P.101 ',
  sectionCode: '06CDTHUNGHIEM',
);

Map<String, dynamic> t(String name, String start, String end) => {
  'mhten': name,
  'lmhma': '06CDTHUNGHIEM',
  'phongten': 'P.101',
  'thoigianbd': start,
  'thoigiankt': '2026-09-30T$end:00',
};

void main() {
  final day = [
    s('Sáng', '07:30', '09:30'),
    s('Chiều', '13:00', '15:00'),
    s('Tối', '18:30', '20:30'),
  ];

  group('student nextUp', () {
    test('before the first class: Tiếp theo, minutes until start', () {
      final r = student.nextUp(day, at(7, 0));
      expect(r.phase, NextUpPhase.upcoming);
      expect(r.statusLabel, 'Tiếp theo');
      expect(r.entry!.subject, 'Sáng');
      expect(r.countdown, 'bắt đầu sau 30 phút');
      expect(r.timeRange, '07:30 – 09:30');
      expect(r.entry!.room, 'P.101');
    });

    test('during a class: Đang diễn ra, minutes left', () {
      final r = student.nextUp(day, at(8, 15));
      expect(r.phase, NextUpPhase.ongoing);
      expect(r.statusLabel, 'Đang diễn ra');
      expect(r.entry!.subject, 'Sáng');
      expect(r.countdown, 'còn 75 phút');
    });

    test('between classes: the next one, "lúc HH:mm" from 60 minutes', () {
      final r = student.nextUp(day, at(10, 0));
      expect(r.phase, NextUpPhase.upcoming);
      expect(r.entry!.subject, 'Chiều');
      expect(r.countdown, 'lúc 13:00');
    });

    test('after the last class: none', () {
      final r = student.nextUp(day, at(21, 0));
      expect(r.phase, NextUpPhase.none);
      expect(r.entry, isNull);
    });

    test('empty list: none', () {
      expect(student.nextUp(const [], at(9, 0)).phase, NextUpPhase.none);
    });

    test('boundaries: start minute is ongoing, end minute is not', () {
      expect(student.nextUp(day, at(7, 30)).phase, NextUpPhase.ongoing);
      expect(student.nextUp(day, at(7, 30, 59)).countdown, 'còn 120 phút');
      final atEnd = student.nextUp(day, at(9, 30));
      expect(atEnd.phase, NextUpPhase.upcoming);
      expect(atEnd.entry!.subject, 'Chiều');
      final last = student.nextUp(day, at(20, 30));
      expect(last.phase, NextUpPhase.none);
      expect(student.nextUp(day, at(20, 29)).countdown, 'còn 1 phút');
    });

    test('59 minutes is "sau N phút", 60 is "lúc"', () {
      expect(
        student.nextUp(day, at(12, 1)).countdown,
        'bắt đầu sau 59 phút',
      );
      expect(student.nextUp(day, at(12, 0)).countdown, 'lúc 13:00');
    });

    test('unordered input and unreadable times', () {
      final r = student.nextUp([
        s('Tối', '18:30', '20:30'),
        s('Hỏng', '', ''),
        s('Chiều', '13:00', '15:00'),
      ], at(9, 0));
      expect(r.entry!.subject, 'Chiều');
    });
  });

  group('teacher nextUp', () {
    final sessions = [
      t('Sáng', '07:30', '09:30'),
      t('Tối', '18:30', '20:30'),
    ];

    test('reads the toJson keys and carries the class code', () {
      final r = teacher.nextUp(sessions, at(7, 0));
      expect(r.phase, NextUpPhase.upcoming);
      expect(r.entry!.classCode, '06CDTHUNGHIEM');
      expect(r.timeRange, '07:30 – 09:30');
      expect(r.countdown, 'bắt đầu sau 30 phút');
    });

    test('ongoing, between, after, empty', () {
      expect(teacher.nextUp(sessions, at(9, 0)).countdown, 'còn 30 phút');
      expect(teacher.nextUp(sessions, at(10, 0)).countdown, 'lúc 18:30');
      expect(teacher.nextUp(sessions, at(22, 0)).phase, NextUpPhase.none);
      expect(teacher.nextUp(const [], at(9, 0)).phase, NextUpPhase.none);
    });

    test('accepts ISO start times', () {
      final r = teacher.nextUp([
        {'mhten': 'A', 'thoigianbd': '2026-09-30T14:00:00'},
      ], at(13, 45));
      expect(r.countdown, 'bắt đầu sau 15 phút');
      expect(r.timeRange, '14:00');
    });
  });

  test('greetingFor follows the device hour', () {
    expect(greetingFor(at(5, 0)), 'Chào buổi sáng,');
    expect(greetingFor(at(11, 59)), 'Chào buổi sáng,');
    expect(greetingFor(at(12, 0)), 'Chào buổi chiều,');
    expect(greetingFor(at(17, 59)), 'Chào buổi chiều,');
    expect(greetingFor(at(18, 0)), 'Chào buổi tối,');
    expect(greetingFor(at(23, 30)), 'Chào buổi tối,');
  });
}
