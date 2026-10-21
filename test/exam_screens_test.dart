import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:viendongedu2_flutter/components/skeleton.dart';
import 'package:viendongedu2_flutter/screens/exam_screen.dart';
import 'package:viendongedu2_flutter/screens/gv_lichthi_screen.dart';

import 'helpers/screen_harness.dart';

const _semesters = [
  {
    'id': 26,
    'ma': '261',
    'ten': 'Học kỳ thử nghiệm 1',
    'ngaybatdau': '2026-09-01',
  },
  {
    'id': 25,
    'ma': '252',
    'ten': 'Học kỳ thử nghiệm 2',
    'ngaybatdau': '2025-09-01',
  },
];
const _exam = {
  'exam_id': 'TEST26-EXAM',
  'subject_name': 'Môn thi thử nghiệm',
  'semester_code': '261',
  'class_code': 'TEST26-CLASS',
  'exam_type': 'Giữa kỳ',
  'exam_date': '2026-10-25',
  'start_time': '07:30',
  'duration_minutes': 120,
  'class_size': 12,
  'exam_format': 'Tự luận',
  'note': 'Ghi chú thi thử nghiệm',
};

void main() {
  for (final teacher in [false, true]) {
    final title = teacher ? 'teacher exams' : 'student exams';
    final path = teacher ? '/api/teacher/me/exams' : '/api/student/me/exams';
    final empty = teacher ? 'Chưa có lịch thi học kỳ này' : 'Không có lịch thi';
    for (final width in [320.0, 430.0]) {
      testWidgets('$title loading, error, retry, empty at $width', (t) async {
        final pending = Completer<http.Response>();
        var calls = 0;
        fakeScreenSession((r) async {
          if (r.url.path == '/api/teacher/me/semesters')
            return jsonResponse(_semesters);
          expect(r.url.path, path);
          calls++;
          return calls == 1 ? pending.future : jsonResponse({'exams': []});
        }, teacher: teacher);
        await openScreen(
          t,
          teacher ? const GvLichThiScreen() : const ExamScreen(),
          width,
          settle: false,
        );
        expect(find.text('Lịch thi'), findsOneWidget);
        expect(find.byType(Skeleton), findsWidgets);
        expect(find.text(empty), findsNothing);
        expect(t.takeException(), isNull);
        pending.complete(jsonResponse({'error': 'Lỗi thi thử nghiệm'}, 500));
        await t.pumpAndSettle();
        expect(find.textContaining('Lỗi thi thử nghiệm'), findsOneWidget);
        expect(find.text(empty), findsNothing);
        await t.tap(find.text('Thử lại'));
        await t.pumpAndSettle();
        expect(calls, 2);
        expect(find.text(empty), findsOneWidget);
        expect(t.takeException(), isNull);
        await expectBack(t);
      });
      testWidgets(
        '$title populated, semester selection, refresh, back at $width',
        (t) async {
          final requested = <String?>[];
          fakeScreenSession((r) async {
            if (r.url.path == '/api/teacher/me/semesters')
              return jsonResponse(_semesters);
            expect(r.url.path, path);
            requested.add(r.url.queryParameters['semester']);
            return jsonResponse({
              'exams': [
                _exam,
                if (!teacher && requested.last == null)
                  {
                    ..._exam,
                    'exam_id': 'TEST26-OLD',
                    'semester_code': '252',
                    'subject_name': 'Môn thi cũ',
                    'exam_date': '2025-10-01',
                  },
              ],
            });
          }, teacher: teacher);
          await openScreen(
            t,
            teacher ? const GvLichThiScreen() : const ExamScreen(),
            width,
          );
          expect(find.text('Môn thi thử nghiệm'), findsOneWidget);
          expect(find.text('25/10/2026'), findsOneWidget);
          expect(find.text('120 phút'), findsWidgets);
          expect(requested.single, teacher ? '261' : null);
          expect(t.takeException(), isNull);
          if (teacher) {
            await t.tap(find.text('Môn thi thử nghiệm'));
            await t.pumpAndSettle();
            expect(find.text('Tự luận'), findsOneWidget);
            expect(find.text('12 sinh viên'), findsOneWidget);
            expect(find.text('Ghi chú thi thử nghiệm'), findsOneWidget);
          } else {
            expect(find.text('—'), findsWidgets); // Unknown room stays unknown.
          }
          await t.tap(find.byWidgetPredicate((w) => w is DropdownButton));
          await t.pumpAndSettle();
          await t.tap(
            find
                .text(teacher ? 'Học kỳ thử nghiệm 2' : 'Học kỳ 2, 2025 - 2026')
                .last,
          );
          await t.pumpAndSettle();
          expect(requested.last, '252');
          expect(find.text('Môn thi cũ'), findsNothing);
          final list = find.descendant(
            of: find.byType(RefreshIndicator),
            matching: find.byType(ListView),
          );
          await t.drag(list, const Offset(0, 350));
          await t.pumpAndSettle();
          expect(requested, [teacher ? '261' : null, '252', '252']);
          expect(t.takeException(), isNull);
          await expectBack(t);
        },
      );
    }
    if (teacher) {
      testWidgets(
        'teacher semester read error retries; no semesters is empty',
        (t) async {
          var calls = 0;
          fakeScreenSession((r) async {
            expect(r.url.path, '/api/teacher/me/semesters');
            return ++calls == 1
                ? jsonResponse({'error': 'Lỗi học kỳ thử nghiệm'}, 500)
                : jsonResponse([]);
          }, teacher: true);
          await openScreen(t, const GvLichThiScreen(), 320);
          expect(find.textContaining('Lỗi học kỳ thử nghiệm'), findsOneWidget);
          await t.tap(find.text('Thử lại'));
          await t.pumpAndSettle();
          expect(calls, 2);
          expect(find.text('Chưa có lịch thi học kỳ này'), findsOneWidget);
        },
      );
    }
  }
}
