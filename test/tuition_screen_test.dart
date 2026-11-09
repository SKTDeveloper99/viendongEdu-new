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

  testWidgets('Học phí draws server notices; ledger card says Công nợ', (
    tester,
  ) async {
    _serve(
      {
        'mssv': 'TEST2600001',
        'summary': {
          'source': 'ims',
          'money_known': true,
          'owes': true,
          'owedTotal': 1000,
          'paid': 0,
          'balance': 1000,
        },
        'payments': [],
        'notices': [
          {'id': 'n1', 'level': 'warning', 'text': 'Thông báo thử nghiệm.'},
        ],
      },
      {
        'mssv': 'TEST2600001',
        'computable': true,
        'phai_nop': 1000,
        'da_nop': 0,
        'cong_no': 1000,
      },
    );
    await tester.pumpWidget(const MaterialApp(home: TuitionScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Thông báo thử nghiệm.'), findsOneWidget);
    expect(find.textContaining('buổi thi gần nhất'), findsNothing);
    expect(find.text('Công nợ'), findsOneWidget);
    expect(find.textContaining('IMS'), findsNothing);
    expect(find.textContaining('02/11'), findsNothing);
  });

  testWidgets('owing student on a server without notices sees the fallback', (
    tester,
  ) async {
    _serve(
      {
        'mssv': 'TEST2600001',
        'summary': {'source': 'bang_ke', 'money_known': true, 'owes': true},
        'payments': [],
      },
      {'mssv': 'TEST2600001', 'computable': false},
    );
    await tester.pumpWidget(const MaterialApp(home: TuitionScreen()));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Bạn còn nợ học phí. Vui lòng đóng trước buổi thi gần nhất để được dự thi.',
      ),
      findsOneWidget,
    );
  });
}

void _serve(Map<String, dynamic> tuition, Map<String, dynamic> congNo) {
  AppSession.instance.emsToken = 'test-token';
  EmsApiService.client = MockClient((request) async {
    final body = request.url.path.endsWith('/tuition') ? tuition : congNo;
    return http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
}
