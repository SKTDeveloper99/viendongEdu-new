// Quên mật khẩu (học viên) — LAW P-51 (đề xuất). Lối vào chỉ có ở thẻ
// "Sinh viên" của trang đăng nhập; màn hình riêng gửi MSSV + ngày sinh tới
// POST /api/auth/student/forgot-password, báo kết quả rồi về đăng nhập.
//
//   flutter test test/forgot_password_screen_test.dart
//
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viendongedu2_flutter/screens/forgot_password_screen.dart';
import 'package:viendongedu2_flutter/screens/login_screen.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';

const _fail =
    'Không đặt lại được mật khẩu với thông tin này. Vui lòng liên hệ GVCN hoặc Phòng Đào tạo để được hỗ trợ.';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => EmsApiService.client = http.Client());

  Widget app() => const MaterialApp(home: LoginScreen());

  http.Response json(Object body, int status) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  test(
    'ngày sinh: dd/mm/yyyy thành yyyy-mm-dd, ngày không có thật bị từ chối',
    () {
      expect(parseBirthDate('09/03/2004'), '2004-03-09');
      expect(parseBirthDate('9/3/2004'), '2004-03-09');
      expect(parseBirthDate('09.03.2004'), '2004-03-09');
      expect(parseBirthDate('31/02/2004'), isNull);
      expect(parseBirthDate('2004-03-09'), isNull);
      expect(parseBirthDate(''), isNull);
    },
  );

  testWidgets('chỉ thẻ Sinh viên có "Quên mật khẩu?"', (tester) async {
    await tester.pumpWidget(app());
    expect(find.byKey(const Key('forgot-password-link')), findsOneWidget);
    await tester.tap(find.text('Cán bộ, GV'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('forgot-password-link')), findsNothing);
    expect(find.text('Quên mật khẩu?'), findsNothing);
  });

  testWidgets('đúng MSSV và ngày sinh: báo kết quả rồi về đăng nhập với MSSV', (
    tester,
  ) async {
    Map<String, dynamic>? sent;
    String? path;
    EmsApiService.client = MockClient((req) async {
      path = req.url.path;
      sent = jsonDecode(req.body) as Map<String, dynamic>;
      expect(req.headers['authorization'], isNull);
      return json({
        'ok': true,
        'message': 'Đã đặt lại mật khẩu. Hãy đăng nhập bằng mã số sinh viên.',
      }, 200);
    });

    await tester.pumpWidget(app());
    await tester.enterText(find.byType(TextField).first, 'TEST26APP09');
    await tester.tap(find.byKey(const Key('forgot-password-link')));
    await tester.pumpAndSettle();

    expect(find.text('Quên mật khẩu'), findsOneWidget);
    final mssvField = tester.widget<TextField>(
      find.byKey(const Key('forgot-mssv')),
    );
    expect(mssvField.controller!.text, 'TEST26APP09');

    await tester.enterText(find.byKey(const Key('forgot-dob')), '09/03/2004');
    await tester.tap(find.byKey(const Key('forgot-submit')));
    await tester.pumpAndSettle();

    expect(path, '/api/auth/student/forgot-password');
    expect(sent, {'mssv': 'TEST26APP09', 'date_of_birth': '2004-03-09'});
    expect(find.text('Đã đặt lại mật khẩu'), findsOneWidget);

    await tester.tap(find.byKey(const Key('forgot-done')));
    await tester.pumpAndSettle();
    expect(find.byType(ForgotPasswordScreen), findsNothing);
    expect(find.byKey(const Key('forgot-password-link')), findsOneWidget);
    expect(find.text('TEST26APP09'), findsOneWidget);
  });

  testWidgets('sai: hiện đúng câu của máy chủ và ở lại màn hình', (
    tester,
  ) async {
    EmsApiService.client = MockClient((_) async => json({'error': _fail}, 400));
    await tester.pumpWidget(
      const MaterialApp(home: ForgotPasswordScreen(initialMssv: 'TEST26APP09')),
    );
    await tester.enterText(find.byKey(const Key('forgot-dob')), '10/03/2004');
    await tester.tap(find.byKey(const Key('forgot-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('forgot-error')), findsOneWidget);
    expect(find.text(_fail), findsOneWidget);
    expect(find.byType(ForgotPasswordScreen), findsOneWidget);
  });

  testWidgets('ngày sinh sai dạng: báo ngay, không gửi gì', (tester) async {
    var calls = 0;
    EmsApiService.client = MockClient((_) async {
      calls++;
      return json({'ok': true}, 200);
    });
    await tester.pumpWidget(
      const MaterialApp(home: ForgotPasswordScreen(initialMssv: 'TEST26APP09')),
    );
    await tester.enterText(find.byKey(const Key('forgot-dob')), '31/02/2004');
    await tester.tap(find.byKey(const Key('forgot-submit')));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.textContaining('ngày/tháng/năm'), findsWidgets);
    expect(find.byKey(const Key('forgot-error')), findsOneWidget);
  });

  testWidgets(
    'máy chủ chưa có Quên mật khẩu (404 chung): báo chưa mở, gặp GVCN/PĐT',
    (tester) async {
      EmsApiService.client = MockClient(
        (_) async => json({'error': 'Endpoint not found'}, 404),
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: ForgotPasswordScreen(initialMssv: 'TEST26APP09'),
        ),
      );
      await tester.enterText(find.byKey(const Key('forgot-dob')), '09/03/2004');
      await tester.tap(find.byKey(const Key('forgot-submit')));
      await tester.pumpAndSettle();
      expect(find.textContaining('chưa mở trên máy chủ'), findsOneWidget);
      expect(find.textContaining('GVCN hoặc Phòng Đào tạo'), findsOneWidget);
    },
  );

  for (final typed in ['01/01/2099', '01/01/1930']) {
    testWidgets('a typed birth date outside the calendar ($typed) still opens '
        'the calendar instead of failing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ForgotPasswordScreen(initialMssv: 'TEST26APP01'),
        ),
      );
      await tester.enterText(find.byKey(const Key('forgot-dob')), typed);
      await tester.tap(find.byTooltip('Chọn trên lịch'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Chọn ngày sinh'), findsOneWidget);
    });
  }

  testWidgets(
    'over the limit (429): the server\'s Vietnamese words are shown',
    (tester) async {
      const limit = 'Bạn đã thử quá nhiều lần. Vui lòng thử lại sau một giờ.';
      EmsApiService.client = MockClient(
        (_) async => json({'error': limit}, 429),
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: ForgotPasswordScreen(initialMssv: 'TEST26APP01'),
        ),
      );
      await tester.enterText(find.byKey(const Key('forgot-dob')), '09/03/2004');
      await tester.tap(find.byKey(const Key('forgot-submit')));
      await tester.pumpAndSettle();
      expect(find.text(limit), findsOneWidget);
      expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    },
  );
}
