import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:viendongedu2_flutter/screens/gv_lophoc_screen.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';

/// `gv_lophoc_screen` gọi CRM (`CrmTeacherApi` → `EmsApiService.send`), không
/// còn `ApiService` (IMS). Dữ liệu mẫu là fixture — tên/mã hư cấu (THUNGHIEM/
/// TEST26…) theo quy định test data.
void main() {
  tearDown(() => EmsApiService.client = http.Client());

  testWidgets('loads semesters then classes for the current semester, '
      'grouped and sorted by day', (tester) async {
    EmsApiService.client = MockClient((request) async {
      if (request.url.path.endsWith('/teacher/me/semesters')) {
        return http.Response(
          jsonEncode([
            {'id': 261, 'ma': '261', 'ten': 'Học kỳ 1, 2026 - 2027'},
            {'id': 252, 'ma': '252', 'ten': 'Học kỳ 2, 2025 - 2026'},
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path.endsWith('/teacher/me/schedule/semester')) {
        expect(request.url.queryParameters['semester'], '261');
        return http.Response(
          jsonEncode({
            'data': [
              {
                'lmhid': '90001',
                'lmhma': '261_THUNGHIEM01_06CD15THUNGHIEM',
                'mhten': 'Môn thử nghiệm thứ Tư',
                'sotinchi': 3,
                'phongten': 'P.101',
                'tietbd': '13',
                'tgbatdau': '18:00',
                'tgketthuc': '20:30',
                'ngayma': '4',
                'ngayten': 'Thứ 4',
                'baonghiyn': false,
              },
              {
                'lmhid': '90002',
                'lmhma': '261_THUNGHIEM02_06CD15THUNGHIEM',
                'mhten': 'Môn thử nghiệm thứ Hai',
                'sotinchi': 2,
                'phongten': 'P.102',
                'tietbd': '1',
                'tgbatdau': '07:00',
                'tgketthuc': '09:30',
                'ngayma': '2',
                'ngayten': 'Thứ 2',
                'baonghiyn': false,
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{}', 404);
    });

    await tester.pumpWidget(const MaterialApp(home: GvLopHocScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Môn thử nghiệm thứ Tư'), findsOneWidget);
    expect(find.text('Môn thử nghiệm thứ Hai'), findsOneWidget);

    // Thứ 2 phải xuất hiện trước Thứ 4 trong danh sách (sắp xếp theo thứ tự
    // tuần, không phải thứ tự trả về từ server).
    final mon2 = tester.getTopLeft(find.text('Thứ 2')).dy;
    final thu4 = tester.getTopLeft(find.text('Thứ 4')).dy;
    expect(mon2, lessThan(thu4));
  });

  testWidgets('shows retry on error and refetches on tap', (tester) async {
    var calls = 0;
    EmsApiService.client = MockClient((request) async {
      calls++;
      return http.Response('{"error":"lỗi máy chủ"}', 500,
          headers: {'content-type': 'application/json'});
    });

    await tester.pumpWidget(const MaterialApp(home: GvLopHocScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Thử lại'), findsOneWidget);
    final firstCalls = calls;
    expect(firstCalls, greaterThan(0));

    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(calls, greaterThan(firstCalls));
  });
}
