// Màn hình đăng ký môn học — trạng thái rỗng thật (không có đợt/lớp nào mở)
// và thông báo "chưa gửi tới IMS" khi đăng ký thành công qua EMS.
// mssv/tên thử nghiệm: TEST2600001 / "Thử Nghiệm".
//
//   flutter test test/registration_screen_test.dart
//
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viendongedu2_flutter/models/crm_identity.dart';
import 'package:viendongedu2_flutter/screens/registration_screen.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSession.instance
      ..emsToken = 'test-token'
      ..role = CrmRole.student
      ..mssv = 'TEST2600001'
      ..fullName = 'Thử Nghiệm';
  });
  tearDown(() => EmsApiService.client = http.Client());

  testWidgets('không có đợt đăng ký nào -> hiện trạng thái rỗng, KHÔNG ẩn màn hình', (tester) async {
    EmsApiService.client = MockClient((request) async {
      if (request.url.path.endsWith('/registration/periods')) {
        return http.Response(
          jsonEncode({'semester_code': '261', 'periods': []}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{}', 404);
    });

    await tester.pumpWidget(const MaterialApp(home: RegistrationScreen()));
    await tester.pumpAndSettle();

    // Owner rule: no hidden screens — the screen itself must still render.
    expect(find.text('Đăng ký môn học'), findsOneWidget);
    expect(find.textContaining('Hiện không có đợt đăng ký nào'), findsOneWidget);
  });

  testWidgets('đợt mở, không có lớp mở đăng ký -> hiện trạng thái rỗng của danh sách lớp', (tester) async {
    EmsApiService.client = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/registration/periods')) {
        return http.Response(
          jsonEncode({
            'semester_code': '261',
            'periods': [
              {
                'period_id': '125',
                'period_code': 'HK261',
                'period_name': 'Học kỳ 1, 2026 -2027',
                'start_at': '2026-08-10T00:00:00.000Z',
                'end_at': '2026-08-21T23:59:59.000Z',
                'is_open': false,
                'semester_code': '261',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (path.endsWith('/registration/offerings')) {
        return http.Response(
          jsonEncode({'period_id': '125', 'curriculum_resolved': true, 'offerings': []}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (path.endsWith('/registration/results')) {
        return http.Response(
          jsonEncode({'semester_code': '261', 'results': []}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{}', 404);
    });

    await tester.pumpWidget(const MaterialApp(home: RegistrationScreen()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Đợt đăng ký đã đóng'), findsOneWidget);
    expect(find.textContaining('Không có môn học mở đăng ký cho đợt này.'), findsOneWidget);
  });

  testWidgets('đăng ký thành công -> báo rõ đã ghi ở EMS, CHƯA gửi IMS', (tester) async {
    var registered = false;
    EmsApiService.client = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/registration/periods')) {
        return http.Response(
          jsonEncode({
            'semester_code': '261',
            'periods': [
              {
                'period_id': '125',
                'period_code': 'HK261',
                'period_name': 'Học kỳ 1, 2026 -2027',
                'start_at': '2026-01-01T00:00:00.000Z',
                'end_at': '2030-01-01T00:00:00.000Z',
                'is_open': true,
                'semester_code': '261',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (path.endsWith('/registration/offerings')) {
        return http.Response(
          jsonEncode({
            'period_id': '125',
            'curriculum_resolved': true,
            'offerings': [
              {
                'offering_id': '169',
                'class_code': '06THC-TEST',
                'subject_code': '2DC003',
                'subject_name': 'Môn thử nghiệm',
                'credits': 3,
                'max_size': 50,
                'registered_count': 10,
                'in_my_curriculum': true,
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (path.endsWith('/registration/results')) {
        return http.Response(
          jsonEncode({
            'semester_code': '261',
            'results': registered
                ? [
                    {
                      'id': 'req-1',
                      'offering_id': '169',
                      'subject_name': 'Môn thử nghiệm',
                      'status': 'pending',
                      'source': 'ems_request',
                      'synced_to_ims': false,
                    },
                  ]
                : [],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.method == 'POST' && path.endsWith('/student/me/registration')) {
        registered = true;
        return http.Response(
          jsonEncode({
            'recorded_in': 'ems',
            'synced_to_ims': false,
            'id': 'req-1',
            'mssv': 'TEST2600001',
            'semester_code': '261',
            'offering_id': '169',
            'status': 'pending',
            'submitted_at': '2026-09-24T08:00:00.000Z',
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{}', 404);
    });

    await tester.pumpWidget(const MaterialApp(home: RegistrationScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Đăng ký'), findsOneWidget);
    await tester.tap(find.text('Đăng ký'));
    await tester.pump(); // show snackbar
    await tester.pumpAndSettle();

    // Thông điệp trung thực: ghi ở EMS, CHƯA lên IMS — không giấu học viên.
    expect(find.textContaining('Chưa được gửi tới Phòng Đào tạo (IMS)'), findsOneWidget);
  });
}
