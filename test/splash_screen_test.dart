import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viendongedu2_flutter/models/crm_identity.dart';
import 'package:viendongedu2_flutter/screens/change_password_screen.dart';
import 'package:viendongedu2_flutter/screens/splash_screen.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/notification_service.dart';
import 'package:viendongedu2_flutter/theme/vd_theme.dart';

class _Notifications extends Fake implements NotificationService {
  final ready = Completer<void>();
  String? pendingRoute;
  final registered = <String>[];
  var consumes = 0;
  @override
  Future<void> get initialMessageReady => ready.future;
  @override
  String? consumePendingInitialMessageRoute() {
    consumes++;
    final route = pendingRoute;
    pendingRoute = null;
    return route;
  }

  @override
  Future<void> registerToken(
    String hocVienId, {
    String? mssv,
    String? hoTen,
    String? ngaysinh,
    String? userid,
  }) async {
    registered.add(hocVienId);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() {
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
  Future<void> pump(
    WidgetTester t,
    double width,
    _Notifications notifications,
    Future<bool> Function(BuildContext) check,
  ) async {
    t.view.physicalSize = Size(width, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: VdTheme.light(),
        home: SplashScreen(checkForUpdate: check, notifications: notifications),
        routes: {
          '/login': (_) => const Scaffold(body: Text('Đăng nhập thử')),
          '/home': (_) => const Scaffold(body: Text('Trang học viên thử')),
          '/gv_home': (_) => const Scaffold(body: Text('Trang giảng viên thử')),
          '/teacher/notifications': (_) =>
              Scaffold(appBar: AppBar(title: const Text('Thông báo thử'))),
        },
      ),
    );
  }

  void saveIdentity({bool teacher = false, bool forced = false}) {
    final id = CrmIdentity(
      role: teacher ? CrmRole.teacher : CrmRole.student,
      token: 'fictional-test-token',
      mssv: teacher ? null : 'TEST2600014',
      teacherId: teacher ? 'TEST26-ID' : null,
      teacherCode: teacher ? 'TEST26-TEACHER' : null,
      fullName: 'Nhân vật thử nghiệm',
      mustChangePassword: forced,
    );
    SharedPreferences.setMockInitialValues({
      'ems_token': id.token,
      'crm_identity': jsonEncode(id.toPrefsJson()),
    });
  }

  for (final width in [320.0, 430.0]) {
    testWidgets(
      'splash loading, update block and unauthenticated route at $width',
      (t) async {
        final check = Completer<bool>();
        final notifications = _Notifications()
          ..pendingRoute = '/teacher/notifications';
        await pump(t, width, notifications, (_) => check.future);
        await t.pump(const Duration(milliseconds: 400));
        expect(find.text('VIỄN ĐÔNG'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Đăng nhập thử'), findsNothing);
        expect(t.takeException(), isNull);
        check.complete(false);
        await t.pump(const Duration(milliseconds: 400));
        expect(find.byType(SplashScreen), findsOneWidget);
        expect(notifications.consumes, 0);
        await t.pumpWidget(const SizedBox.shrink());
        await pump(t, width, notifications, (_) async => true);
        await t.pumpAndSettle();
        expect(find.text('Đăng nhập thử'), findsOneWidget);
        expect(notifications.pendingRoute, isNull);
        expect(notifications.registered, isEmpty);
        expect(t.takeException(), isNull);
      },
    );
    for (final teacher in [false, true]) {
      testWidgets(
        'splash restores ${teacher ? 'teacher' : 'student'} at $width',
        (t) async {
          saveIdentity(teacher: teacher);
          final notifications = _Notifications()..ready.complete();
          await pump(t, width, notifications, (_) async => true);
          await t.pumpAndSettle();
          expect(
            find.text(teacher ? 'Trang giảng viên thử' : 'Trang học viên thử'),
            findsOneWidget,
          );
          expect(notifications.registered, [
            teacher ? 'gv_TEST26-TEACHER' : 'hv_TEST2600014',
          ]);
          expect(find.byType(SplashScreen), findsNothing);
          expect(t.takeException(), isNull);
        },
      );
    }
    testWidgets('splash forced password route at $width', (t) async {
      saveIdentity(forced: true);
      final notifications = _Notifications();
      await pump(t, width, notifications, (_) async => true);
      await t.pumpAndSettle();
      expect(find.byType(ChangePasswordScreen), findsOneWidget);
      expect(find.text('Vui lòng đổi mật khẩu'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_ios), findsNothing);
      expect(notifications.consumes, 0);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets(
    'cold-start notification after splash replacement keeps home below it',
    (t) async {
      saveIdentity(teacher: true);
      final notifications = _Notifications();
      await pump(t, 320, notifications, (_) async => true);
      await t.pumpAndSettle();
      expect(find.text('Trang giảng viên thử'), findsOneWidget);
      // Firebase can answer after the replacement animation disposes Splash.
      notifications.pendingRoute = '/teacher/notifications';
      notifications.ready.complete();
      await t.pumpAndSettle();
      expect(find.text('Thông báo thử'), findsOneWidget);
      await t.pageBack();
      await t.pumpAndSettle();
      expect(find.text('Trang giảng viên thử'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('splash notification timeout still allows home', (t) async {
    saveIdentity();
    await pump(t, 430, _Notifications(), (_) async => true);
    await t.pumpAndSettle();
    await t.pump(const Duration(seconds: 2));
    expect(find.text('Trang học viên thử'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
