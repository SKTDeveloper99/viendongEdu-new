import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viendongedu2_flutter/features/teacher_attendance/attendance_format.dart';
import 'package:viendongedu2_flutter/features/teacher_attendance/teacher_attendance_screen.dart';
import 'package:viendongedu2_flutter/features/teacher_attendance/widgets/reasons_dialog.dart';
import 'package:viendongedu2_flutter/models/crm_identity.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSession.instance.emsToken = 'test-token';
    AppSession.instance.role = CrmRole.teacher;
    AppSession.instance.teacherId = 'teacher-1';
  });
  tearDown(() {
    EmsApiService.client = http.Client();
    AppSession.instance.emsToken = null;
    AppSession.instance.role = null;
    AppSession.instance.teacherId = null;
  });

  test('invariant 7: school time is UTC+7', () {
    final t = DateTime.utc(2026, 9, 8, 23, 5, 9);
    expect(schoolHhmm(t), '06:05');
    expect(schoolHhmmss(t), '06:05:09 09/09/2026');
  });

  test('invariant 8: route /ems_attendance_gv opens the session list', () {
    final src = File('lib/main.dart').readAsStringSync();
    expect(
      src,
      contains(
        "'/ems_attendance_gv': (context) => const EmsAttendanceTeacherScreen()",
      ),
    );
  });

  testWidgets('invariant 8: session list reloads after the roster closes', (
    tester,
  ) async {
    var listCalls = 0;
    EmsApiService.client = MockClient((request) async {
      if (request.url.path.endsWith('/attendance/my-sessions')) {
        listCalls++;
        return http.Response(
          jsonEncode({
            'sessions': [
              {
                'section_id': 's-1',
                'section_code': 'LOP-THU',
                'subject_name': 'Môn thử nghiệm',
                'session_date': '2026-09-08',
                'start_time': '18:00',
                'session_key': 'k-1',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode({'session_key': 'k-1', 'students': []}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    await tester.pumpWidget(
      const MaterialApp(home: EmsAttendanceTeacherScreen()),
    );
    await tester.pumpAndSettle();
    expect(listCalls, 1);
    await tester.tap(find.text('Môn thử nghiệm'));
    await tester.pumpAndSettle();
    expect(find.text('Lưu điểm danh'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(listCalls, 2);
  });

  testWidgets('invariant 6: reasons dialog owns and disposes controllers', (
    tester,
  ) async {
    Map<String, String>? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showReasonsDialog(
                context,
                people: const [EmsPunchedStudent(mssv: 'TEST260001')],
                initial: const {},
                nameOf: (m) => 'Học viên $m',
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), ' lý do ');
    await tester.pump();
    await tester.tap(find.text('Lưu kèm lý do'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(result, {'TEST260001': 'lý do'});
    expect(find.byType(ReasonsDialog), findsNothing);
  });
}
