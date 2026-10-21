import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:viendongedu2_flutter/components/skeleton.dart';
import 'package:viendongedu2_flutter/core/school_calendar.dart';
import 'package:viendongedu2_flutter/screens/gv_schedule_screen.dart';
import 'package:viendongedu2_flutter/screens/schedule_screen.dart';

import 'helpers/screen_harness.dart';

final _day = DateTime(2026, 10, 19, 8);
const _slot = {
  'section_code': 'TEST26-CLASS',
  'subject_name': 'Môn học thử nghiệm có tên dài',
  'day_code': '2',
  'start_time': '07:30',
  'end_time': '09:30',
  'room': 'TEST26-PHONG',
  'teacher_name': 'Giảng viên thử nghiệm',
  'class_size': 12,
};

void main() {
  for (final teacher in [false, true]) {
    for (final width in [320.0, 430.0]) {
      Widget screen() => teacher
          ? GvScheduleScreen(
              calendar: SchoolCalendar(
                clock: () => DateTime.utc(2026, 10, 19, 1),
              ),
            )
          : ScheduleScreen(now: () => _day);
      final path = teacher
          ? '/api/teacher/me/schedule'
          : '/api/student/me/schedule';
      final empty = teacher ? 'Không có lịch dạy' : 'Không có lịch học';
      testWidgets(
        '${teacher ? 'teacher' : 'student'} schedule loading, error, recovery, empty at $width',
        (t) async {
          final pending = Completer<http.Response>();
          var calls = 0;
          fakeScreenSession((r) async {
            if (r.url.path == '/api/student/me/attendance-ems') {
              return jsonResponse({'marks': []});
            }
            expect(r.url.path, path);
            return ++calls == 1
                ? pending.future
                : jsonResponse({teacher ? 'data' : 'schedule': []});
          }, teacher: teacher);
          await openScreen(t, screen(), width, settle: false);
          expect(find.byType(Skeleton), findsWidgets);
          expect(find.text(empty), findsNothing);
          pending.complete(jsonResponse({'error': 'Lỗi lịch thử nghiệm'}, 500));
          await t.pumpAndSettle();
          expect(find.text(empty), findsNothing);
          if (teacher) {
            expect(find.textContaining('Lỗi lịch thử nghiệm'), findsOneWidget);
            await t.tap(find.text('Thử lại'));
          } else {
            expect(find.text('Đang đối chiếu'), findsOneWidget);
            await t.tap(find.text('Thử lại'));
          }
          await t.pumpAndSettle();
          expect(calls, 2);
          expect(find.text(empty), findsOneWidget);
          expect(t.takeException(), isNull);
          await expectBack(t);
        },
      );
      testWidgets(
        '${teacher ? 'teacher' : 'student'} schedule populated and day taps at $width',
        (t) async {
          final dates = <String?>[];
          fakeScreenSession((r) async {
            if (r.url.path == '/api/student/me/attendance-ems') {
              return jsonResponse({'marks': []});
            }
            expect(r.url.path, path);
            dates.add(r.url.queryParameters['date']);
            return jsonResponse({
              teacher ? 'data' : 'schedule': [
                if (!teacher || dates.last == '2026-10-19')
                  teacher
                      ? {
                          'lmhid': 'TEST26-ID',
                          'lmhma': 'TEST26-CLASS',
                          'mhten': 'Môn học thử nghiệm có tên dài',
                          'phongten': 'TEST26-PHONG',
                          'thoigianbd': '2026-10-19T07:30:00',
                          'thoigiankt': '2026-10-19T09:30:00',
                        }
                      : _slot,
              ],
            });
          }, teacher: teacher);
          await openScreen(t, screen(), width);
          expect(find.text('Môn học thử nghiệm có tên dài'), findsOneWidget);
          if (teacher) {
            expect(find.text('07:30'), findsOneWidget);
            expect(find.text('09:30'), findsOneWidget);
          }
          expect(t.takeException(), isNull);
          await t.tap(find.text('T3'));
          await t.pumpAndSettle();
          expect(find.text(empty), findsOneWidget);
          expect(find.text('Môn học thử nghiệm có tên dài'), findsNothing);
          if (teacher) {
            expect(dates, ['2026-10-19', '2026-10-20']);
            await expectBack(t);
          } else {
            expect(dates, [null]); // Student weeks are filtered locally.
            await expectBack(t);
          }
          expect(t.takeException(), isNull);
        },
      );
    }
  }
}
