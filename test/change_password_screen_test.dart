// Đổi mật khẩu CRM — dùng chung cho lối vào bình thường và cho đổi mật khẩu
// bắt buộc (must_change_password) sau khi đăng nhập lần đầu. Học viên gọi
// POST /student/me/password, giảng viên gọi POST /auth/change-password.
//
//   flutter test test/change_password_screen_test.dart
//
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viendongedu2_flutter/models/crm_identity.dart';
import 'package:viendongedu2_flutter/screens/change_password_screen.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() => EmsApiService.client = http.Client());

  Future<void> fillAndSubmit(WidgetTester tester) async {
    await tester.enterText(find.byType(TextFormField).at(0), 'oldpass');
    await tester.enterText(find.byType(TextFormField).at(1), 'newpass123');
    await tester.enterText(find.byType(TextFormField).at(2), 'newpass123');
    await tester.tap(find.text('Xác nhận đổi mật khẩu'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'học viên bắt buộc đổi mật khẩu gọi /student/me/password và vào /home',
      (tester) async {
    AppSession.instance
      ..emsToken = 'crm-token'
      ..role = CrmRole.student
      ..mssv = 'TEST2600001'
      ..mustChangePassword = true;

    String? calledPath;
    EmsApiService.client = MockClient((req) async {
      calledPath = req.url.path;
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      expect(body['current_password'], 'oldpass');
      expect(body['new_password'], 'newpass123');
      return http.Response(
        jsonEncode({'ok': true, 'must_change_password': false}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(const MaterialApp(
      initialRoute: '/change_password',
      routes: {
        '/change_password': _forcedChange,
        '/home': _home,
      },
    ));
    await fillAndSubmit(tester);

    expect(calledPath, '/api/student/me/password');
    expect(find.byKey(const Key('home')), findsOneWidget);
    expect(AppSession.instance.mustChangePassword, isFalse);
  });

  testWidgets(
      'giảng viên bắt buộc đổi mật khẩu gọi /auth/change-password và vào /gv_home',
      (tester) async {
    AppSession.instance
      ..emsToken = 'crm-token'
      ..role = CrmRole.teacher
      ..teacherCode = '0601030'
      ..mustChangePassword = true;

    String? calledPath;
    EmsApiService.client = MockClient((req) async {
      calledPath = req.url.path;
      return http.Response(
        jsonEncode({'ok': true}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(const MaterialApp(
      initialRoute: '/change_password',
      routes: {
        '/change_password': _forcedChange,
        '/gv_home': _gvHome,
      },
    ));
    await fillAndSubmit(tester);

    expect(calledPath, '/api/auth/change-password');
    expect(find.byKey(const Key('gv_home')), findsOneWidget);
  });

  testWidgets('lối vào thường (không bắt buộc) có nút back và pop khi xong',
      (tester) async {
    AppSession.instance
      ..emsToken = 'crm-token'
      ..role = CrmRole.student
      ..mssv = 'TEST2600001'
      ..mustChangePassword = false;

    EmsApiService.client = MockClient((_) async => http.Response(
          jsonEncode({'ok': true, 'must_change_password': false}),
          200,
          headers: {'content-type': 'application/json'},
        ));

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ChangePasswordScreen(),
                ),
              ),
              child: const Text('mở'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_back_ios), findsOneWidget);
    await fillAndSubmit(tester);

    // pop về màn trước, thấy lại nút 'mở'.
    expect(find.text('mở'), findsOneWidget);
  });

  testWidgets('mật khẩu xác nhận không khớp thì không gửi request',
      (tester) async {
    AppSession.instance
      ..emsToken = 'crm-token'
      ..role = CrmRole.student
      ..mssv = 'TEST2600001'
      ..mustChangePassword = true;

    var called = false;
    EmsApiService.client = MockClient((_) async {
      called = true;
      return http.Response('{}', 200);
    });

    await tester.pumpWidget(const MaterialApp(
      initialRoute: '/change_password',
      routes: {'/change_password': _forcedChange, '/home': _home},
    ));
    await tester.enterText(find.byType(TextFormField).at(0), 'oldpass');
    await tester.enterText(find.byType(TextFormField).at(1), 'newpass123');
    await tester.enterText(find.byType(TextFormField).at(2), 'khac-di');
    await tester.tap(find.text('Xác nhận đổi mật khẩu'));
    await tester.pumpAndSettle();

    expect(called, isFalse);
    expect(find.text('Mật khẩu xác nhận không khớp'), findsOneWidget);
  });
}

Widget _forcedChange(BuildContext _) =>
    const ChangePasswordScreen(forced: true);
Widget _home(BuildContext _) => const Scaffold(key: Key('home'), body: Text('home'));
Widget _gvHome(BuildContext _) =>
    const Scaffold(key: Key('gv_home'), body: Text('gv_home'));
