// Characterization test for the grades screen ("Bảng điểm").
//
// Fixture is fictional (MSSV TEST260001, subjects "Môn thử nghiệm …") and the
// mock client answers the two endpoints the screen reads:
//   GET /student/me/grades              → per-subject rows
//   GET /student/me/graduation-summary  → academic totals + remaining subjects
//
//   flutter test test/grades_screen_test.dart
//
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:viendongedu2_flutter/features/grades/grades_screen.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

Map<String, dynamic> _grade(int id, String sem, String code, String name,
        int credits, double? score) =>
    {
      'grade_id': id,
      'semester_code': sem,
      'class_code': '06CD15THUNGHIEM',
      'final_score': score,
      'recorded_at': '2026-0${id + 1}-01T00:00:00.000Z',
      'subject_code': code,
      'subject_name': name,
      'credits': credits,
      'teacher_name': 'GV Thử Nghiệm',
    };

final _gradesBody = {
  'mssv': 'TEST260001',
  'summary': {
    'total': 4,
    'scored': 3,
    'passed': 2,
    'failed': 1,
    'average_score': 6.0
  },
  'grades': [
    _grade(1, '251', 'TN101', 'Môn thử nghiệm A', 3, 9.0),
    _grade(2, '251', 'TN102', 'Môn thử nghiệm B', 2, 3.0),
    _grade(3, '252', 'TN102', 'Môn thử nghiệm B', 2, 6.0),
    _grade(4, '252', 'TN103', 'Môn thử nghiệm D', 1, null),
  ],
};

final _summaryBody = {
  'academic': {
    'total': 4,
    'scored': 3,
    'passed': 2,
    'failed': 1,
    'average_score': 6.0,
    'has_curriculum': true,
    'required_subjects': 5,
    'required_passed': 2,
    'remaining_subjects_count': 3,
    'academically_clear': false,
  },
  'remaining_subjects': [
    {
      'subject_code': 'TN201',
      'subject_name': 'Môn thử nghiệm E',
      'credits': 2,
      'completion_status': 'pending'
    },
    {
      'subject_code': 'TN202',
      'subject_name': 'Môn thử nghiệm F',
      'credits': 3,
      'completion_status': 'failed'
    },
    {
      'subject_code': 'TN203',
      'subject_name': 'Môn thử nghiệm G',
      'credits': 1,
      'completion_status': 'not_taken'
    },
  ],
};

MockClient _server({
  Object? grades,
  Object? summary,
  int status = 200,
  String? rawBody,
}) =>
    MockClient((req) async {
      final Object body = req.url.path.endsWith('/student/me/grades')
          ? (grades ?? _gradesBody)
          : (summary ?? _summaryBody);
      return http.Response(rawBody ?? jsonEncode(body), status,
          headers: _json);
    });

void main() {
  tearDown(() => EmsApiService.client = http.Client());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: GradesScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('overview tab shows server totals, distribution and mini stats',
      (tester) async {
    EmsApiService.client = _server();
    await pump(tester);

    expect(find.text('Bảng điểm'), findsOneWidget);
    expect(find.text('ĐTB Tích lũy'), findsOneWidget);
    expect(find.text('6.00'), findsOneWidget);
    expect(find.text('Tổng kết: 6.00'), findsOneWidget);
    expect(find.text('2 / 5 môn đạt'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
    expect(find.text('hoàn thành'), findsOneWidget);
    expect(find.text('Môn đã học'), findsOneWidget);
    expect(find.text('3'), findsWidgets); // 3 graded rows
    expect(find.text('Không đạt'), findsOneWidget);
    expect(find.text('1 môn'), findsNWidgets(2)); // failed + no score
    expect(find.text('Phân bổ điểm chữ'), findsOneWidget);
    expect(find.text('Loại A'), findsOneWidget);
    expect(find.text('Loại C'), findsOneWidget);
    expect(find.text('Loại F'), findsOneWidget);
    expect(find.text('1 môn · 33%'), findsNWidgets(3));
  });

  testWidgets('detail tab lists graded subjects best score first with letters',
      (tester) async {
    EmsApiService.client = _server();
    await pump(tester);
    await tester.tap(find.text('Chi tiết'));
    await tester.pumpAndSettle();

    expect(find.text('Môn thử nghiệm A'), findsOneWidget);
    expect(find.text('Môn thử nghiệm B'), findsNWidgets(2)); // 2 attempts
    expect(find.text('Môn thử nghiệm D'), findsNothing); // no score yet
    expect(find.text('9.0'), findsOneWidget);
    expect(find.text('6.0'), findsOneWidget);
    expect(find.text('3.0'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
    expect(find.text('F'), findsOneWidget);
    expect(find.text('Lần 2'), findsOneWidget); // TN102 second attempt
    expect(find.text('Lần 1'), findsNothing);
    expect(find.text('3 TC'), findsOneWidget);
    expect(find.text('TN101'), findsOneWidget);

    final top = tester.getTopLeft(find.text('9.0')).dy;
    final mid = tester.getTopLeft(find.text('6.0')).dy;
    final low = tester.getTopLeft(find.text('3.0')).dy;
    expect(top < mid && mid < low, isTrue);
  });

  testWidgets('subjects tab: unscored list, then remaining subjects by status',
      (tester) async {
    EmsApiService.client = _server();
    await pump(tester);
    await tester.tap(find.text('Môn học'));
    await tester.pumpAndSettle();

    expect(find.text('Chưa có điểm'), findsOneWidget); // chip label
    expect(find.text('Chưa học'), findsNWidgets(2)); // chip + row badge
    expect(find.text('1 môn chưa có điểm'), findsOneWidget);
    expect(find.text('Môn thử nghiệm D'), findsOneWidget);
    expect(find.text('TN103'), findsOneWidget);

    await tester.tap(find.text('Chưa học').first);
    await tester.pumpAndSettle();

    expect(find.text('3 môn chưa học'), findsOneWidget);
    expect(find.text('Môn thử nghiệm E'), findsOneWidget);
    expect(find.text('Môn thử nghiệm F'), findsOneWidget);
    expect(find.text('Môn thử nghiệm G'), findsOneWidget);
    expect(find.text('Đang học'), findsOneWidget);
    expect(find.text('Không đạt'), findsOneWidget);
    expect(find.text('Chưa học'), findsNWidgets(2)); // chip + not_taken badge
  });

  testWidgets('empty account: detail and subject tabs show empty states',
      (tester) async {
    EmsApiService.client = _server(
      grades: {'mssv': 'TEST260001', 'summary': {}, 'grades': []},
      summary: {'academic': {}, 'remaining_subjects': []},
    );
    await pump(tester);

    expect(find.text('0.00'), findsNWidgets(1));
    expect(find.text('0 / 0 môn đạt'), findsOneWidget);
    expect(find.text('Phân bổ điểm chữ'), findsNothing);

    await tester.tap(find.text('Chi tiết'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có điểm'), findsOneWidget);

    await tester.tap(find.text('Môn học'));
    await tester.pumpAndSettle();
    expect(find.text('Không còn môn chưa có điểm'), findsOneWidget);
    await tester.tap(find.text('Chưa học'));
    await tester.pumpAndSettle();
    expect(find.text('Không còn môn chưa học'), findsOneWidget);
  });

  testWidgets('server error → retry state, header still visible; retry works',
      (tester) async {
    var fail = true;
    EmsApiService.client = MockClient((req) async {
      if (fail) return http.Response('{"error":"boom"}', 404, headers: _json);
      final body = req.url.path.endsWith('/student/me/grades')
          ? _gradesBody
          : _summaryBody;
      return http.Response(jsonEncode(body), 200, headers: _json);
    });
    await pump(tester);

    expect(find.text('Bảng điểm'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.text('Tổng kết: 6.00'), findsNothing);

    fail = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Thử lại'), findsNothing);
    expect(find.text('Tổng kết: 6.00'), findsOneWidget);
  });
}
