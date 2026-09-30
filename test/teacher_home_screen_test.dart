// Characterization test for the teacher home screen (GvHomeScreen, '/gv_home').
//
// Fixture is fictional (teacher code TESTGV01). The mock client answers the two
// endpoints the screen reads:
//   GET /teacher/me/overview                  → profile + 2 sessions today
//   GET /teacher/notifications/unread-count   → bell badge (3)
//
//   flutter test test/teacher_home_screen_test.dart
//
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viendongedu2_flutter/features/teacher_home/teacher_home_screen.dart';
import 'package:viendongedu2_flutter/models/crm_identity.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

Map<String, dynamic> _slot(String name, String start, String end) => {
  'lmhid': '9001',
  'lmhma': '06CDTHUNGHIEM-$start',
  'mhten': name,
  'phongten': 'P.101',
  'thoigianbd': start,
  'thoigiankt': '2026-09-30T$end:00',
};

Map<String, dynamic> _overview({String type = 'gvch'}) => {
  'teacher': {
    'teacher_id': 'T-TEST-1',
    'teacher_code': 'TESTGV01',
    'name': 'Giảng Viên Thử Nghiệm',
    'type': type,
  },
  'today_sessions': [
    _slot('Môn thử nghiệm sáng', '07:30', '09:30'),
    _slot('Môn thử nghiệm tối', '18:30', '20:30'),
  ],
};

void main() {
  late Map<String, int> hits;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSession.instance
      ..emsToken = 'test-token'
      ..role = CrmRole.teacher
      ..teacherId = 'T-TEST-1'
      ..teacherCode = 'TESTGV01'
      ..fullName = 'Giảng Viên Thử Nghiệm';
    hits = {};
  });
  tearDown(() {
    EmsApiService.client = http.Client();
    AppSession.instance
      ..emsToken = null
      ..role = null
      ..teacherId = null
      ..teacherCode = null
      ..fullName = null;
  });

  void mock({
    bool overviewFails = false,
    String type = 'gvch',
    int unread = 3,
    bool unreadFails = false,
  }) {
    EmsApiService.client = MockClient((req) async {
      final p = req.url.path;
      hits[p] = (hits[p] ?? 0) + 1;
      if (p.endsWith('/teacher/me/overview')) {
        if (overviewFails) return http.Response('{"error":"boom"}', 500);
        return http.Response(
          jsonEncode(_overview(type: type)),
          200,
          headers: {..._json, 'etag': '"ov-1"'},
        );
      }
      if (p.endsWith('/teacher/notifications/unread-count')) {
        if (unreadFails) return http.Response('{"error":"boom"}', 500);
        return http.Response(
          jsonEncode({'count': unread}),
          200,
          headers: _json,
        );
      }
      return http.Response('{}', 200, headers: _json);
    });
  }

  Widget stub(String name) => Scaffold(body: Text('route:$name'));

  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: '/gv_home',
        routes: {
          '/gv_home': (_) => const GvHomeScreen(),
          for (final r in [
            '/teacher_my_day',
            '/gv_schedule',
            '/gv_lophoc',
            '/gv_lichthi',
            '/gv_quanly_lop',
            '/ems_attendance_gv',
            '/change_password',
            '/notifications',
            '/',
          ])
            r: (_) => stub(r),
        },
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900)); // overview pace
    await tester.pump(const Duration(milliseconds: 2600)); // unread pace
    // Failed GETs wait retry-after (1 s) before their second attempt.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  }

  testWidgets('trang chủ: tên/mã GV, Cơ hữu, 2 buổi hôm nay, chuông 3', (
    tester,
  ) async {
    mock();
    await pumpHome(tester);

    expect(find.text('Giảng Viên Thử Nghiệm'), findsOneWidget);
    expect(find.text('Mã GV: TESTGV01'), findsOneWidget);
    expect(find.text('Cơ hữu'), findsOneWidget);
    expect(find.text('Lịch dạy hôm nay'), findsOneWidget);
    expect(find.text('Môn thử nghiệm sáng'), findsOneWidget);
    expect(find.text('Môn thử nghiệm tối'), findsOneWidget);
    expect(find.text('P.101'), findsNWidgets(2));
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Thu gọn'), findsOneWidget);
    await tester.tap(find.text('Thu gọn'));
    await tester.pump();
    expect(find.text('Mở rộng'), findsOneWidget);
    expect(
      find.textContaining('nhấn để xem chi tiết', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Môn thử nghiệm sáng'), findsNothing);
  });

  testWidgets('giảng viên thỉnh giảng: không có huy hiệu Cơ hữu', (
    tester,
  ) async {
    mock(type: 'gvtg');
    await pumpHome(tester);
    expect(find.text('Cơ hữu'), findsNothing);
    expect(find.text('Giảng Viên Thử Nghiệm'), findsOneWidget);
  });

  testWidgets('tên và mã hiện ngay từ phiên, trước khi có mạng', (
    tester,
  ) async {
    mock();
    await tester.pumpWidget(const MaterialApp(home: GvHomeScreen()));
    await tester.pump();
    expect(find.text('Giảng Viên Thử Nghiệm'), findsOneWidget);
    expect(find.text('Mã GV: TESTGV01'), findsOneWidget);
    expect(hits['/api/teacher/me/overview'], isNull);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('các ô menu đi đúng tuyến', (tester) async {
    mock();
    for (final entry in {
      'Ngày làm việc của tôi': '/teacher_my_day',
      'Lịch dạy': '/gv_schedule',
      'Lớp học': '/gv_lophoc',
      'Lịch thi': '/gv_lichthi',
      'Quản lý lớp': '/gv_quanly_lop',
      'Điểm danh EMS': '/ems_attendance_gv',
    }.entries) {
      await pumpHome(tester);
      await tester.tap(find.text(entry.key).first);
      await tester.pumpAndSettle();
      expect(
        find.text('route:${entry.value}'),
        findsOneWidget,
        reason: entry.key,
      );
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('chuông mở /notifications rồi tải lại số chưa đọc', (
    tester,
  ) async {
    mock();
    await pumpHome(tester);
    final before = hits['/api/teacher/notifications/unread-count']!;
    await tester.tap(find.byIcon(Icons.notifications_outlined));
    await tester.pumpAndSettle();
    expect(find.text('route:/notifications'), findsOneWidget);
    Navigator.of(tester.element(find.text('route:/notifications'))).pop();
    await tester.pumpAndSettle();
    expect(hits['/api/teacher/notifications/unread-count']!, before + 1);
  });

  testWidgets('lỗi số chưa đọc bị nuốt: lịch vẫn hiện, không có chấm', (
    tester,
  ) async {
    mock(unreadFails: true);
    await pumpHome(tester);
    expect(find.text('Môn thử nghiệm sáng'), findsOneWidget);
    expect(find.text('3'), findsNothing);
  });

  testWidgets('không có EMS: không gọi unread-count', (tester) async {
    mock();
    AppSession.instance.emsToken = null;
    await pumpHome(tester);
    expect(hits['/api/teacher/notifications/unread-count'], isNull);
  });

  testWidgets('lịch lỗi và chưa có bản lưu: hiện nút thử lại', (tester) async {
    mock(overviewFails: true);
    await pumpHome(tester);
    expect(find.text('Môn thử nghiệm sáng'), findsNothing);
    expect(find.text('Không có kết nối. Thử tải lịch lại'), findsOneWidget);

    mock();
    await tester.tap(find.text('Không có kết nối. Thử tải lịch lại'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Môn thử nghiệm sáng'), findsOneWidget);
    expect(find.text('Không có kết nối. Thử tải lịch lại'), findsNothing);
  });

  testWidgets('lịch lỗi nhưng có bản lưu: hiện bản lưu + StaleNote', (
    tester,
  ) async {
    mock();
    await pumpHome(tester);
    await tester.pumpWidget(const SizedBox());

    mock(overviewFails: true);
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
    expect(find.text('Phần mềm Viendongedu phiên bản 1.1.43'), findsOneWidget);
    expect(find.text('Thuộc bản quyền Cao đẳng Viễn Đông'), findsOneWidget);

    await tester.tap(find.text('Đổi mật khẩu'));
    await tester.pumpAndSettle();
    expect(find.text('route:/change_password'), findsOneWidget);
    Navigator.of(tester.element(find.text('route:/change_password'))).pop();
    await tester.pumpAndSettle();

    // Logging out clears the session through Firebase, which needs a real app
    // (covered with a fake repository in teacher_home_view_model_test.dart).
    expect(find.text('Đăng xuất'), findsOneWidget);
  });
}
