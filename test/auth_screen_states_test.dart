import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:viendongedu2_flutter/screens/change_password_screen.dart';
import 'package:viendongedu2_flutter/screens/login_screen.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';

import 'helpers/screen_harness.dart';

void main() {
  for (final width in [320.0, 430.0]) {
    for (final teacher in [false, true]) {
      testWidgets(
        'login validation, visibility, pending and error ${teacher ? 'teacher' : 'student'} at $width',
        (t) async {
          var calls = 0;
          final pending = Completer<http.Response>();
          fakeScreenSession((r) async {
            expect(
              r.url.path,
              teacher ? '/api/auth/teacher/login' : '/api/auth/student/login',
            );
            calls++;
            return pending.future;
          });
          AppSession.instance.emsToken = null;
          await openScreen(t, const LoginScreen(), width);
          if (teacher) {
            await t.tap(find.text('Giảng viên'));
            await t.pump();
          }
          expect(
            find.text(teacher ? 'Mã giáo viên' : 'Mã số sinh viên (MSSV)'),
            findsOneWidget,
          );
          await t.ensureVisible(find.text('Đăng nhập'));
          await t.tap(find.text('Đăng nhập'));
          await t.pumpAndSettle();
          expect(calls, 0);
          expect(
            find.text('Vui lòng nhập tài khoản và mật khẩu.'),
            findsOneWidget,
          );
          expect(t.takeException(), isNull);
          await t.tap(find.text('Thử lại'));
          await t.pumpAndSettle();
          await t.enterText(
            find.byType(TextField).at(0),
            teacher ? 'TEST26-TEACHER' : 'TEST2600014',
          );
          await t.enterText(
            find.byType(TextField).at(1),
            'fictional-password14',
          );
          expect(
            t.widget<TextField>(find.byType(TextField).at(1)).obscureText,
            isTrue,
          );
          await t.tap(find.byIcon(Icons.visibility_off));
          await t.pump();
          expect(
            t.widget<TextField>(find.byType(TextField).at(1)).obscureText,
            isFalse,
          );
          await t.ensureVisible(find.text('Đăng nhập'));
          await t.tap(find.text('Đăng nhập'));
          await t.pump(const Duration(seconds: 1));
          await t.pump();
          expect(calls, 1);
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          expect(
            t.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
            isNull,
          );
          expect(t.takeException(), isNull);
          pending.complete(
            jsonResponse({'error': 'Sai mật khẩu thử nghiệm'}, 401),
          );
          await t.pumpAndSettle();
          expect(find.text('Sai mật khẩu thử nghiệm'), findsOneWidget);
          expect(AppSession.instance.isLoggedIn, isFalse);
          await t.tap(find.text('Thử lại'));
          await t.pumpAndSettle();
          expect(find.text('Đăng nhập'), findsOneWidget);
          expect(
            t.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
            isNotNull,
          );
          expect(t.takeException(), isNull);
        },
      );
    }
    for (final forced in [false, true]) {
      testWidgets(
        'password validation, loading, error, retry ${forced ? 'forced' : 'normal'} at $width',
        (t) async {
          var calls = 0;
          final pending = Completer<http.Response>();
          fakeScreenSession((r) async {
            expect(r.url.path, '/api/student/me/password');
            calls++;
            return calls == 1 ? pending.future : jsonResponse({'ok': true});
          });
          AppSession.instance.mustChangePassword = forced;
          await openScreen(t, ChangePasswordScreen(forced: forced), width);
          expect(
            find.text(forced ? 'Vui lòng đổi mật khẩu' : 'Đổi mật khẩu'),
            findsOneWidget,
          );
          expect(t.takeException(), isNull);
          final submit = find.byType(ElevatedButton);
          await t.ensureVisible(submit);
          await t.tap(submit);
          await t.pumpAndSettle();
          expect(calls, 0);
          expect(find.text('Vui lòng nhập mật khẩu hiện tại'), findsOneWidget);
          if (forced) {
            await t.binding.handlePopRoute();
            await t.pumpAndSettle();
            expect(find.byType(ChangePasswordScreen), findsOneWidget);
          }
          final fields = find.byType(TextFormField);
          await t.enterText(fields.at(0), 'old-test-password14');
          await t.enterText(fields.at(1), 'new-test-password14');
          await t.enterText(fields.at(2), 'new-test-password14');
          await t.ensureVisible(submit);
          await t.tap(submit);
          await t.pump();
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          expect(t.widget<ElevatedButton>(submit).onPressed, isNull);
          expect(calls, 1);
          pending.complete(
            jsonResponse({'error': 'Mật khẩu hiện tại không đúng'}, 400),
          );
          await t.pumpAndSettle();
          expect(find.text('Mật khẩu hiện tại không đúng'), findsOneWidget);
          expect(AppSession.instance.mustChangePassword, forced);
          expect(t.widget<ElevatedButton>(submit).onPressed, isNotNull);
          expect(t.takeException(), isNull);
          if (!forced) {
            await t.ensureVisible(submit);
            await t.tap(submit);
            await t.pumpAndSettle();
            expect(calls, 2);
            expect(find.text('Mở màn hình thử'), findsOneWidget);
          }
        },
      );
    }
  }
}
