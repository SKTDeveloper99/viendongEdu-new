import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:viendongedu2_flutter/screens/teacher_my_day_screen.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';
import 'package:viendongedu2_flutter/data/api/student_cases_api.dart';

void main() {
  setUp(() {
    AppSession.instance.emsToken = 'crm-teacher-token';
    AppSession.instance.emsDenied = false;
  });

  tearDown(() {
    EmsApiService.client = http.Client();
    AppSession.instance.emsToken = null;
  });

  test('TeacherStudentCase parses server contract defensively', () {
    final item = TeacherStudentCase.fromJson({
      'id': 'case-1',
      'student_mssv': '2600000001',
      'student_name': 'Nguyễn Văn A',
      'title': 'Vắng học liên tiếp',
      'status': 'open',
      'priority': 'high',
      'my_relation': 'primary',
      'due_at': '2099-09-25T10:00:00+07:00',
    });

    expect(item.id, 'case-1');
    expect(item.studentMssv, '2600000001');
    expect(item.relation, 'primary');
    expect(item.dueAt, isNotNull);
    expect(item.isOverdue, isFalse);
  });

  test('case API uses the mirrored CRM token and sends the answer', () async {
    final calls = <http.Request>[];
    EmsApiService.client = MockClient((request) async {
      calls.add(request);
      if (request.method == 'POST') {
        return http.Response(
          jsonEncode({
            'case': {'id': 'case-1', 'status': 'pending_approval'},
            'official_answer': {'text': 'Đã gọi phụ huynh'},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode({
          'cases': [
            {
              'id': 'case-1',
              'student_mssv': '2600000001',
              'student_name': 'Nguyễn Văn A',
              'title': 'Vắng học liên tiếp',
              'status': 'open',
              'priority': 'high',
              'my_relation': 'primary',
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final cases = await StudentCasesApi.myOpenStudentCases();
    final result = await StudentCasesApi.answerStudentCase(
      cases.single.id,
      '  Đã gọi phụ huynh  ',
    );

    expect(cases.single.studentName, 'Nguyễn Văn A');
    expect(result.requiresApproval, isTrue);
    expect(calls[0].url.path, '/api/student-cases/my-open');
    expect(
      calls.every(
        (request) =>
            request.headers['authorization'] == 'Bearer crm-teacher-token',
      ),
      isTrue,
    );
    expect(jsonDecode(calls[1].body), {'answer': 'Đã gọi phụ huynh'});
  });

  testWidgets('shows sessions and assigned cases, then submits an answer', (
    tester,
  ) async {
    var answered = false;
    final posts = <Map<String, dynamic>>[];
    EmsApiService.client = MockClient((request) async {
      if (request.url.path.endsWith('/attendance/my-sessions')) {
        return http.Response(
          jsonEncode({
            'from_schedule': true,
            'sessions': [
              {
                'section_id': 'section-1',
                'section_code': 'K20-CNTT-01',
                'subject_name': 'Lập trình Web',
                'room': 'A.203',
                'session_date': '2026-09-19',
                'start_time': '07:30',
                'end_time': '09:30',
                'roster_size': 30,
                'marked_count': 0,
                'session_key': 'section-1:07-30:2026-09-19',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.method == 'POST' && request.url.path.endsWith('/answer')) {
        posts.add(jsonDecode(request.body) as Map<String, dynamic>);
        answered = true;
        return http.Response(
          jsonEncode({
            'case': {'id': 'case-1', 'status': 'official'},
            'official_answer': {'text': posts.single['answer']},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path.endsWith('/student-cases/my-open')) {
        return http.Response(
          jsonEncode({
            'cases': answered
                ? []
                : [
                    {
                      'id': 'case-1',
                      'student_mssv': '2600000001',
                      'student_name': 'Nguyễn Văn A',
                      'title': 'Vắng học liên tiếp',
                      'description': 'Vắng hai buổi và chưa phản hồi.',
                      'status': 'open',
                      'priority': 'high',
                      'my_relation': 'primary',
                      'due_at': '2099-09-25T10:00:00+07:00',
                    },
                  ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{}', 404);
    });

    await tester.pumpWidget(const MaterialApp(home: TeacherMyDayScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Ngày làm việc của tôi'), findsOneWidget);
    expect(find.text('Lập trình Web'), findsOneWidget);
    expect(find.text('Vắng học liên tiếp'), findsOneWidget);
    expect(find.textContaining('Nguyễn Văn A'), findsOneWidget);

    await tester.tap(find.text('Phản hồi ca sinh viên'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'Đã gọi phụ huynh, hẹn gặp ngày mai.',
    );
    await tester.pump();
    await tester.tap(find.text('Gửi phản hồi'));
    await tester.pumpAndSettle();

    expect(posts, hasLength(1));
    expect(posts.single['answer'], 'Đã gọi phụ huynh, hẹn gặp ngày mai.');
    expect(
      find.text('Không có sinh viên nào đang chờ bạn phản hồi.'),
      findsOneWidget,
    );
  });

  testWidgets('one failed source does not blank the other section', (
    tester,
  ) async {
    EmsApiService.client = MockClient((request) async {
      if (request.url.path.endsWith('/attendance/my-sessions')) {
        return http.Response(
          '{"from_schedule":true,"sessions":[]}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('<html>502</html>', 502);
    });

    await tester.pumpWidget(const MaterialApp(home: TeacherMyDayScreen()));
    await tester.pumpAndSettle();

    expect(
      find.text('Hôm nay không có buổi dạy trong lịch EMS.'),
      findsOneWidget,
    );
    expect(find.text('Thử lại'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off), findsOneWidget);
  });
}
