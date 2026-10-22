import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viendongedu2_flutter/models/crm_identity.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/crm_session_guard.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';
import 'package:viendongedu2_flutter/services/offline_snapshot.dart';

class _Routes extends NavigatorObserver {
  int logins = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route.settings.name == '/login') {
      logins++;
    }
  }
}

void main() {
  late http.Client original;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    original = EmsApiService.client;
    AppSession.instance
      ..emsToken = 'test-session'
      ..role = CrmRole.student
      ..mssv = 'TEST260001';
  });
  tearDown(() {
    EmsApiService.client = original;
    EmsApiService.onUnauthorized = null;
    AppSession.instance.emsToken = null;
  });

  testWidgets('parallel 401s clear locally and push login only once', (
    tester,
  ) async {
    final key = GlobalKey<NavigatorState>();
    final routes = _Routes();
    installCrmSessionGuard(key);
    EmsApiService.client = MockClient(
      (_) async => http.Response('invalid JSON', 401),
    );
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: key,
        navigatorObservers: [routes],
        home: const Scaffold(body: Text('Test home')),
        routes: {'/login': (_) => const Scaffold(body: Text('Đăng nhập'))},
      ),
    );
    await tester.pumpAndSettle();
    expect(key.currentState?.overlay?.context, isNotNull);
    expect(AppSession.instance.hasEms, isTrue);
    await OfflineSnapshot.save('test', {'items': []});
    await tester.runAsync(() async {
      await Future.wait([
        for (var i = 0; i < 3; i++)
          EmsApiService.send('GET', '/test/$i').catchError((Object error) {
            expect(error, isA<EmsException>());
            return null;
          }),
      ]);
      await () async {
        while (AppSession.instance.hasEms) {
          await Future<void>.delayed(Duration.zero);
        }
      }().timeout(const Duration(seconds: 3));
    });
    await tester.pumpAndSettle();
    expect(routes.logins, 1);
    expect(find.text('Đăng nhập'), findsOneWidget);
    expect(AppSession.instance.hasEms, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys().where((k) => k.startsWith('offline_v1_')), isEmpty);
  });

  testWidgets('a delayed old 401 cannot log out a newly signed-in account', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            context = c;
            return const Scaffold(body: Text('Test home'));
          },
        ),
      ),
    );
    AppSession.instance.emsToken = 'test-new-session';
    expect(
      await handleCrmAuthError(
        context,
        EmsException(
          'Phiên đăng nhập đã hết hạn.',
          statusCode: 401,
          requestToken: 'test-session',
        ),
      ),
      isTrue,
    );
    expect(AppSession.instance.emsToken, 'test-new-session');
    expect(find.text('Test home'), findsOneWidget);
  });
}
