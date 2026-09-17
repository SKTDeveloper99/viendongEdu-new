import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viendongedu2_flutter/screens/ems_attendance_student_screen.dart';
import 'package:viendongedu2_flutter/screens/ems_attendance_teacher_screen.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';

/// Mock EMS with a two-student roster. [onPost] decides what POST /marks
/// returns; the roster reflects [status] per mssv after a successful save.
MockClient _teacherMock({
  required http.Response Function(Map<String, dynamic> body) onPost,
  required List<Map<String, dynamic>> Function() students,
  required List<Map<String, dynamic>> posts,
}) {
  return MockClient((request) async {
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
              'roster_size': 2,
              'marked_count': 0,
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
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      posts.add(body);
      return onPost(body);
    }
    if (request.url.path.endsWith('/attendance/roster')) {
      return http.Response(
        jsonEncode({
          'session_key': '123:18-00:2026-09-08',
          'students': students(),
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.Response('{}', 404);
  });
}

Future<void> _openClass(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(home: EmsAttendanceTeacherScreen()),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Môn thử nghiệm'));
  await tester.pumpAndSettle();
}

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

  // 17/09 Huy 43461: 12 học viên chưa chạm, Lưu vẫn xanh. Lưu phải hỏi trước.
  testWidgets('Lưu with undecided students asks first and never writes them', (
    tester,
  ) async {
    final posts = <Map<String, dynamic>>[];
    final status = <String, String?>{'2600000001': null, '2600000002': null};
    EmsApiService.client = _teacherMock(
      posts: posts,
      students: () => [
        for (final e in status.entries)
          {'mssv': e.key, 'full_name': 'Học viên ${e.key}', 'status': e.value},
      ],
      onPost: (body) {
        for (final m in body['marks'] as List) {
          status[m['mssv'] as String] = m['status'] as String;
        }
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
      },
    );
    await _openClass(tester);
    // Tick only the first student present.
    await tester.tap(find.text('Có').first);
    await tester.pump();
    await tester.tap(find.text('Lưu điểm danh'));
    await tester.pumpAndSettle();

    expect(find.text('Còn 1 học viên chưa điểm danh'), findsOneWidget);
    expect(find.textContaining('Học viên 2600000002'), findsWidgets);
    expect(posts, isEmpty, reason: 'nothing sent before the teacher answers');

    await tester.tap(find.text('Quay lại điểm danh'));
    await tester.pumpAndSettle();
    expect(posts, isEmpty);

    await tester.tap(find.text('Lưu điểm danh'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Lưu 1 đã chọn'));
    await tester.pumpAndSettle();

    expect(posts, hasLength(1));
    final marks = posts.single['marks'] as List;
    expect(marks, hasLength(1));
    expect(marks.single['mssv'], '2600000001');
    expect(status['2600000002'], isNull, reason: 'undecided is never absent');
    expect(find.textContaining('Đã lưu 1 dòng'), findsOneWidget);
  });

  // 17/09 Hậu 43194: bốn lần 422 y hệt trong 30 giây vì hàng đợi 20 s gửi lại.
  testWidgets('punch-conflict 422 stops the retry queue until Lưu is tapped', (
    tester,
  ) async {
    final posts = <Map<String, dynamic>>[];
    final status = <String, String?>{'2600000001': null, '2600000002': null};
    EmsApiService.client = _teacherMock(
      posts: posts,
      students: () => [
        {
          'mssv': '2600000001',
          'full_name': 'Học viên quẹt cổng',
          'status': status['2600000001'],
          'scanned': true,
          'scanned_at': '2026-09-08T17:42:00+07:00',
          'punch_id': 77,
        },
        {
          'mssv': '2600000002',
          'full_name': 'Học viên hai',
          'status': status['2600000002'],
        },
      ],
      onPost: (body) {
        final marks = body['marks'] as List;
        final noReason = marks.any(
          (m) =>
              m['status'] == 'absent' &&
              (m['note'] == null || (m['note'] as String).trim().isEmpty),
        );
        if (noReason) {
          return http.Response(
            jsonEncode({
              'error':
                  '1 học viên đã quẹt cổng nhưng bị ghi vắng — cần nêu lý do.',
              'code': 'punch_conflict_needs_reason',
              'students': [
                {
                  'mssv': '2600000001',
                  'punched_at': '2026-09-08T17:42:00+07:00',
                },
              ],
            }),
            422,
            headers: {'content-type': 'application/json'},
          );
        }
        for (final m in marks) {
          status[m['mssv'] as String] = m['status'] as String;
        }
        return http.Response(
          jsonEncode({
            'saved': 2,
            'inserted': 2,
            'updated': 0,
            'late': false,
            'overridden_punches': [77],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      },
    );
    await _openClass(tester);
    // Scanned student marked absent, the other present → no undecided.
    await tester.tap(find.text('Vắng').first);
    await tester.tap(find.text('Có').last);
    await tester.pump();
    await tester.tap(find.text('Lưu điểm danh'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(posts, hasLength(1));
    expect(find.text('Cần nêu lý do'), findsOneWidget);

    // Teacher closes the dialog. The 20 s queue must NOT resend the same body.
    await tester.tap(find.text('Huỷ'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 65));
    await tester.pumpAndSettle();
    expect(posts, hasLength(1), reason: 'no silent identical retries');
    expect(find.textContaining('CHƯA LƯU'), findsWidgets);

    // Lưu again → dialog → reason → save goes through with the note.
    await tester.tap(find.text('Lưu điểm danh'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(posts, hasLength(2));
    await tester.enterText(find.byType(TextField).first, 'không thấy tại lớp');
    await tester.pump();
    await tester.tap(find.text('Lưu kèm lý do'));
    await tester.pumpAndSettle();

    expect(posts, hasLength(3));
    final last = posts.last['marks'] as List;
    final absent = last.firstWhere((m) => m['mssv'] == '2600000001');
    expect(absent['note'], 'không thấy tại lớp');
    await tester.pump(const Duration(seconds: 65));
    await tester.pumpAndSettle();
    expect(posts, hasLength(3), reason: 'queue cleared after success');
  });
}
