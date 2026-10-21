import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viendongedu2_flutter/models/crm_identity.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';
import 'package:viendongedu2_flutter/theme/vd_theme.dart';

http.Response jsonResponse(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

/// No sockets: every request must be handled explicitly by the test.
void fakeScreenSession(
  Future<http.Response> Function(http.Request) respond, {
  bool teacher = false,
}) {
  SharedPreferences.setMockInitialValues({});
  AppSession.instance
    ..emsToken = 'fictional-test-token'
    ..emsDenied = false
    ..role = teacher ? CrmRole.teacher : CrmRole.student
    ..mssv = teacher ? null : 'TEST2600014'
    ..teacherId = teacher ? 'TEST26-TEACHER-ID' : null
    ..teacherCode = teacher ? 'TEST26-TEACHER' : null
    ..fullName = 'Nhân vật thử nghiệm'
    ..mustChangePassword = false;
  final previous = EmsApiService.client;
  final client = MockClient(respond);
  EmsApiService.client = client;
  addTearDown(() {
    EmsApiService.client = previous;
    client.close();
    AppSession.instance
      ..emsToken = null
      ..emsDenied = false
      ..role = null
      ..mssv = null
      ..teacherId = null
      ..teacherCode = null
      ..fullName = null
      ..mustChangePassword = false;
  });
}

Future<void> openScreen(
  WidgetTester tester,
  Widget screen,
  double width, {
  bool settle = true,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: VdTheme.light(),
      routes: {'/login': (_) => const Scaffold(body: Text('Đăng nhập thử'))},
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => screen)),
            child: const Text('Mở màn hình thử'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Mở màn hình thử'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  if (settle) await tester.pumpAndSettle();
}

Future<void> expectBack(
  WidgetTester tester, {
  IconData icon = Icons.arrow_back_ios,
}) async {
  await tester.tap(find.byIcon(icon));
  await tester.pumpAndSettle();
  expect(find.text('Mở màn hình thử'), findsOneWidget);
  expect(tester.takeException(), isNull);
}
