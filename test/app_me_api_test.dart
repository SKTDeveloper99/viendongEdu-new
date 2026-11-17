import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viendongedu2_flutter/features/work_home/app_me_api.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSession.instance.emsToken = 'a-real-token';
  });
  tearDown(() {
    EmsApiService.client = http.Client();
    AppSession.instance.emsToken = null;
  });

  test(
    'a first /app/me that never answers is retried once by itself',
    () async {
      var calls = 0;
      EmsApiService.client = MockClient((req) async {
        calls++;
        if (calls == 1) throw TimeoutException('slow cold start');
        return http.Response(
          jsonEncode({
            'day_card': {'id': '2026-11-20:teachers_day', 'title': 'T'},
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final me = await AppMeApi.me(retryAfter: Duration.zero);
      expect(calls, 2);
      expect((me['day_card'] as Map)['id'], '2026-11-20:teachers_day');
    },
  );

  test('a refusal is not retried', () async {
    var calls = 0;
    EmsApiService.client = MockClient((req) async {
      calls++;
      return http.Response('{"error":"no"}', 403);
    });
    await expectLater(
      AppMeApi.me(retryAfter: Duration.zero),
      throwsA(isA<EmsException>()),
    );
    expect(calls, 1);
  });
}
