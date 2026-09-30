// Characterization test for the classes screen ("Lớp học") and its detail page.
//
// Fixture is fictional (MSSV TEST260001, sections "TN…", subjects "Môn thử
// nghiệm …"). The mock client answers the endpoints the screen reads:
//   GET /student/me/sections[?semester=]  → enrolment rows
//   GET /student/me/grades                → scores matched by section_code
//   GET /student/me/attendance-ems        → per-session marks (detail page)
//
//   flutter test test/classes_screen_test.dart
//
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:viendongedu2_flutter/features/classes/classes_screen.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

Map<String, dynamic> _section(String sem, String code, String subj,
        String name, int credits) =>
    {
      'semester_code': sem,
      'section_id': 1,
      'section_code': code,
      'subject_code': subj,
      'subject_name': name,
      'credits': credits,
      'teacher_name': 'GV Thử Nghiệm',
    };

final _allSections = [
  _section('252', 'TN252A', 'TN101', 'Môn thử nghiệm A', 3),
  _section('252', 'TN252B', 'TN102', 'Môn thử nghiệm B', 2),
  _section('251', 'TN251C', 'TN103', 'Môn thử nghiệm C', 0),
];

final _gradesBody = {
  'mssv': 'TEST260001',
  'grades': [
    {
      'grade_id': 1,
      'semester_code': '252',
      'section_code': 'TN252A',
      'subject_code': 'TN101',
      'subject_name': 'Môn thử nghiệm A',
      'credits': 3,
      'midterm_score': 7.5,
      'final_exam_score': 9.0,
      'final_score': 8.5,
    },
    // No section_code → matched by subject_code + semester.
    {
      'grade_id': 2,
      'semester_code': '252',
      'subject_code': 'TN102',
      'subject_name': 'Môn thử nghiệm B',
      'credits': 2,
      'final_score': 6.0,
    },
  ],
};

final _attendanceBody = {
  'marks': [
    {'session_date': '2026-03-02T00:00:00.000Z', 'status': 'present', 'section_code': 'TN252A'},
    {'session_date': '2026-03-09T00:00:00.000Z', 'status': 'absent', 'section_code': 'TN252A'},
    {'session_date': '2026-03-16T00:00:00.000Z', 'status': 'excused', 'section_code': 'TN252A'},
    {'session_date': '2026-03-02T00:00:00.000Z', 'status': 'present', 'section_code': 'OTHER'},
  ],
};

int sectionsCalls = 0;

MockClient _server({
  List<Map<String, dynamic>>? sections,
  int sectionsStatus = 200,
}) {
  sectionsCalls = 0;
  return MockClient((req) async {
    final path = req.url.path;
    if (path.endsWith('/student/me/sections')) {
      sectionsCalls++;
      if (sectionsStatus != 200) {
        return http.Response('{"error":"boom"}', sectionsStatus,
            headers: _json);
      }
      final all = sections ?? _allSections;
      final sem = req.url.queryParameters['semester'];
      final rows = sem == null
          ? all
          : all.where((s) => s['semester_code'] == sem).toList();
      return http.Response(jsonEncode({'mssv': 'TEST260001', 'sections': rows}),
          200,
          headers: _json);
    }
    if (path.endsWith('/student/me/grades')) {
      return http.Response(jsonEncode(_gradesBody), 200, headers: _json);
    }
    if (path.endsWith('/student/me/attendance-ems')) {
      return http.Response(jsonEncode(_attendanceBody), 200, headers: _json);
    }
    return http.Response('{}', 404, headers: _json);
  });
}

void main() {
  tearDown(() => EmsApiService.client = http.Client());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ClassesScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('latest semester selected first; cards show class info',
      (tester) async {
    EmsApiService.client = _server();
    await pump(tester);

    expect(find.text('Lớp học'), findsOneWidget);
    expect(find.text('Học kỳ 2, 2025 - 2026'), findsOneWidget);
    expect(find.text('2 lớp học'), findsOneWidget);
    expect(find.text('Môn thử nghiệm A'), findsOneWidget);
    expect(find.text('Môn thử nghiệm B'), findsOneWidget);
    expect(find.text('Môn thử nghiệm C'), findsNothing);
    expect(find.text('3 TC'), findsOneWidget);
    expect(find.text('2 TC'), findsOneWidget);
    expect(find.text('TN252A'), findsOneWidget);
    expect(find.text('GV Thử Nghiệm'), findsNWidgets(2));
  });

  testWidgets('choosing another semester reloads its classes', (tester) async {
    EmsApiService.client = _server();
    await pump(tester);

    await tester.tap(find.text('Học kỳ 2, 2025 - 2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Học kỳ 1, 2025 - 2026').last);
    await tester.pumpAndSettle();

    expect(find.text('1 lớp học'), findsOneWidget);
    expect(find.text('Môn thử nghiệm C'), findsOneWidget);
    expect(find.text('Môn thử nghiệm A'), findsNothing);
    expect(find.text('0 TC'), findsNothing); // credits 0 → no chip
  });

  testWidgets('detail page: info, scores (section + subject fallback), attendance',
      (tester) async {
    EmsApiService.client = _server();
    await pump(tester);

    await tester.tap(find.text('Môn thử nghiệm A'));
    await tester.pumpAndSettle();

    expect(find.text('Học kỳ 2, 2025 - 2026'), findsOneWidget);
    expect(find.text('Mã lớp'), findsOneWidget);
    expect(find.text('Mã môn'), findsOneWidget);
    expect(find.text('TN101'), findsOneWidget);
    expect(find.text('Điểm số'), findsOneWidget);
    expect(find.text('Chuyên cần'), findsNothing);
    expect(find.text('Giữa kỳ'), findsOneWidget);
    expect(find.text('7.5'), findsOneWidget);
    expect(find.text('Cuối kỳ'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
    expect(find.text('Tổng kết'), findsOneWidget);
    expect(find.text('8.5'), findsOneWidget);
    expect(find.text('Thống kê điểm danh'), findsOneWidget);
    expect(find.text('33%'), findsOneWidget); // 1 present of 3 (OTHER excluded)
    expect(find.text('Tổng: 3 buổi'), findsOneWidget);
    expect(find.text('Chi tiết các buổi học'), findsOneWidget);
    expect(find.text('Buổi 3'), findsOneWidget);
    expect(find.text('02/03/2026'), findsOneWidget);
    expect(find.text('Có mặt'), findsWidgets);
    expect(find.text('Vắng mặt'), findsWidgets);
    expect(find.text('Báo nghỉ'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_ios));
    await tester.pumpAndSettle();
    expect(find.text('2 lớp học'), findsOneWidget);

    await tester.tap(find.text('Môn thử nghiệm B'));
    await tester.pumpAndSettle();
    expect(find.text('Điểm số'), findsOneWidget);
    expect(find.text('6.0'), findsOneWidget); // subject+semester fallback
    expect(find.text('Giữa kỳ'), findsNothing);
    expect(find.text('Thống kê điểm danh'), findsNothing); // no marks for TN252B
  });

  testWidgets('no enrolments → empty state', (tester) async {
    EmsApiService.client = _server(sections: []);
    await pump(tester);

    expect(find.text('Không có lớp học'), findsOneWidget);
    expect(find.byType(DropdownButton<dynamic>), findsNothing);
  });

  testWidgets('server error → retry state; retry loads classes',
      (tester) async {
    EmsApiService.client = _server(sectionsStatus: 404);
    await pump(tester);

    expect(find.text('Lớp học'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);

    EmsApiService.client = _server();
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Thử lại'), findsNothing);
    expect(find.text('2 lớp học'), findsOneWidget);
  });

  testWidgets('pull to refresh reloads the selected semester', (tester) async {
    EmsApiService.client = _server();
    await pump(tester);
    final before = sectionsCalls; // 1 (all) + 1 (semester)
    expect(before, 2);

    await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(sectionsCalls, before + 1);
    expect(find.text('2 lớp học'), findsOneWidget);
  });
}
