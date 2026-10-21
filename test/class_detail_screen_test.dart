import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:viendongedu2_flutter/features/classes/class_detail_screen.dart';
import 'package:viendongedu2_flutter/features/classes/class_models.dart';
import 'package:viendongedu2_flutter/features/classes/widgets/attendance_card.dart';
import 'package:viendongedu2_flutter/features/classes/widgets/class_grade_card.dart';
import 'package:viendongedu2_flutter/features/classes/widgets/session_list_card.dart';

import 'helpers/screen_harness.dart';

const _item = ClassItem(
  sectionId: 14,
  lmhma: 'TEST26-CLASS',
  mhma: 'TEST26-SUBJECT',
  mhten: 'Môn học thử nghiệm có tên dài',
  sotinchi: 3,
  gvten: 'Giảng viên thử nghiệm',
  diemgk: 7,
  diemck: 9,
  tongdiem: 8.3,
);
const _screen = ClassDetailScreen(item: _item, semTen: 'Học kỳ thử nghiệm');

void main() {
  for (final width in [320.0, 430.0]) {
    testWidgets(
      'class detail loading, error, retry, empty and back at $width',
      (t) async {
        final pending = Completer<http.Response>();
        var calls = 0;
        fakeScreenSession((r) async {
          expect(r.url.path, '/api/student/me/attendance-ems');
          expect(r.url.queryParameters['limit'], '300');
          return ++calls == 1 ? pending.future : jsonResponse({'marks': []});
        });
        await openScreen(t, _screen, width, settle: false);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byType(ClassGradeCard), findsNothing);
        expect(t.takeException(), isNull);
        pending.complete(jsonResponse({'error': 'Lỗi thử nghiệm'}, 500));
        await t.pumpAndSettle();
        expect(find.text('Không thể tải điểm danh'), findsOneWidget);
        expect(find.text('Chưa có dữ liệu điểm danh'), findsNothing);
        expect(find.byType(AttendanceCard), findsNothing);
        await t.ensureVisible(find.text('Thử lại'));
        await t.tap(find.text('Thử lại'));
        await t.pumpAndSettle();
        expect(calls, 2);
        expect(find.text('Chưa có dữ liệu điểm danh'), findsOneWidget);
        expect(find.text('Mã lớp'), findsOneWidget);
        expect(find.text('8.3'), findsOneWidget);
        expect(find.byType(SessionListCard), findsNothing);
        expect(t.takeException(), isNull);
        await expectBack(t);
      },
    );
    testWidgets(
      'class detail filters attendance, preserves scores and fits at $width',
      (t) async {
        fakeScreenSession((r) async {
          expect(r.url.path, '/api/student/me/attendance-ems');
          return jsonResponse({
            'marks': [
              for (final entry in [
                (1, 'present'),
                (2, 'absent'),
                (3, 'excused'),
              ])
                {
                  'session_key': 'TEST26-${entry.$1}',
                  'section_code': _item.lmhma,
                  'session_date': '2026-10-0${entry.$1}',
                  'status': entry.$2,
                },
              {
                'section_code': 'TEST26-OTHER',
                'session_date': '2026-10-04',
                'status': 'present',
              },
            ],
          });
        });
        await openScreen(t, _screen, width);
        expect(find.text('Giảng viên thử nghiệm'), findsOneWidget);
        expect(find.text('8.3'), findsOneWidget);
        await t.ensureVisible(find.byType(AttendanceCard));
        await t.pumpAndSettle();
        expect(find.text('Tổng: 3 buổi'), findsOneWidget);
        await t.ensureVisible(find.byType(SessionListCard));
        await t.pumpAndSettle();
        expect(find.text('Buổi 3'), findsOneWidget);
        expect(find.text('Buổi 4'), findsNothing);
        expect(find.text('Báo nghỉ'), findsOneWidget);
        expect(t.takeException(), isNull);
        await expectBack(t);
      },
    );
  }
  testWidgets('class detail safely discards a response after back', (t) async {
    final pending = Completer<http.Response>();
    fakeScreenSession((_) => pending.future);
    await openScreen(t, _screen, 320, settle: false);
    await t.tap(find.byIcon(Icons.arrow_back_ios));
    await t.pumpAndSettle();
    pending.complete(jsonResponse({'marks': []}));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Mở màn hình thử'), findsOneWidget);
  });
}
