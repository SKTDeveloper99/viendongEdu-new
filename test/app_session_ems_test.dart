import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    EmsApiService.client = http.Client();
    final session = AppSession.instance;
    session
      ..token = 'ims-test-token'
      ..emsToken = null
      ..emsDenied = false
      ..hocVien = null
      ..giangVien = null;
  });

  tearDown(() => EmsApiService.client = http.Client());

  test('an expired EMS exchange does not poison later retries', () async {
    var calls = 0;
    EmsApiService.client = MockClient((_) async {
      calls += 1;
      if (calls == 1) {
        return http.Response(
          jsonEncode({'error': 'expired_token'}),
          401,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode({'crm_token': 'fresh-ems-token'}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    expect(await AppSession.instance.refreshEmsToken(force: true), isFalse);
    expect(AppSession.instance.emsDenied, isFalse);
    expect(await AppSession.instance.refreshEmsToken(), isTrue);
    expect(AppSession.instance.emsToken, 'fresh-ems-token');
    expect(calls, 2);
  });

  test('a fresh login attempt may recover from an earlier denial', () async {
    var calls = 0;
    EmsApiService.client = MockClient((_) async {
      calls += 1;
      if (calls == 1) {
        return http.Response(
          jsonEncode({'error': 'account_deactivated'}),
          403,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode({'crm_token': 'allowed-again'}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    expect(await AppSession.instance.refreshEmsToken(force: true), isFalse);
    expect(AppSession.instance.emsDenied, isTrue);
    expect(await AppSession.instance.refreshEmsToken(), isFalse);
    expect(calls, 1);

    expect(await AppSession.instance.refreshEmsToken(force: true), isTrue);
    expect(AppSession.instance.emsToken, 'allowed-again');
    expect(calls, 2);
  });

  test('simultaneous callers share one EMS mirror request', () async {
    var calls = 0;
    EmsApiService.client = MockClient((_) async {
      calls += 1;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return http.Response(
        jsonEncode({'crm_token': 'one-token'}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final results = await Future.wait([
      AppSession.instance.refreshEmsToken(force: true),
      AppSession.instance.refreshEmsToken(force: true),
    ]);

    expect(results, [isTrue, isTrue]);
    expect(calls, 1);
  });

  test('teacher schedule cannot fall back to an IMS attendance writer', () {
    final source = File(
      'lib/screens/gv_schedule_screen.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('GvAttendanceScreen')));
    expect(source, isNot(contains('GvQrAttendanceScreen')));
    expect(source, isNot(contains('postDiemDanhLuu')));
    expect(source, contains('EmsAttendanceTeacherScreen'));
  });
}
