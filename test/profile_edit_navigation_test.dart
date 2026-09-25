// Nút sửa hồ sơ (hv_profile_info_screen / gv_profile_info_screen) điều
// hướng sang ProfileEditScreen ('/profile_edit') — bot A5, 2026-09-25.
//
//   flutter test test/profile_edit_navigation_test.dart
//
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viendongedu2_flutter/models/crm_identity.dart';
import 'package:viendongedu2_flutter/models/crm_teacher_profile.dart';
import 'package:viendongedu2_flutter/screens/gv_profile_info_screen.dart';
import 'package:viendongedu2_flutter/screens/hv_profile_info_screen.dart';
import 'package:viendongedu2_flutter/screens/profile_edit_screen.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => EmsApiService.client = http.Client());

  Widget testApp(Widget home) => MaterialApp(
        home: home,
        routes: {
          '/profile_edit': (context) => const ProfileEditScreen(),
        },
      );

  testWidgets('học viên: nút sửa hồ sơ mở ProfileEditScreen', (tester) async {
    AppSession.instance
      ..emsToken = 'test-token'
      ..role = CrmRole.student
      ..mssv = 'TEST2600001'
      ..fullName = 'Thử Nghiệm';

    EmsApiService.client = MockClient((request) async {
      if (request.url.path.endsWith('/student/me')) {
        return http.Response(
          jsonEncode({
            'student': {
              'mssv': 'TEST2600001',
              'full_name': 'Thử Nghiệm',
              'email': 'thunghiem@thunghiem.test',
              'phone': '0900000000',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{}', 404);
    });

    await tester.pumpWidget(testApp(const HvProfileInfoScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Sửa hồ sơ'), findsNothing);
    await tester.tap(find.byTooltip('Sửa hồ sơ'));
    await tester.pumpAndSettle();

    // Đã điều hướng sang ProfileEditScreen — tiêu đề của nó xuất hiện.
    expect(find.text('Sửa hồ sơ'), findsOneWidget);
  });

  testWidgets('giảng viên: nút sửa hồ sơ mở ProfileEditScreen', (tester) async {
    AppSession.instance
      ..emsToken = 'test-token'
      ..role = CrmRole.teacher
      ..teacherId = '99'
      ..teacherCode = 'GV-TEST'
      ..fullName = 'Thử Nghiệm';

    EmsApiService.client = MockClient((request) async {
      if (request.url.path.endsWith('/teacher/me')) {
        return http.Response(
          jsonEncode({
            'teacher': {
              'teacher_id': '99',
              'teacher_code': 'GV-TEST',
              'name': 'Thử Nghiệm',
              'email': 'gv@thunghiem.test',
              'phone': '0922222222',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{}', 404);
    });

    await tester.pumpWidget(testApp(GvProfileInfoScreen(
      profile: const CrmTeacherProfile(
        teacherId: '99',
        teacherCode: 'GV-TEST',
        name: 'Thử Nghiệm',
      ),
      fallbackName: 'Thử Nghiệm',
      teacherCode: 'GV-TEST',
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Sửa hồ sơ'));
    await tester.pumpAndSettle();

    expect(find.text('Sửa hồ sơ'), findsOneWidget);
  });
}
