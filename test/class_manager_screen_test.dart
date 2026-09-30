// Characterization test for the teacher "Quản lý lớp" screen (read-only).
//
// Fictional data only (THUNGHIEM / TEST26…). The mock client answers:
//   GET /teacher/me/semesters
//   GET /teacher/me/classes?semester=
//   GET /teacher/me/schedule/semester?semester=   (gives lmhid per section)
//   GET /teacher/me/classes/:id/students
//   GET /teacher/me/classes/:id/attendance
//   GET /attendance/session-marks?session_key=
//
//   flutter test test/class_manager_screen_test.dart
//
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';
import 'package:viendongedu2_flutter/screens/gv_quanly_lop_screen.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

Map<String, dynamic> _class(String id, String code, String subj, String name,
        int credits, int enrolled, String sem) =>
    {
      'section_id': id,
      'section_code': code,
      'semester_code': sem,
      'room': 'P.101',
      'ngay_bat_dau': '2026-02-16T00:00:00.000Z',
      'ngay_ket_thuc': '2026-06-20T00:00:00.000Z',
      'ngay_thi': '2026-06-28T00:00:00.000Z',
      'subject_code': subj,
      'subject_name': name,
      'credits': credits,
      'enrolled_students': enrolled,
    };

final _classes = {
  '261': [
    _class('sec-a', 'TN261A', 'TN101', 'Môn thử nghiệm A', 3, 3, '261'),
    _class('sec-b', 'TN261B', 'TN102', 'Môn thử nghiệm B', 0, 2, '261'),
  ],
  '252': [
    _class('sec-c', 'TN252C', 'TN103', 'Môn thử nghiệm C', 2, 1, '252'),
  ],
};

Map<String, dynamic> _att(String sid, String date, String mssv, String name,
        String status) =>
    {
      'session_id': sid,
      'date': date,
      'start_time': '07:00',
      'end_time': '09:30',
      'room': 'P.101',
      'mssv': mssv,
      'full_name': name,
      'status': status,
    };

final _attendanceA = [
  _att('s1', '2026-03-02', 'TEST260001', 'An Thử Nghiệm', 'present'),
  _att('s1', '2026-03-02', 'TEST260002', 'Bình Thử Nghiệm', 'absent'),
  _att('s1', '2026-03-02', 'TEST260003', 'Chi Thử Nghiệm', 'present'),
  _att('s2', '2026-03-09', 'TEST260001', 'An Thử Nghiệm', 'present'),
  _att('s2', '2026-03-09', 'TEST260002', 'Bình Thử Nghiệm', 'present'),
  _att('s2', '2026-03-09', 'TEST260003', 'Chi Thử Nghiệm', 'absent'),
];

const _students = [
  {'enrollment_id': 'e1', 'mssv': 'TEST260001', 'full_name': 'An Thử Nghiệm'},
  {'enrollment_id': 'e2', 'mssv': 'TEST260002', 'full_name': 'Bình Thử Nghiệm'},
  {'enrollment_id': 'e3', 'mssv': 'TEST260003', 'full_name': 'Chi Thử Nghiệm'},
];

MockClient _server({int semestersStatus = 200, int marksStatus = 200}) {
  return MockClient((req) async {
    final p = req.url.path;
    if (p.endsWith('/teacher/me/semesters')) {
      if (semestersStatus != 200) {
        return http.Response('{"error":"boom"}', semestersStatus,
            headers: _json);
      }
      return http.Response(
          jsonEncode([
            {'id': 252, 'ma': '252', 'ten': 'Học kỳ 2, 2025 - 2026'},
            {'id': 261, 'ma': '261', 'ten': 'Học kỳ 1, 2026 - 2027'},
          ]),
          200,
          headers: _json);
    }
    if (p.endsWith('/teacher/me/schedule/semester')) {
      return http.Response(
          jsonEncode({
            'data': [
              {'lmhid': '90001', 'lmhma': 'TN261A'},
            ],
          }),
          200,
          headers: _json);
    }
    if (p.endsWith('/teacher/me/classes')) {
      final sem = req.url.queryParameters['semester'];
      return http.Response(jsonEncode({'classes': _classes[sem]}), 200,
          headers: _json);
    }
    if (p.endsWith('/teacher/me/classes/sec-a/students')) {
      return http.Response(jsonEncode({'students': _students}), 200,
          headers: _json);
    }
    if (p.endsWith('/teacher/me/classes/sec-a/attendance')) {
      return http.Response(jsonEncode({'attendance': _attendanceA}), 200,
          headers: _json);
    }
    if (p.endsWith('/attendance/session-marks')) {
      if (marksStatus != 200) {
        return http.Response('{"error":"boom"}', marksStatus, headers: _json);
      }
      final key = req.url.queryParameters['session_key'];
      final marks = key == '90001:07-00:2026-03-02'
          ? [
              {'mssv': 'TEST260001', 'status': 'present'},
              {'mssv': 'TEST260002', 'status': 'absent'},
              {'mssv': 'TEST260003', 'status': 'late'},
            ]
          : <Map<String, String>>[];
      return http.Response(jsonEncode({'marks': marks}), 200, headers: _json);
    }
    return http.Response('{}', 404, headers: _json);
  });
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => EmsApiService.client = http.Client());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: const GvQuanLyLopScreen(),
      routes: {'/login': (_) => const Scaffold(body: Text('route:login'))},
    ));
    await tester.pumpAndSettle();
  }

  Future<void> openClassA(WidgetTester tester) async {
    await tester.tap(find.textContaining('Môn thử nghiệm A', findRichText: true));
    await tester.pumpAndSettle();
  }

  testWidgets('latest semester first; cards show class info', (tester) async {
    EmsApiService.client = _server();
    await pump(tester);

    expect(find.text('Quản lý lớp'), findsOneWidget);
    expect(find.text('Học kỳ 1, 2026 - 2027'), findsOneWidget);
    expect(find.text('2 lớp'), findsOneWidget);
    expect(find.textContaining('Môn thử nghiệm A', findRichText: true), findsOneWidget);
    expect(find.textContaining('Môn thử nghiệm B', findRichText: true), findsOneWidget);
    expect(find.text('TN261A'), findsOneWidget);
    expect(find.text('3 tín chỉ'), findsOneWidget); // credits 0 → no chip
    expect(find.text('3 SV'), findsOneWidget);
    expect(find.text('2 SV'), findsOneWidget);
  });

  testWidgets('choosing another semester reloads its classes', (tester) async {
    EmsApiService.client = _server();
    await pump(tester);

    await tester.tap(find.text('Học kỳ 1, 2026 - 2027'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Học kỳ 2, 2025 - 2026').last);
    await tester.pumpAndSettle();

    expect(find.text('1 lớp'), findsOneWidget);
    expect(find.textContaining('Môn thử nghiệm C', findRichText: true), findsOneWidget);
    expect(find.textContaining('Môn thử nghiệm A', findRichText: true), findsNothing);
  });

  testWidgets('class sheet: info tab then students tab', (tester) async {
    EmsApiService.client = _server();
    await pump(tester);
    await openClassA(tester);

    expect(find.text('Thông tin'), findsOneWidget);
    expect(find.text('Mã lớp'), findsOneWidget);
    expect(find.text('Tín chỉ'), findsOneWidget);
    expect(find.text('3 TC'), findsOneWidget);
    expect(find.text('Phòng'), findsOneWidget);
    expect(find.text('3 sinh viên'), findsOneWidget);
    expect(find.text('16/02/2026 – 20/06/2026'), findsOneWidget);
    expect(find.text('28/06/2026'), findsOneWidget);

    await tester.tap(find.text('Danh sách'));
    await tester.pumpAndSettle();
    expect(find.text('Tổng: 3 sinh viên'), findsOneWidget);
    expect(find.text('An Thử Nghiệm'), findsOneWidget);
    expect(find.text('TEST260002'), findsOneWidget);
    expect(find.text('Chi Thử Nghiệm'), findsOneWidget);
  });

  testWidgets('class sheet: sessions tab (EMS vs CRM counts) and summary',
      (tester) async {
    EmsApiService.client = _server();
    await pump(tester);
    await openClassA(tester);

    await tester.tap(find.text('Điểm danh'));
    await tester.pumpAndSettle();

    expect(find.text('02/03/2026'), findsOneWidget);
    expect(find.text('09/03/2026'), findsOneWidget);
    expect(find.text('07:00 – 09:30'), findsNWidgets(2));
    // s1 has EMS marks: present + late = 2 of 3.
    expect(find.text('2 / 3 có mặt (EMS)'), findsOneWidget);
    expect(find.text('Đã ĐD'), findsOneWidget);
    // s2 has no EMS marks: CRM fallback wording.
    expect(find.text('2 / 3 có mặt trên CRM — chưa xác nhận trên EMS'),
        findsOneWidget);
    expect(find.text('Chưa ĐD'), findsOneWidget);

    await tester.tap(find.text('Tổng hợp'));
    await tester.pumpAndSettle();
    expect(find.text('2/2'), findsOneWidget); // An
    expect(find.text('1/2'), findsNWidgets(2)); // Bình, Chi
    expect(find.text('An Thử Nghiệm'), findsOneWidget);
  });

  testWidgets('opening one session shows EMS present/absent/late',
      (tester) async {
    EmsApiService.client = _server();
    await pump(tester);
    await openClassA(tester);
    await tester.tap(find.text('Điểm danh'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('2 / 3 có mặt (EMS)'));
    await tester.pumpAndSettle();

    expect(find.text('Có mặt'), findsNWidgets(3)); // pill + 2 rows
    expect(find.text('Vắng'), findsNWidgets(2)); // pill + 1 row
    expect(find.text('Chưa ĐD'), findsNWidgets(2)); // pill (0) + s2 badge underneath
    expect(find.text('Chưa điểm danh'), findsNothing);
    expect(find.text('An Thử Nghiệm'), findsWidgets);
  });

  testWidgets('session without EMS marks lists students as not yet marked',
      (tester) async {
    EmsApiService.client = _server();
    await pump(tester);
    await openClassA(tester);
    await tester.tap(find.text('Điểm danh'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('chưa xác nhận trên EMS'));
    await tester.pumpAndSettle();

    expect(find.text('Chưa điểm danh'), findsNWidgets(3));
  });

  testWidgets('session marks error shows retry', (tester) async {
    EmsApiService.client = _server(marksStatus: 500);
    await pump(tester);
    await openClassA(tester);
    await tester.tap(find.text('Điểm danh'));
    await tester.pumpAndSettle();
    // Class-level EMS counts swallow the errors → both rows show CRM wording.
    await tester.tap(find.text('2 / 3 có mặt trên CRM — chưa xác nhận trên EMS').first);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('Thử lại'), findsOneWidget);
  });

  testWidgets('server error → retry state; retry loads classes',
      (tester) async {
    EmsApiService.client = _server(semestersStatus: 500);
    await pump(tester);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('Thử lại'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);

    EmsApiService.client = _server();
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('2 lớp'), findsOneWidget);
  });

  testWidgets('401 clears the session and goes to /login', (tester) async {
    EmsApiService.client = _server(semestersStatus: 401);
    await pump(tester);
    expect(find.text('route:login'), findsOneWidget);
  });
}
