import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viendongedu2_flutter/models/crm_identity.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';
import 'package:viendongedu2_flutter/services/offline_snapshot.dart';

http.Response _json(Object body, {int status = 200, Map<String, String>? h}) =>
    http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json', ...?h},
    );

void main() {
  late http.Client original;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    original = EmsApiService.client;
    EmsApiService.retryDelay = (_) => Duration.zero;
    EmsApiService.resetConnectionState();
    final s = AppSession.instance;
    s.emsToken = 'test-token';
    s.role = CrmRole.student;
    s.mssv = 'TEST260001';
  });

  tearDown(() {
    EmsApiService.client = original;
    AppSession.instance.emsToken = null;
  });

  test('two parallel identical GETs make one request', () async {
    var calls = 0;
    EmsApiService.client = MockClient((_) async {
      calls++;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return _json({'ok': true});
    });
    final r = await Future.wait([
      EmsApiService.send('GET', '/x'),
      EmsApiService.send('GET', '/x'),
    ]);
    expect(calls, 1);
    expect(r[0], r[1]);
  });

  test('requests carry X-Request-Id', () async {
    late http.BaseRequest seen;
    EmsApiService.client = MockClient((req) async {
      seen = req;
      return _json({});
    });
    await EmsApiService.send('GET', '/x');
    expect(seen.headers['X-Request-Id'], matches(RegExp(r'^[0-9a-f]{32}$')));
  });

  test('GET is retried once on 503', () async {
    var calls = 0;
    EmsApiService.client = MockClient((_) async {
      calls++;
      return calls == 1
          ? _json({'code': 'server_busy'}, status: 503, h: {'retry-after': '0'})
          : _json({'ok': 1});
    });
    expect(await EmsApiService.send('GET', '/x'), {'ok': 1});
    expect(calls, 2);
  });

  test('persistent 503 gives the busy message after one retry', () async {
    var calls = 0;
    EmsApiService.client = MockClient((_) async {
      calls++;
      return _json({'code': 'server_busy'}, status: 503);
    });
    await expectLater(
      EmsApiService.send('GET', '/x'),
      throwsA(
        isA<EmsException>().having(
          (e) => e.message,
          'message',
          'Máy chủ đang bận, vui lòng thử lại sau giây lát.',
        ),
      ),
    );
    expect(calls, 2);
  });

  test('POST is never retried', () async {
    var calls = 0;
    EmsApiService.client = MockClient((_) async {
      calls++;
      return _json({'code': 'server_busy'}, status: 503);
    });
    await expectLater(
      EmsApiService.send('POST', '/x', body: {'a': 1}),
      throwsA(isA<EmsException>()),
    );
    expect(calls, 1);
  });

  test('304 returns the stored body as fresh', () async {
    var calls = 0;
    String? inm;
    EmsApiService.client = MockClient((req) async {
      calls++;
      if (calls == 1) return _json({'v': 1}, h: {'etag': '"abc"'});
      inm = req.headers['If-None-Match'];
      return http.Response('', 304);
    });
    await EmsApiService.sendCached('/student/me/schedule');
    final r = await EmsApiService.sendCached('/student/me/schedule');
    expect(inm, '"abc"');
    expect(r.data, {'v': 1});
    expect(r.fresh, isTrue);
  });

  test('failed refresh returns stored data with fresh=false', () async {
    var calls = 0;
    EmsApiService.client = MockClient((_) async {
      calls++;
      if (calls == 1) return _json({'v': 2}, h: {'etag': '"e"'});
      throw http.ClientException('offline');
    });
    await EmsApiService.sendCached('/teacher/me/classes');
    final r = await EmsApiService.sendCached('/teacher/me/classes');
    expect(r.data, {'v': 2});
    expect(r.fresh, isFalse);
  });

  test('failed refresh with nothing stored throws', () async {
    EmsApiService.client = MockClient((_) async => throw Exception('x'));
    await expectLater(
      EmsApiService.sendCached('/teacher/me/overview'),
      throwsA(isA<EmsException>()),
    );
  });

  test('logout clears the cache', () async {
    var calls = 0;
    EmsApiService.client = MockClient((_) async {
      calls++;
      if (calls == 1) return _json({'v': 3}, h: {'etag': '"z"'});
      throw http.ClientException('offline');
    });
    await EmsApiService.sendCached('/student/me/schedule');
    // AppSession.clear() runs this first; the rest needs Firebase.
    await OfflineSnapshot.clearCurrentAccount();
    AppSession.instance.emsToken = 'test-token';
    AppSession.instance.role = CrmRole.student;
    AppSession.instance.mssv = 'TEST260001';
    await expectLater(
      EmsApiService.sendCached('/student/me/schedule'),
      throwsA(isA<EmsException>()),
    );
  });

  test('tuition path is never written to the cache', () async {
    EmsApiService.client = MockClient(
      (_) async => _json({'owed': 0}, h: {'etag': '"t"'}),
    );
    await EmsApiService.send('GET', '/student/me/tuition');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys().where((k) => k.startsWith('offline_v1_')), isEmpty);
  });

  group('unsure network never sends a write', () {
    setUp(() => EmsApiService.probe = EmsApiService.defaultProbe);
    test(
      'write after a network failure: probe fails -> nothing sent',
      () async {
        final sent = <String>[];
        EmsApiService.client = MockClient((req) async {
          sent.add('${req.method} ${req.url.path}');
          throw http.ClientException('offline');
        });
        await expectLater(
          EmsApiService.send('POST', '/attendance/marks', body: {'x': 1}),
          throwsA(
            isA<EmsException>().having((e) => e.code, 'code', 'network_unsure'),
          ),
        );
        expect(sent.where((s) => s.startsWith('POST')), isEmpty);
      },
    );

    test(
      'recent good contact: write goes straight through, no probe',
      () async {
        final sent = <String>[];
        EmsApiService.client = MockClient((req) async {
          sent.add('${req.method} ${req.url.path}');
          return _json({'ok': true});
        });
        await EmsApiService.send('GET', '/student/me');
        await EmsApiService.send('POST', '/attendance/marks', body: {'x': 1});
        expect(sent.where((s) => s.endsWith('/app/min-version')), isEmpty);
        expect(sent.last, 'POST /api/attendance/marks');
      },
    );

    test(
      'no recent contact: reachable probe (any status) lets write through',
      () async {
        final sent = <String>[];
        EmsApiService.client = MockClient((req) async {
          sent.add('${req.method} ${req.url.path}');
          if (req.url.path.endsWith('/app/min-version')) {
            return _json({'error': 'x'}, status: 404);
          }
          return _json({'ok': true});
        });
        await EmsApiService.send('POST', '/attendance/marks', body: {'x': 1});
        expect(sent, [
          'GET /api/app/min-version',
          'POST /api/attendance/marks',
        ]);
      },
    );

    test('login is never blocked by the gate', () async {
      EmsApiService.client = MockClient((req) async {
        if (req.url.path.endsWith('/app/min-version')) {
          throw http.ClientException('offline');
        }
        return _json({
          'token': 't',
          'student': {'mssv': 'TEST260001'},
        });
      });
      await EmsApiService.send(
        'POST',
        '/auth/student/login',
        body: {'mssv': 'TEST260001', 'password': 'x'},
        auth: false,
      );
    });
  });
}
