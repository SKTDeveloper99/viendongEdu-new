// T1: CRM pages inside the app through a one-use pass. The web view itself
// is replaced by a fake surface here. Fixtures fictional.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viendongedu2_flutter/core/crm_web/crm_web_policy.dart';
import 'package:viendongedu2_flutter/core/crm_web/crm_web_target.dart';
import 'package:viendongedu2_flutter/data/web_pass_repository.dart';
import 'package:viendongedu2_flutter/features/crm_web/crm_page_screen.dart';
import 'package:viendongedu2_flutter/features/crm_web/crm_web_session.dart';
import 'package:viendongedu2_flutter/models/crm_identity.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};
const _host = 'ems.viendong.edu.vn';

void main() {
  group('targets', () {
    test('fixed paths; ids checked; route names round-trip', () {
      expect(CrmTarget.tasks().relative, '/tasks');
      expect(CrmTarget.tasks(taskId: '42').relative, '/tasks?task_id=42');
      expect(CrmTarget.tasks(taskId: '42&x=1').relative, '/tasks');
      expect(
        CrmTarget.groups(taskId: '7', spaceId: '../admin').relative,
        '/nhom?task_id=7',
      );
      final back = CrmTarget.fromRouteName(
        CrmTarget.tasks(taskId: '9').routeName,
      )!;
      expect(back.relative, '/tasks?task_id=9');
      expect(CrmTarget.fromRouteName('/crm/admin-access.html'), isNull);
      expect(CrmTarget.fromRouteName('/gv_home'), isNull);
    });

    test('task pushes open the page for teachers only', () {
      final data = {'route': '/nhom', 'task_id': '5', 'space_id': 'abc-1'};
      expect(
        CrmTarget.fromPush(data, isTeacher: true)!.relative,
        '/nhom?task_id=5&space_id=abc-1',
      );
      expect(CrmTarget.fromPush(data, isTeacher: false), isNull);
      expect(
        CrmTarget.fromPush({'route': '/tasks'}, isTeacher: true)!.relative,
        '/tasks',
      );
      expect(
        CrmTarget.fromPush({'route': '/conversations'}, isTeacher: true),
        isNull,
      );
    });
  });

  test('navigation: our host inside, login/pass failure caught, rest out', () {
    CrmNav nav(String u) => crmNavigation(Uri.parse(u), host: _host);
    expect(nav('https://ems.viendong.edu.vn/tasks'), CrmNav.allow);
    expect(nav('https://EMS.viendong.edu.vn/nhom?x=1'), CrmNav.allow);
    expect(nav('https://ems.viendong.edu.vn/pass-failed'), CrmNav.passFailed);
    expect(nav('https://ems.viendong.edu.vn/login.html'), CrmNav.passFailed);
    expect(nav('https://ems.viendong.edu.vn/login'), CrmNav.passFailed);
    expect(nav('http://ems.viendong.edu.vn/tasks'), CrmNav.external);
    expect(nav('https://drive.google.com/file/1'), CrmNav.external);
    expect(nav('https://ems.viendong.edu.vn.evil.test/'), CrmNav.external);
    expect(nav('mailto:a@b.test'), CrmNav.external);
    expect(nav('intent://scan/#Intent;end'), CrmNav.block);
    expect(nav('javascript:alert(1)'), CrmNav.block);
    expect(nav('about:blank'), CrmNav.allow);
    expect(nav('data:text/html,<script>x</script>'), CrmNav.block);
  });

  group('pass and screen', () {
    late List<Map<String, dynamic>> mints;
    late Object Function() reply;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      AppSession.instance
        ..emsToken = 'test-teacher-token'
        ..role = CrmRole.teacher
        ..teacherId = 'T-TEST-1';
      mints = [];
      reply = () => {
        'url': 'https://$_host/pass#c=test-code',
        'expires_in': 60,
      };
      EmsApiService.client = MockClient((req) async {
        mints.add({
          'path': req.url.path,
          ...jsonDecode(req.body) as Map<String, dynamic>,
        });
        final r = reply();
        if (r is http.Response) return r;
        return http.Response(jsonEncode(r), 200, headers: _json);
      });
    });
    tearDown(() {
      EmsApiService.client = http.Client();
      AppSession.instance
        ..emsToken = null
        ..role = null
        ..teacherId = null;
    });

    test(
      'mint asks for the fixed target; foreign or bare URLs refused',
      () async {
        final pass = await const WebPassRepository().mint(
          CrmTarget.tasks(taskId: '3'),
        );
        expect(mints.single['path'], '/api/v1/auth/web-pass');
        expect(mints.single['target'], '/tasks?task_id=3');
        expect(pass.url.host, _host);
        for (final bad in [
          'https://evil.test/pass#c=x',
          'http://$_host/pass#c=x',
          'https://$_host/pass?c=x', // code must stay in the fragment
          'rác',
        ]) {
          reply = () => {'url': bad};
          await expectLater(
            const WebPassRepository().mint(CrmTarget.tasks()),
            throwsA(isA<EmsException>()),
            reason: bad,
          );
        }
      },
    );

    Future<void> pump(
      WidgetTester t, {
      CrmWebSession? session,
      void Function(CrmWebSurfaceArgs)? onSurface,
    }) async {
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => CrmPageScreen(
                    target: CrmTarget.tasks(),
                    session: session ?? CrmWebSession(token: () => 'tok'),
                    surface: (context, args) {
                      onSurface?.call(args);
                      return Text('trang ${args.url.host}');
                    },
                  ),
                ),
              ),
              child: const Text('mở'),
            ),
          ),
        ),
      );
      await t.tap(find.text('mở'));
      await t.pumpAndSettle();
    }

    testWidgets('opens the page with a fresh pass; ✕ closes', (t) async {
      await pump(t);
      expect(find.text('Việc của tôi'), findsOneWidget);
      expect(find.text('trang $_host'), findsOneWidget);
      await t.tap(find.byTooltip('Đóng'));
      await t.pumpAndSettle();
      expect(find.text('mở'), findsOneWidget);
    });

    testWidgets('mint fails: one Vietnamese retry line, retry mints again', (
      t,
    ) async {
      reply = () => http.Response('test-server-error', 500);
      await pump(t);
      expect(find.text(CrmPageScreen.retryText), findsOneWidget);
      expect(find.textContaining('Đăng nhập'), findsNothing);
      reply = () => {'url': 'https://$_host/pass#c=x2'};
      await t.tap(find.text('Thử lại'));
      await t.pumpAndSettle();
      expect(find.text('trang $_host'), findsOneWidget);
      expect(mints.length, greaterThanOrEqualTo(2));
    });

    testWidgets('pass expired inside the page: retry line, not the login', (
      t,
    ) async {
      late CrmWebSurfaceArgs args;
      await pump(t, onSurface: (a) => args = a);
      args.onPassFailed();
      await t.pumpAndSettle();
      expect(find.text(CrmPageScreen.retryText), findsOneWidget);
      expect(find.text('trang $_host'), findsNothing);
    });
  });

  group('web storage follows the app login', () {
    late int wipes;
    late String? token;
    late CrmWebSession session;

    setUp(() {
      wipes = 0;
      token = 'token-A';
      session = CrmWebSession(token: () => token)..attach(() async => wipes++);
    });
    tearDown(() => AppSession.clearHooks.clear());

    test('first opening after start wipes; same token does not', () async {
      await session.beforeOpen();
      expect(wipes, 1);
      await session.beforeOpen();
      expect(wipes, 1);
    });

    test('another app token wipes before opening', () async {
      await session.beforeOpen();
      token = 'token-B';
      await session.beforeOpen();
      expect(wipes, 2);
    });

    test('logout wipes', () async {
      await session.beforeOpen();
      for (final hook in List.of(AppSession.clearHooks)) {
        hook();
      }
      await Future<void>.delayed(Duration.zero);
      expect(wipes, 2);
    });
  });
}
