import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viendongedu2_flutter/models/crm_identity.dart';
import 'package:viendongedu2_flutter/screens/student_questions_screen.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/crm_questions_api.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSession.instance.emsToken = 'student-token';
    AppSession.instance.role = CrmRole.student;
    AppSession.instance.mssv = '2600000001';
  });
  tearDown(() {
    EmsApiService.client = http.Client();
    AppSession.instance.emsToken = null;
    AppSession.instance.role = null;
    AppSession.instance.mssv = null;
  });

  test('question list cache belongs to the signed-in student', () async {
    EmsApiService.client = MockClient(
      (request) async => http.Response(
        jsonEncode({
          'conversations': [
            {
              'id': 4,
              'subject': 'Lịch học',
              'status': 'open',
              'last_message': {'body': 'Xin chào'},
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    expect((await CrmQuestionsApi.list()).single.subject, 'Lịch học');
    expect(await CrmQuestionsApi.cachedList(), isNull);
    AppSession.instance.mssv = '2600000002';
    expect(await CrmQuestionsApi.cachedList(), isNull);
  });

  testWidgets('offline student sees no connection and no saved list', (
    tester,
  ) async {
    EmsApiService.client = MockClient(
      (request) async => http.Response(
        jsonEncode({
          'conversations': [
            {'id': 4, 'subject': 'Lịch học', 'status': 'open'},
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    await CrmQuestionsApi.list();
    EmsApiService.client = MockClient(
      (request) async => throw http.ClientException('offline'),
    );

    await tester.pumpWidget(const MaterialApp(home: StudentQuestionsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Lịch học'), findsNothing);
    expect(find.textContaining('Không có kết nối'), findsOneWidget);
  });

  testWidgets('offline draft cannot be sent to an unverified destination', (
    tester,
  ) async {
    EmsApiService.client = MockClient(
      (request) async => throw http.ClientException('offline'),
    );
    await tester.pumpWidget(const MaterialApp(home: StudentQuestionsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đặt câu hỏi'));
    await tester.pumpAndSettle();
    expect(find.text('Gửi câu hỏi'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });
}
