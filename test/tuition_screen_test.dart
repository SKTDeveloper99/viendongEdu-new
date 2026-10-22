import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:viendongedu2_flutter/screens/tuition_screen.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';

void main() {
  tearDown(() => EmsApiService.client = http.Client());

  testWidgets('unknown tuition amount keeps the reconciliation voice', (
    tester,
  ) async {
    AppSession.instance.emsToken = 'test-token';
    EmsApiService.client = MockClient((request) async {
      final body = request.url.path.endsWith('/tuition')
          ? {
              'mssv': 'TEST2600001',
              'summary': {'money_known': false},
              'payments': [],
            }
          : {'mssv': 'TEST2600001', 'computable': false};
      return http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    await tester.pumpWidget(const MaterialApp(home: TuitionScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Đang đối chiếu'), findsOneWidget);
    expect(find.text('0 đ'), findsNothing);
  });
}
