// Contract S3: every student screen that reads a notices-carrying endpoint
// draws its `notices` at the top, and draws nothing when they are absent.
// Fixtures are fictional.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viendongedu2_flutter/components/student_notices.dart';
import 'package:viendongedu2_flutter/data/student_home_repository.dart';
import 'package:viendongedu2_flutter/features/classes/classes_screen.dart';
import 'package:viendongedu2_flutter/features/grades/grades_screen.dart';
import 'package:viendongedu2_flutter/features/student_home/student_home_screen.dart';
import 'package:viendongedu2_flutter/features/student_home/student_home_view_model.dart';
import 'package:viendongedu2_flutter/models/crm_identity.dart';
import 'package:viendongedu2_flutter/screens/ems_attendance_student_screen.dart';
import 'package:viendongedu2_flutter/screens/exam_screen.dart';
import 'package:viendongedu2_flutter/screens/schedule_screen.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

/// Endpoint suffix → body, each carrying its own notice when [withNotices].
Map<String, Map<String, dynamic>> _bodies({required bool withNotices}) {
  Map<String, dynamic> n(String screen) => withNotices
      ? {
          'notices': [
            {
              'id': 'n-$screen',
              'level': 'warning',
              'text': 'Thông báo $screen.',
            },
            {
              'id': 'old-$screen',
              'level': 'urgent',
              'text': 'Hết hạn $screen.',
              'until': '2020-01-01',
            },
          ],
        }
      : {};
  return {
    '/student/me': {
      'student': {'mssv': 'TEST2600001', 'class_code': 'TEST-CLASS'},
      ...n('Trang chủ'),
    },
    '/student/me/schedule': {'schedule': [], ...n('Lịch học')},
    '/student/me/exams': {'exams': [], ...n('Lịch thi')},
    '/student/me/grades': {
      'mssv': 'TEST2600001',
      'summary': {},
      'grades': [],
      ...n('Bảng điểm'),
    },
    '/student/me/graduation-summary': {'academic': {}},
    '/student/me/remaining-subjects': {'subjects': []},
    '/student/me/attendance-ems': {'marks': [], ...n('Điểm danh')},
    '/student/me/sections': {
      'sections': [
        {
          'section_code': 'TEST-S1',
          'semester_code': '261',
          'subject_code': 'TN1',
          'subject_name': 'Môn thử nghiệm',
        },
      ],
      ...n('Lớp học'),
    },
  };
}

void _serve({required bool withNotices}) {
  final bodies = _bodies(withNotices: withNotices);
  EmsApiService.client = MockClient((req) async {
    final body = bodies[req.url.path.replaceFirst('/api', '')] ?? {};
    return http.Response(jsonEncode(body), 200, headers: _json);
  });
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSession.instance
      ..emsToken = 'test-token'
      ..role = CrmRole.student
      ..mssv = '2600000001'
      ..fullName = 'Học Viên Thử Nghiệm';
  });
  tearDown(() {
    EmsApiService.client = http.Client();
    AppSession.instance
      ..emsToken = null
      ..role = null
      ..mssv = null
      ..fullName = null;
  });

  final screens = <String, Widget Function()>{
    'Trang chủ': () => HomeScreen(
      viewModel: StudentHomeViewModel(
        const StudentHomeRepository(),
        now: () => DateTime(2026, 11, 10, 9),
        tickEvery: null,
      ),
    ),
    'Lịch học': () => ScheduleScreen(now: () => DateTime(2026, 11, 10, 9)),
    'Lịch thi': () => const ExamScreen(),
    'Bảng điểm': () => const GradesScreen(),
    'Điểm danh': () => const EmsAttendanceStudentScreen(),
    'Lớp học': () => const ClassesScreen(),
  };

  for (final MapEntry(key: screen, value: build) in screens.entries) {
    testWidgets('$screen draws its server notices, hides expired ones', (
      t,
    ) async {
      _serve(withNotices: true);
      await t.pumpWidget(MaterialApp(home: build()));
      await t.pump(const Duration(seconds: 3));
      await t.pumpAndSettle();
      expect(find.text('Thông báo $screen.'), findsOneWidget);
      expect(find.text('Hết hạn $screen.'), findsNothing);
      expect(find.byType(StudentNoticeBanner), findsOneWidget);
    });

    testWidgets('$screen without notices draws no banner', (t) async {
      _serve(withNotices: false);
      await t.pumpWidget(MaterialApp(home: build()));
      await t.pump(const Duration(seconds: 3));
      await t.pumpAndSettle();
      expect(find.byType(StudentNoticeBanner), findsNothing);
    });
  }
}
