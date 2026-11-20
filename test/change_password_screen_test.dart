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

  _signOutTests();

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

      await tester.pumpWidget(
        const MaterialApp(
          initialRoute: '/change_password',
          routes: {'/change_password': _forcedChange, '/home': _home},
        ),
      );
      await fillAndSubmit(tester);

      expect(calledPath, '/api/student/me/password');
      expect(find.byKey(const Key('home')), findsOneWidget);
      expect(AppSession.instance.mustChangePassword, isFalse);
    },
  );

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

      await tester.pumpWidget(
        const MaterialApp(
          initialRoute: '/change_password',
          routes: {'/change_password': _forcedChange, '/gv_home': _gvHome},
        ),
      );
      await fillAndSubmit(tester);

      expect(calledPath, '/api/auth/change-password');
      expect(find.byKey(const Key('gv_home')), findsOneWidget);
    },
  );

  testWidgets('lối vào thường (không bắt buộc) có nút back và pop khi xong', (
    tester,
  ) async {
    AppSession.instance
      ..emsToken = 'crm-token'
      ..role = CrmRole.student
      ..mssv = 'TEST2600001'
      ..mustChangePassword = false;

    EmsApiService.client = MockClient(
      (_) async => http.Response(
        jsonEncode({'ok': true, 'must_change_password': false}),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
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
      ),
    );
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_back_ios), findsOneWidget);
    await fillAndSubmit(tester);

    // pop về màn trước, thấy lại nút 'mở'.
    expect(find.text('mở'), findsOneWidget);
  });

  testWidgets('mật khẩu xác nhận không khớp thì không gửi request', (
    tester,
  ) async {
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

    await tester.pumpWidget(
      const MaterialApp(
        initialRoute: '/change_password',
        routes: {'/change_password': _forcedChange, '/home': _home},
      ),
    );
    await tester.enterText(find.byType(TextFormField).at(0), 'oldpass');
    await tester.enterText(find.byType(TextFormField).at(1), 'newpass123');
    await tester.enterText(find.byType(TextFormField).at(2), 'khac-di');
    await tester.tap(find.text('Xác nhận đổi mật khẩu'));
    await tester.pumpAndSettle();

    expect(called, isFalse);
    expect(
      find.text('Vui lòng nhập lại mật khẩu xác nhận cho khớp'),
      findsOneWidget,
    );
  });

  testWidgets(
    'right after sign-in the typed password is used, not asked again; a '
    'wrong one is refused on the screen without signing out',
    (tester) async {
      AppSession.instance
        ..emsToken = 'crm-token'
        ..role = CrmRole.staff
        ..mustChangePassword = true;
      var expired = false;
      final before = EmsApiService.onUnauthorized;
      EmsApiService.onUnauthorized = (_) => expired = true;
      addTearDown(() => EmsApiService.onUnauthorized = before);
      final sent = <String>[];
      EmsApiService.client = MockClient((req) async {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        sent.add('${body['current_password']}');
        return http.Response.bytes(
          utf8.encode(jsonEncode({'error': 'Mật khẩu hiện tại không đúng'})),
          401,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      await tester.pumpWidget(
        MaterialApp(
          home: const ChangePasswordScreen(
            forced: true,
            currentPassword: 'first-pass',
          ),
          routes: {'/staff_home': _home},
        ),
      );
      // Only the two new-password fields; staff get the staff rule.
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.textContaining('mã số sinh viên'), findsNothing);
      await tester.enterText(find.byType(TextFormField).at(0), 'newpass-abc');
      await tester.enterText(find.byType(TextFormField).at(1), 'newpass-abc');
      await tester.tap(find.text('Xác nhận đổi mật khẩu'));
      await tester.pumpAndSettle();
      expect(sent, ['first-pass']);
      expect(find.text('Mật khẩu hiện tại không đúng'), findsOneWidget);
      expect(expired, isFalse);
      expect(AppSession.instance.emsToken, 'crm-token');
    },
  );

  // The student route answers a wrong current password with 401 too.
  Future<bool> studentChange(WidgetTester tester, String serverText) async {
    AppSession.instance
      ..emsToken = 'crm-token'
      ..role = CrmRole.student
      ..mustChangePassword = false;
    var expired = false;
    final before = EmsApiService.onUnauthorized;
    EmsApiService.onUnauthorized = (_) => expired = true;
    addTearDown(() => EmsApiService.onUnauthorized = before);
    EmsApiService.client = MockClient((req) async {
      expect(req.url.path, endsWith('/student/me/password'));
      return http.Response.bytes(
        utf8.encode(jsonEncode({'error': serverText})),
        401,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    await tester.pumpWidget(const MaterialApp(home: ChangePasswordScreen()));
    await tester.enterText(find.byType(TextFormField).at(0), 'Sai-Mat-Khau-1');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Moi-Mat-Khau-26a',
    );
    await tester.enterText(
      find.byType(TextFormField).at(2),
      'Moi-Mat-Khau-26a',
    );
    await tester.tap(find.text('Xác nhận đổi mật khẩu'));
    await tester.pumpAndSettle();
    return expired;
  }

  testWidgets('student: a wrong current password is refused on the screen '
      'without signing out', (tester) async {
    final expired = await studentChange(
      tester,
      'Mật khẩu hiện tại không đúng.',
    );
    expect(find.text('Mật khẩu hiện tại không đúng.'), findsOneWidget);
    expect(expired, isFalse);
    expect(AppSession.instance.emsToken, 'crm-token');
  });

  testWidgets('student: a session the server ended still signs out', (
    tester,
  ) async {
    final expired = await studentChange(
      tester,
      'Phiên đăng nhập đã kết thúc vì mật khẩu vừa được thay đổi. '
      'Vui lòng đăng nhập lại.',
    );
    expect(expired, isTrue);
  });
}

void _signOutTests() {
  testWidgets('forced change: "Đăng xuất" leaves to sign-in without sending '
      'a password change, and the session is gone', (tester) async {
    AppSession.instance
      ..emsToken = 'crm-token'
      ..role = CrmRole.student
      ..mssv = 'TEST26APP01'
      ..mustChangePassword = true;
    final before = AppSession.revokeDeviceOverride;
    AppSession.revokeDeviceOverride = (_) async {};
    addTearDown(() => AppSession.revokeDeviceOverride = before);
    var calls = 0;
    EmsApiService.client = MockClient((_) async {
      calls++;
      return http.Response('{}', 200);
    });
    await tester.pumpWidget(
      MaterialApp(
        home: const ChangePasswordScreen(
          forced: true,
          currentPassword: 'TEST26APP01',
        ),
        routes: {'/login': _login},
      ),
    );
    expect(find.byIcon(Icons.arrow_back_ios), findsNothing);
    await tester.tap(find.byKey(const Key('forced-change-sign-out')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login')), findsOneWidget);
    expect(calls, 0);
    expect(AppSession.instance.emsToken, isNull);
  });

  testWidgets('the normal (not forced) entry has no extra "Đăng xuất"', (
    tester,
  ) async {
    AppSession.instance
      ..emsToken = 'crm-token'
      ..role = CrmRole.student
      ..mssv = 'TEST26APP01'
      ..mustChangePassword = false;
    await tester.pumpWidget(const MaterialApp(home: ChangePasswordScreen()));
    expect(find.byKey(const Key('forced-change-sign-out')), findsNothing);
  });
}

Widget _login(BuildContext _) =>
    const Scaffold(key: Key('login'), body: Text('login'));

Widget _forcedChange(BuildContext _) =>
    const ChangePasswordScreen(forced: true);
Widget _home(BuildContext _) =>
    const Scaffold(key: Key('home'), body: Text('home'));
Widget _gvHome(BuildContext _) =>
    const Scaffold(key: Key('gv_home'), body: Text('gv_home'));
