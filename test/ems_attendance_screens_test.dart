import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viendongedu2_flutter/screens/ems_attendance_student_screen.dart';
import 'package:viendongedu2_flutter/screens/ems_attendance_teacher_screen.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => EmsApiService.client = http.Client());

  testWidgets('student sees pending class and independent gate arrival', (
    tester,
  ) async {
    EmsApiService.client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'marks': [
            {
              'session_key': '123:18-00:2026-09-08',
              'session_date': '2026-09-08',
              'start_time': '18:00',
              'end_time': '20:30',
              'subject_name': 'Môn thử nghiệm',
              'status': null,
              'arrived_at': '2026-09-08T17:42:00+07:00',
              'arrival_on_time': true,
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(home: EmsAttendanceStudentScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Chờ giáo viên xác nhận'), findsOneWidget);
    expect(find.textContaining('Đã vào trường lúc 17:42'), findsOneWidget);
    expect(find.textContaining('trước giờ học'), findsOneWidget);
  });

  testWidgets('teacher save carries punch evidence and waits for read-back', (
    tester,
  ) async {
    var saved = false;
    Map<String, dynamic>? posted;
    EmsApiService.client = MockClient((request) async {
      if (request.url.path.endsWith('/attendance/my-sessions')) {
        return http.Response(
          jsonEncode({
            'sessions': [
              {
                'section_id': '11111111-1111-1111-1111-111111111111',
                'section_code': 'LOP-THU',
                'subject_name': 'Môn thử nghiệm',
                'session_date': '2026-09-08',
                'start_time': '18:00',
                'end_time': '20:30',
                'roster_size': 1,
                'marked_count': saved ? 1 : 0,
                'session_key': '123:18-00:2026-09-08',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.method == 'POST' &&
          request.url.path.endsWith('/attendance/marks')) {
        posted = jsonDecode(request.body) as Map<String, dynamic>;
        saved = true;
        return http.Response(
          jsonEncode({
            'saved': 1,
            'inserted': 1,
            'updated': 0,
            'late': false,
            'overridden_punches': [],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path.endsWith('/attendance/roster')) {
        return http.Response(
          jsonEncode({
            'session_key': '123:18-00:2026-09-08',
            'students': [
              {
                'mssv': '2600000001',
                'full_name': 'Học viên thử nghiệm',
                'status': saved ? 'present' : null,
                'scanned': true,
                'scanned_at': '2026-09-08T17:42:00+07:00',
                'punch_id': 77,
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{}', 404);
    });

    await tester.pumpWidget(
      const MaterialApp(home: EmsAttendanceTeacherScreen()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Môn thử nghiệm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quẹt cổng: có mặt (1)'));
    await tester.pump();
    await tester.tap(find.text('Lưu điểm danh'));
    await tester.pumpAndSettle();

    expect(posted, isNotNull);
    final marks = posted!['marks'] as List<dynamic>;
    expect(marks.single['punch_id'], 77);
    expect(marks.single['status'], 'present');
    expect(find.textContaining('Đã lưu 1 dòng'), findsOneWidget);
  });
}
