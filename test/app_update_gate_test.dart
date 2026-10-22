import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viendongedu2_flutter/services/app_update_gate.dart';

void main() {
  late http.Client original;
  setUp(() => original = EmsApiService.client);
  tearDown(() => EmsApiService.client = original);

  for (final failure in ['offline', 'timeout', '500', '401', 'malformed', 'shape']) {
    test('optional version lookup fails open for $failure', () async {
      EmsApiService.client = MockClient((_) async {
        switch (failure) {
          case 'offline': throw http.ClientException('test-offline');
          case 'timeout': throw TimeoutException('test-timeout');
          case '500': return http.Response('server_error', 500);
          case '401': return http.Response('unauthorized', 401);
          case 'shape': return http.Response('[]', 200);
          default: return http.Response('{broken', 200);
        }
      });
      expect(await AppUpdateGate.minimumVersion(), isNull);
    });
  }

  testWidgets('a hanging version lookup gives up after two seconds', (tester) async {
    EmsApiService.client = MockClient((_) => Completer<http.Response>().future);
    var finished = false;
    Map<String, dynamic>? result;
    final request = AppUpdateGate.minimumVersion().then((value) {
      finished = true;
      result = value;
    });
    await tester.pump();
    expect(finished, isFalse);
    await tester.pump(const Duration(seconds: 2));
    await request;
    expect(finished, isTrue);
    expect(result, isNull);
  });

  test('a build below the server minimum is outdated', () {
    expect(AppUpdateGate.isOutdated('1.1.44+86', '6.0.4'), isTrue);
    expect(AppUpdateGate.isOutdated('6.0.3+3', '6.0.4'), isTrue);
    expect(AppUpdateGate.isOutdated('6.0.4+4', '6.0.4'), isFalse);
    expect(AppUpdateGate.isOutdated('6.0.5', '6.0.4'), isFalse);
    expect(AppUpdateGate.isOutdated('6.1.0', '6.0.4'), isFalse);
  });

  test('garbage never locks a user out', () {
    expect(AppUpdateGate.isOutdated('', '6.0.4'), isFalse);
    expect(AppUpdateGate.isOutdated('6.0.4', ''), isFalse);
    expect(AppUpdateGate.isOutdated('x.y', '6.0.4'), isFalse);
  });
}
