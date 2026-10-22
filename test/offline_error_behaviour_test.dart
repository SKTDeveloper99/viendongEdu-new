import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viendongedu2_flutter/models/crm_identity.dart';
import 'package:viendongedu2_flutter/screens/registration_screen.dart';
import 'package:viendongedu2_flutter/screens/student_board_screen.dart';
import 'package:viendongedu2_flutter/screens/tuition_screen.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/crm_money_api.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';

http.Response json(Object data) => http.Response(
  jsonEncode(data),
  200,
  headers: {'content-type': 'application/json'},
);

void main() {
  late http.Client original;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    original = EmsApiService.client;
    EmsApiService.resetConnectionState();
    AppSession.instance
      ..emsToken = 'test-session'
      ..role = CrmRole.student
      ..mssv = 'TEST260001';
  });
  tearDown(() {
    EmsApiService.client = original;
    AppSession.instance.emsToken = null;
  });

  testWidgets(
    'cached tuition survives a failed separate debt lookup and retries',
    (tester) async {
      EmsApiService.client = MockClient(
        (_) async => json({
          'mssv': 'TEST260001',
          'summary': {'money_known': false},
          'payments': [],
        }),
      );
      await CrmMoneyApi.getTuition();
      var offline = true;
      var debtCalls = 0;
      EmsApiService.client = MockClient((req) async {
        if (req.url.path.endsWith('/cong-no')) {
          debtCalls++;
          if (offline) return http.Response('test-server-error', 500);
          return json({});
        }
        if (offline) throw http.ClientException('test-offline');
        return json({
          'summary': {'money_known': false},
          'payments': [],
        });
      });
      await tester.pumpWidget(const MaterialApp(home: TuitionScreen()));
      await tester.pumpAndSettle();
      expect(find.textContaining('dữ liệu cũ'), findsOneWidget);
      expect(find.textContaining('Chưa tải được sổ công nợ'), findsOneWidget);
      expect(find.text('Lịch sử giao dịch'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      offline = false;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(debtCalls, 2);
      expect(find.textContaining('dữ liệu cũ'), findsNothing);
    },
  );

  testWidgets(
    'board shows untagged stored data as old while refresh is pending',
    (tester) async {
      EmsApiService.client = MockClient(
        (_) async => json({
          'items': [
            {
              'id': 'TEST26',
              'title': 'Bảng tin thử nghiệm',
              'body': 'Nội dung thử nghiệm',
            },
          ],
        }),
      );
      await tester.pumpWidget(const MaterialApp(home: StudentBoardScreen()));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      final response = Completer<http.Response>();
      EmsApiService.client = MockClient((_) => response.future);
      await tester.pumpWidget(const MaterialApp(home: StudentBoardScreen()));
      await tester.pump();
      expect(find.textContaining('dữ liệu cũ'), findsOneWidget);
      expect(find.text('Bảng tin thử nghiệm'), findsOneWidget);
      response.complete(http.Response('test-server-error', 500));
      await tester.pumpAndSettle();
      expect(find.textContaining('dữ liệu cũ'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets('both registration reads may fail without an unhandled future', (
    tester,
  ) async {
    var failed = true;
    EmsApiService.client = MockClient((req) async {
      if (req.url.path.endsWith('/periods')) {
        return json({
          'periods': [
            {'period_id': 'TEST26', 'is_open': true},
          ],
        });
      }
      if (req.url.path.endsWith('/offerings')) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        if (failed) throw TimeoutException('test-timeout');
        return json({'offerings': []});
      }
      if (failed) return http.Response('test-server-error', 500);
      return json({'results': []});
    });
    await tester.pumpWidget(const MaterialApp(home: RegistrationScreen()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Vui lòng thử lại'), findsWidgets);
    failed = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
