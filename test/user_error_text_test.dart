import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';
import 'package:viendongedu2_flutter/utils/user_error_text.dart';

void main() {
  test('Vietnamese validation guidance is preserved verbatim', () {
    const guidance = 'Vui lòng nhập CMND/CCCD gồm 9 hoặc 12 chữ số.';
    expect(userErrorText(EmsException(guidance, statusCode: 422)), guidance);
  });

  for (final status in [401, 403, 404, 409, 422, 500, null]) {
    test('English and machine errors get Vietnamese guidance ($status)', () {
      for (final raw in ['access_denied', 'Forbidden', '', '<html>Error</html>']) {
        final error = EmsException(raw, code: 'test_code', statusCode: status);
        final text = userErrorText(error);
        expect(text, contains('Vui lòng'));
        expect(text, isNot(contains('Forbidden')));
        expect(text, isNot(contains('access_denied')));
        expect(text, isNot(contains('<html>')));
        expect(error.code, 'test_code');
        expect(error.statusCode, status);
        expect(error.message, raw);
      }
    });
  }

  test('technical exception details never become UI text', () {
    final errors = <Object>[
      const FormatException('Invalid payload'),
      StateError('Missing test value'),
      EmsException('FormatException: Dữ liệu không hợp lệ'),
    ];
    for (final error in errors) {
      expect(
        userErrorText(error),
        'Chưa xác nhận được kết quả. Vui lòng kiểm tra lại trước khi thử lại.',
      );
    }
  });

  group('HTTP error boundary', () {
    late http.Client original;
    setUp(() {
      original = EmsApiService.client;
      EmsApiService.resetConnectionState();
    });
    tearDown(() => EmsApiService.client = original);

    test('machine response keeps refusal metadata and uses Vietnamese copy', () async {
      EmsApiService.client = MockClient((_) async => http.Response(
        jsonEncode({'error': 'access_denied', 'message': 'Access denied'}),
        403,
      ));
      await expectLater(
        EmsApiService.send('GET', '/fictional-test'),
        throwsA(isA<EmsException>()
          .having((e) => e.code, 'code', 'access_denied')
          .having((e) => e.statusCode, 'status', 403)
          .having((e) => e.message, 'message', contains('liên hệ nhà trường'))),
      );
    });

    test('punch conflict retains the students needed by the reason dialog', () async {
      EmsApiService.client = MockClient((_) async => http.Response(
        jsonEncode({
          'code': 'punch_conflict_needs_reason',
          'error': 'punch_conflict',
          'students': [{'mssv': 'TEST26VN01'}],
        }),
        422,
      ));
      await expectLater(
        EmsApiService.send('GET', '/fictional-test'),
        throwsA(isA<EmsPunchConflict>()
          .having((e) => e.code, 'code', 'punch_conflict_needs_reason')
          .having((e) => e.students.single.mssv, 'student', 'TEST26VN01')
          .having((e) => e.message, 'message', contains('Vui lòng'))),
      );
    });
  });
}
