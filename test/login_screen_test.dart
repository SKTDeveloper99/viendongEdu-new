// Đăng nhập CRM (EMS) — không còn đăng nhập IMS từ 6.1.0.
//
// Ba luồng phải đúng: học viên đăng nhập thường, giảng viên đăng nhập
// thường (vai trò chọn qua nút chuyển ở đầu màn hình), và must_change_password
// đưa thẳng vào màn đổi mật khẩu bắt buộc thay vì vào app.
//
//   flutter test test/login_screen_test.dart
//
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viendongedu2_flutter/models/crm_identity.dart';
import 'package:viendongedu2_flutter/screens/change_password_screen.dart';
import 'package:viendongedu2_flutter/screens/login_screen.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final s = AppSession.instance;
    s
      ..token = null
      ..emsToken = null
      ..emsDenied = false
      ..role = null
      ..mssv = null
      ..teacherId = null
      ..teacherCode = null
      ..fullName = null
      ..mustChangePassword = false
      ..hocVien = null
      ..giangVien = null;
  });

  tearDown(() => EmsApiService.client = http.Client());

  /// App giả lập tối thiểu: chỉ đủ để biết đã điều hướng tới đâu, không kéo
  /// theo các màn hình thật (vốn còn gọi IMS và cần rất nhiều dữ liệu mock).
  Widget testApp() => const MaterialApp(
        initialRoute: '/login',
        routes: {
          '/login': _r,
          '/home': _home,
          '/gv_home': _gvHome,
        },
      );

  testWidgets('học viên đăng nhập đúng mật khẩu vào thẳng /home',
      (tester) async {
    EmsApiService.client = MockClient((req) async {
      expect(req.url.path, '/api/auth/student/login');
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      expect(body['mssv'], 'TEST2600001');
      expect(body['password'], 'TEST2600001');
      return http.Response(
        jsonEncode({
          'token': 'crm-student-token',
          'student': {
            'mssv': 'TEST2600001',
            'full_name': 'Thử Nghiệm Học Viên',
            'must_change_password': false,
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(testApp());
    await tester.enterText(find.byType(TextField).at(0), 'TEST2600001');
    await tester.enterText(find.byType(TextField).at(1), 'TEST2600001');
    await tester.tap(find.text('Đăng nhập'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home')), findsOneWidget);
    expect(AppSession.instance.isLoggedIn, isTrue);
    expect(AppSession.instance.role, CrmRole.student);
    expect(AppSession.instance.mssv, 'TEST2600001');
    expect(AppSession.instance.mustChangePassword, isFalse);
  });

  testWidgets('giảng viên chuyển vai trò rồi đăng nhập vào /gv_home',
      (tester) async {
    EmsApiService.client = MockClient((req) async {
      expect(req.url.path, '/api/auth/teacher/login');
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      expect(body['teacher_code'], '0601030');
      return http.Response(
        jsonEncode({
          'token': 'crm-teacher-token',
          'teacher': {
            'teacher_id': '9',
            'teacher_code': '0601030',
            'full_name': 'Thử Nghiệm Giáo Viên',
            'must_change_password': false,
          },
          'user': {'id': '9', 'role': 'teacher'},
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(testApp());
    await tester.tap(find.text('Giảng viên'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(0), '0601030');
    await tester.enterText(find.byType(TextField).at(1), '0601030');
    await tester.tap(find.text('Đăng nhập'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('gv_home')), findsOneWidget);
    expect(AppSession.instance.role, CrmRole.teacher);
    expect(AppSession.instance.teacherCode, '0601030');
  });

  testWidgets('must_change_password đưa vào màn đổi mật khẩu bắt buộc, '
      'không vào thẳng app', (tester) async {
    EmsApiService.client = MockClient((req) async {
      return http.Response(
        jsonEncode({
          'token': 'crm-student-token',
          'student': {
            'mssv': 'TEST2600002',
            'full_name': 'Thử Nghiệm Học Viên Hai',
            'must_change_password': true,
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(testApp());
    await tester.enterText(find.byType(TextField).at(0), 'TEST2600002');
    await tester.enterText(find.byType(TextField).at(1), 'TEST2600002');
    await tester.tap(find.text('Đăng nhập'));
    await tester.pumpAndSettle();

    expect(find.byType(ChangePasswordScreen), findsOneWidget);
    expect(find.byKey(const Key('home')), findsNothing);
    expect(AppSession.instance.mustChangePassword, isTrue);
    // Bắt buộc: không có nút back.
    expect(find.byIcon(Icons.arrow_back_ios), findsNothing);
  });

  testWidgets('sai mật khẩu hiện đúng thông báo lỗi từ máy chủ',
      (tester) async {
    EmsApiService.client = MockClient((_) async => http.Response(
          jsonEncode({'error': 'Sai mã số sinh viên hoặc mật khẩu.'}),
          401,
          headers: {'content-type': 'application/json'},
        ));

    await tester.pumpWidget(testApp());
    await tester.enterText(find.byType(TextField).at(0), 'TEST2600003');
    await tester.enterText(find.byType(TextField).at(1), 'saipassword');
    await tester.tap(find.text('Đăng nhập'));
    await tester.pumpAndSettle();

    expect(find.text('Sai mã số sinh viên hoặc mật khẩu.'), findsOneWidget);
    expect(AppSession.instance.isLoggedIn, isFalse);
  });
}

Widget _r(BuildContext _) => const LoginScreen();
Widget _home(BuildContext _) => const Scaffold(
      key: Key('home'),
      body: Text('home'),
    );
Widget _gvHome(BuildContext _) => const Scaffold(
      key: Key('gv_home'),
      body: Text('gv_home'),
    );
