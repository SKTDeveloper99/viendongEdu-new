import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viendongedu2_flutter/models/crm_identity.dart';
import 'package:viendongedu2_flutter/screens/ems_attendance_student_screen.dart';
import 'package:viendongedu2_flutter/screens/lephi_screen.dart';
import 'package:viendongedu2_flutter/screens/tuition_screen.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSession.instance
      ..emsToken = 'test-token'
      ..role = CrmRole.student
      ..mssv = 'TEST260001';
  });
  tearDown(() {
    EmsApiService.client.close();
    EmsApiService.client = http.Client();
    AppSession.instance
      ..emsToken = null
      ..role = null
      ..mssv = null;
  });

  for (final history in ['attendance', 'fees', 'tuition']) {
    testWidgets('$history builds visible rows and loads once across rebuilds', (
      tester,
    ) async {
      final calls = <String, int>{};
      final data = switch (history) {
        'attendance' => {
          'marks': List.generate(
            100,
            (i) => {
              'session_date': '2026-10-20',
              'subject_name': 'TEST26 row $i',
              'status': i.isEven ? 'present' : 'absent',
            },
          ),
        },
        'fees' => {
          'totals': {'le_phi_khac': 123456},
          'items': List.generate(
            100,
            (i) => {'loai_phieu_thu': 'TEST26 row $i', 'so_tien': 100},
          ),
        },
        _ => {
          'summary': {
            'money_known': true,
            'source': 'bang_ke',
            'owedTotal': 123456,
            'paid': 123456,
            'balance': 0,
          },
          'payments': List.generate(
            100,
            (i) => {'loai_phieu_thu': 'TEST26 row $i', 'so_tien': 100},
          ),
        },
      };
      final endpoint = history == 'attendance' ? 'attendance-ems' : history;
      EmsApiService.client = MockClient((request) async {
        final path = request.url.path;
        expect(request.method, 'GET');
        expect(path, anyOf(endsWith('/$endpoint'), endsWith('/cong-no')));
        calls.update(path, (n) => n + 1, ifAbsent: () => 1);
        return http.Response(
          jsonEncode(path.endsWith('/cong-no') ? {} : data),
          200,
        );
      });
      final screen = switch (history) {
        'attendance' => const EmsAttendanceStudentScreen(),
        'fees' => const LePhiScreen(),
        _ => const TuitionScreen(),
      };
      Widget app(Brightness brightness) => MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: screen,
      );
      await tester.pumpWidget(app(Brightness.light));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(RegExp(r'^TEST26 row ')).evaluate().length,
        lessThan(30),
      );
      expect(find.text('TEST26 row 99'), findsNothing);
      if (history != 'attendance') {
        expect(find.text('123.456 đ'), findsWidgets);
      }
      await tester.pumpWidget(app(Brightness.dark));
      await tester.pumpAndSettle();
      expect(calls.values, everyElement(1));
      expect(calls.length, history == 'tuition' ? 2 : 1);
      await tester.scrollUntilVisible(
        find.text('TEST26 row 99'),
        800,
        maxScrolls: 50,
      );
      expect(find.text('TEST26 row 99'), findsOneWidget);
      expect(calls.values, everyElement(1));
      expect(tester.takeException(), isNull);
    });
  }
}
