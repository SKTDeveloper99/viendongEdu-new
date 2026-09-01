// Màn hình Bảng tin — ba trạng thái phải đúng: có dữ liệu, rỗng, và EMS chết.
//
// Dữ liệu dựng sẵn dưới đây là JSON THẬT chụp từ endpoint
// GET /api/v1/student/board (bản chạy trên schoolcrm_audit, học viên hư cấu
// TEST26TN01), nên bài test này kiểm đúng hình dạng server thật trả về.
//
//   flutter test test/student_board_screen_test.dart
//
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:viendongedu2_flutter/screens/student_board_screen.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';

const _realBoardJson = '''
{"items":[{"id":"20ac8e36-a86c-43f0-8ca6-883516608808",
"title":"KHẨN: kiểm thử bảng tin",
"body":"Chào Thử Nghiệm Bảng Tin (Lớp 18QTTHC),\\n\\nTHÔNG BÁO KHẨN từ Trung tâm Viễn Đông EDU: kiểm thử bảng tin.\\n\\nTrân trọng,\\nViễn Đông EDU",
"category":"urgent","must_read":true,"is_correction":false,
"published_at":"2026-09-01T13:05:35.805Z","read_at":null,"acknowledged_at":null}]}
''';

void main() {
  tearDown(() => EmsApiService.client = http.Client());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: StudentBoardScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('hiện thông báo, nhãn KHẨN và dấu bắt buộc đọc', (tester) async {
    EmsApiService.client =
        MockClient((_) async => http.Response(_realBoardJson, 200,
            headers: {'content-type': 'application/json; charset=utf-8'}));

    await pump(tester);

    expect(find.text('Bảng tin'), findsOneWidget);
    expect(find.text('KHẨN: kiểm thử bảng tin'), findsOneWidget);
    expect(find.text('Khẩn'), findsOneWidget);
    expect(find.text('Bắt buộc đọc'), findsOneWidget);
  });

  testWidgets('mở thông báo → đóng dấu đã đọc và hiện nút xác nhận',
      (tester) async {
    final calls = <String>[];
    EmsApiService.client = MockClient((req) async {
      calls.add('${req.method} ${req.url.path}');
      if (req.method == 'POST') {
        return http.Response(jsonEncode({'id': 'x', 'read_at': 'now'}), 200,
            headers: {'content-type': 'application/json'});
      }
      return http.Response(_realBoardJson, 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });

    await pump(tester);
    await tester.tap(find.text('KHẨN: kiểm thử bảng tin'));
    await tester.pumpAndSettle();

    expect(calls.any((c) => c.endsWith('/read')), isTrue,
        reason: 'mở thông báo phải đóng dấu đã đọc');
    expect(find.text('Tôi đã đọc và hiểu'), findsOneWidget);
  });

  testWidgets('EMS chết → trạng thái thử lại, KHÔNG phải màn hình trắng',
      (tester) async {
    EmsApiService.client =
        MockClient((_) async => http.Response('<html>502</html>', 502));

    await pump(tester);

    expect(find.text('Thử lại'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    // Vẫn còn khung màn hình — người dùng không bị kẹt ở trang trống.
    expect(find.text('Bảng tin'), findsOneWidget);
  });

  testWidgets('chưa có thông báo nào → trạng thái rỗng', (tester) async {
    EmsApiService.client = MockClient((_) async => http.Response(
        '{"items":[]}', 200,
        headers: {'content-type': 'application/json'}));

    await pump(tester);

    expect(find.text('Chưa có thông báo nào.'), findsOneWidget);
  });
}
