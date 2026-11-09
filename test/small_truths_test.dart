// Item 9: small truths on student screens. Fixtures fictional.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:viendongedu2_flutter/screens/capbu_screen.dart';
import 'package:viendongedu2_flutter/screens/hv_profile_info_screen.dart';
import 'package:viendongedu2_flutter/screens/lephi_screen.dart';
import 'package:viendongedu2_flutter/screens/schedule_screen.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';
import 'package:viendongedu2_flutter/utils/money_text.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

void _serve(Map<String, Object> bodies) {
  AppSession.instance.emsToken = 'test-token';
  EmsApiService.client = MockClient((req) async {
    final path = req.url.path.replaceFirst('/api', '');
    return http.Response(jsonEncode(bodies[path] ?? {}), 200, headers: _json);
  });
}

void main() {
  tearDown(() {
    EmsApiService.client = http.Client();
    AppSession.instance.emsToken = null;
  });

  test('money: thousands dots, whole đồng, explicit unknown', () {
    expect(vndText(1500000, unknown: '?'), '1.500.000 đ');
    expect(vndText(1500000.0, unknown: '?'), '1.500.000 đ');
    expect(vndText(-25000, unknown: '?'), '-25.000 đ');
    expect(vndText(0, unknown: '?'), '0 đ');
    expect(vndText(null, unknown: 'chưa có dữ liệu'), 'chưa có dữ liệu');
  });

  testWidgets('profile hides the always-blank CCCD and Chuyên ngành rows', (
    t,
  ) async {
    _serve({
      '/student/me': {
        'student': {
          'mssv': 'TEST2600001',
          'full_name': 'Học Viên Thử Nghiệm',
          'class_code': 'TEST-CLASS',
        },
      },
    });
    await t.pumpWidget(const MaterialApp(home: HvProfileInfoScreen()));
    await t.pumpAndSettle();
    expect(find.text('Học Viên Thử Nghiệm'), findsWidgets);
    expect(find.text('CCCD'), findsNothing);
    expect(find.text('Chuyên ngành'), findsNothing);
    expect(find.text('Ngành'), findsOneWidget);
  });

  testWidgets('Lịch học header dates are dd/MM/yyyy', (t) async {
    _serve({
      '/student/me/schedule': {'schedule': []},
      '/student/me/exams': {'exams': []},
      '/student/me/attendance-ems': {'marks': []},
    });
    await t.pumpWidget(
      MaterialApp(home: ScheduleScreen(now: () => DateTime(2026, 9, 30, 8))),
    );
    await t.pumpAndSettle();
    expect(find.text('28/09 – 04/10/2026'), findsOneWidget);
    expect(find.text('30/09/2026'), findsOneWidget);
    expect(find.text('28/9 – 4/10/2026'), findsNothing);
  });

  testWidgets('Cấp bù amount has thousands dots', (t) async {
    _serve({
      '/student/me/capbu': {
        'mssv': 'TEST2600001',
        'count': 1,
        'items': [
          {'id': '1', 'ten': 'Cấp bù thử nghiệm', 'thanh_tien': 1250000.0},
        ],
      },
    });
    await t.pumpWidget(const MaterialApp(home: CapBuScreen()));
    await t.pumpAndSettle();
    expect(find.text('1.250.000 đ'), findsOneWidget);
    expect(find.textContaining('1250000'), findsNothing);
  });

  testWidgets('Lệ phí unknown amount reads "Chưa xác định"', (t) async {
    _serve({
      '/student/me/fees': {
        'mssv': 'TEST2600001',
        'totals': {'le_phi_khac': null},
        'items': [
          {
            'phieu_thu_id': '1',
            'loai_phieu_thu': 'Lệ phí thử nghiệm',
            'so_tien': null,
          },
        ],
      },
    });
    await t.pumpWidget(const MaterialApp(home: LePhiScreen()));
    await t.pumpAndSettle();
    expect(find.text('Chưa xác định'), findsWidgets);
    expect(find.textContaining('luật'), findsNothing);
  });
}
