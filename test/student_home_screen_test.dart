// Characterization test for the student home screen ("Trang chủ").
//
// Fixture is fictional (MSSV TEST260001). The mock client answers the four
// endpoints the screen reads:
//   GET /student/me/schedule           → today's classes (day_code = today)
//   GET /student/me                    → class code for the header
//   GET /v1/student/board              → one unread + one must-read item
//   GET /v1/student/board/unread-count → bell badge
//
// The must-read prompt is once per app session (static flag), so the test that
// triggers it MUST stay last in this file.
//
//   flutter test test/student_home_screen_test.dart
//
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viendongedu2_flutter/features/student_home/student_home_screen.dart';
import 'package:viendongedu2_flutter/models/crm_identity.dart';
import 'package:viendongedu2_flutter/models/crm_student_schedule.dart';
import 'package:viendongedu2_flutter/screens/student_board_screen.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

Map<String, dynamic> _class(String name, String start, String end) => {
  'subject_code': 'TN101',
  'subject_name': name,
  'semester_code': '262',
  'section_code': '06CDTHUNGHIEM-$start',
  'day_code': dayCodeForWeekday(DateTime.now().weekday),
  'start_time': start,
  'end_time': end,
  'room': 'P.101',
  'teacher_name': 'GV Thử Nghiệm',
};

final _scheduleBody = {
  'schedule': [
    _class('Môn thử nghiệm sáng', '07:30', '09:30'),
    _class('Môn thử nghiệm tối', '18:30', '20:30'),
  ],
};

Map<String, dynamic> _board({required bool mustRead}) => {
  'items': [
    {
      'id': 'b1',
      'title': 'Thông báo thử nghiệm A',
      'body': 'x',
      'category': 'general',
      'must_read': false,
      'published_at': '2026-09-01T13:05:35.805Z',
      'read_at': null,
      'acknowledged_at': null,
    },
    {
      'id': 'b2',
      'title': 'Thông báo bắt buộc B',
      'body': 'y',
      'category': 'urgent',
      'must_read': mustRead,
      'published_at': '2026-08-01T13:05:35.805Z',
      'read_at': '2026-08-02T00:00:00.000Z',
      'acknowledged_at': null,
    },
  ],
};

void main() {
  late Map<String, int> hits;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSession.instance
      ..emsToken = 'test-token'
      ..role = CrmRole.student
      ..mssv = 'TEST260001'
      ..fullName = 'Học Viên Thử Nghiệm'
      ..emsDenied = false;
    hits = {};
  });
  tearDown(() {
    EmsApiService.client = http.Client();
    AppSession.instance
      ..emsToken = null
      ..role = null
      ..mssv = null
      ..fullName = null
      ..emsDenied = false;
  });

  void mock({
    bool mustRead = false,
    bool scheduleFails = false,
    bool boardFails = false,
  }) {
    EmsApiService.client = MockClient((req) async {
      final p = req.url.path;
      hits[p] = (hits[p] ?? 0) + 1;
      if (p.endsWith('/student/me/schedule')) {
        if (scheduleFails) return http.Response('{"error":"boom"}', 500);
        return http.Response(
          jsonEncode(_scheduleBody),
          200,
          headers: {..._json, 'etag': '"sched-1"'},
        );
      }
      if (p.endsWith('/student/me')) {
        return http.Response(
          jsonEncode({
            'student': {'mssv': 'TEST260001', 'class_code': '06CDTHUNGHIEM'},
          }),
          200,
          headers: _json,
        );
      }
      if (p.endsWith('/board/unread-count')) {
        return http.Response(
          jsonEncode({'unread': 2, 'must_read_pending': 1}),
          200,
          headers: _json,
        );
      }
      if (p.endsWith('/v1/student/board')) {
        if (boardFails) return http.Response('{"error":"boom"}', 500);
        return http.Response(
          jsonEncode(_board(mustRead: mustRead)),
          200,
          headers: _json,
        );
      }
      return http.Response('{}', 200, headers: _json);
    });
  }

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const HomeScreen(),
        routes: {'/student_board': (_) => const StudentBoardScreen()},
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 500));
    // Failed GETs wait retry-after (1 s) before their second attempt.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  }

  testWidgets('lịch hôm nay: buổi Sáng/Tối, header từ phiên, mã lớp, chuông', (
    tester,
  ) async {
    mock();
    await pumpHome(tester);

    expect(find.text('Lịch học hôm nay'), findsOneWidget);
    expect(find.text('Môn thử nghiệm sáng'), findsOneWidget);
    expect(find.text('Môn thử nghiệm tối'), findsOneWidget);
    expect(find.text('Sáng'), findsOneWidget);
    expect(find.text('Tối'), findsOneWidget);
    expect(find.text('07:30 – 09:30'), findsOneWidget);
    expect(find.text('Học Viên Thử Nghiệm'), findsOneWidget);
    expect(find.text('MSSV: TEST260001'), findsOneWidget);
    expect(find.text('06CDTHUNGHIEM'), findsOneWidget);
    expect(find.text('3'), findsOneWidget); // unread 2 + must-read pending 1
    expect(find.text('Thu gọn'), findsOneWidget);
    await tester.tap(find.text('Thu gọn'));
    await tester.pump();
    expect(find.text('Mở rộng'), findsOneWidget);
    expect(
      find.textContaining('nhấn để xem chi tiết', findRichText: true),
      findsOneWidget,
    );
    for (final label in ['Lịch học', 'Điểm', 'Học phí', 'Bảng tin']) {
      expect(find.text(label), findsWidgets);
    }
  });

  testWidgets('thẻ bảng tin: tiêu đề mới nhất và số chưa đọc', (tester) async {
    mock();
    await pumpHome(tester);

    expect(find.text('Thông tin mới từ trung tâm'), findsOneWidget);
    expect(find.text('Thông báo thử nghiệm A'), findsOneWidget);
    expect(find.text('1 chưa đọc'), findsOneWidget);
  });

  testWidgets('bảng tin lỗi bị nuốt: hiện thẻ thử lại, lịch vẫn chạy', (
    tester,
  ) async {
    mock(boardFails: true);
    await pumpHome(tester);

    expect(find.text('Môn thử nghiệm sáng'), findsOneWidget);
    expect(
      find.text('Không tải được bảng tin. Chạm để thử lại.'),
      findsOneWidget,
    );
  });

  testWidgets('EMS bị từ chối có chủ đích: KHÔNG hiện thẻ thử lại', (
    tester,
  ) async {
    mock(boardFails: true);
    AppSession.instance.emsDenied = true;
    await pumpHome(tester);

    expect(find.text('Môn thử nghiệm sáng'), findsOneWidget);
    expect(find.text('Thông tin mới từ trung tâm'), findsNothing);
  });

  testWidgets('lịch lỗi và chưa có bản lưu: hiện nút thử lại', (tester) async {
    mock(scheduleFails: true);
    await pumpHome(tester);

    expect(find.text('Môn thử nghiệm sáng'), findsNothing);
    expect(find.text('Không có kết nối. Thử tải lịch lại'), findsOneWidget);
  });

  testWidgets('lịch lỗi nhưng có bản lưu: hiện bản lưu + StaleNote', (
    tester,
  ) async {
    mock();
    await pumpHome(tester); // populates the stored copy (ETag-less → body only)
    // Populate a stored copy with an ETag-less body, then break the network.
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getKeys().any((k) => k.startsWith('offline_v1_')),
      isTrue,
      reason: 'stored copy must exist',
    );

    mock(scheduleFails: true);
    await tester.pumpWidget(const SizedBox());
    await pumpHome(tester);

    expect(find.text('Môn thử nghiệm sáng'), findsOneWidget);
    expect(
      find.textContaining('Chưa cập nhật được — dữ liệu lúc'),
      findsOneWidget,
    );
  });

  testWidgets('tab Cá nhân: thông tin, đổi mật khẩu, đăng xuất', (
    tester,
  ) async {
    mock();
    await pumpHome(tester);

    await tester.tap(find.text('Cá nhân'));
    await tester.pump();
    expect(find.text('Thông tin cá nhân'), findsOneWidget);
    expect(find.text('Đổi mật khẩu'), findsOneWidget);
    expect(find.text('Đăng xuất'), findsOneWidget);
    expect(find.text('Phần mềm Viendongedu phiên bản 1.1.43'), findsOneWidget);
  });

  // MUST STAY LAST: consumes the once-per-session must-read prompt.
  testWidgets(
    'bắt buộc đọc: đẩy StudentBoardScreen ĐÚNG MỘT lần, rồi tải lại',
    (tester) async {
      mock(mustRead: true);
      await pumpHome(tester);

      expect(find.byType(StudentBoardScreen), findsOneWidget);
      final boardHitsBefore = hits['/api/v1/student/board'] ?? 0;
      expect(boardHitsBefore, greaterThan(0));

      Navigator.of(tester.element(find.byType(StudentBoardScreen))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(StudentBoardScreen), findsNothing);
      // Home reloads the board after coming back.
      expect(hits['/api/v1/student/board']!, greaterThan(boardHitsBefore));

      // App resume reloads the board again but never pushes the prompt twice.
      final beforeResume = hits['/api/v1/student/board']!;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(hits['/api/v1/student/board']!, greaterThan(beforeResume));
      expect(find.byType(StudentBoardScreen), findsNothing);
    },
  );
}
