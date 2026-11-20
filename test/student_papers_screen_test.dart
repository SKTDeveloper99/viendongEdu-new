// Nộp hồ sơ (học viên) — CRM LAW S-57 (đề xuất). Danh sách do máy chủ cho
// biết, trạng thái từng mục, tệp đã gửi, và Chụp ảnh / Chọn ảnh / Chọn tệp
// tùy loại tệp mục đó nhận.
//
//   flutter test test/student_papers_screen_test.dart
//
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viendongedu2_flutter/features/student_papers/papers_api.dart';
import 'package:viendongedu2_flutter/features/student_papers/papers_screen.dart';
import 'package:viendongedu2_flutter/features/work/hand_in_sheet.dart'
    show PickedFile;
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';

Map<String, dynamic> _item(
  String code,
  String label,
  String accepts, {
  String state = 'none',
  String stateLabel = 'Còn thiếu',
  List<Map<String, dynamic>> files = const [],
  List<String> reasons = const [],
}) => {
  'code': code,
  'label': label,
  'description': 'Hướng dẫn thử',
  'accepts': accepts,
  'accepts_label': accepts == 'photo' ? 'Ảnh chụp' : 'Ảnh chụp hoặc tệp PDF',
  'required': true,
  'due_on': '2026-11-27',
  'overdue': false,
  'state': state,
  'state_label': stateLabel,
  'reasons': reasons,
  'files': files,
};

PapersPage _page(List<Map<String, dynamic>> items) => PapersPage(
  [for (final i in items) PaperItem.fromJson(i)],
  'Hiện trường chưa yêu cầu bạn nộp giấy tờ nào.',
  12 * 1024 * 1024,
);

PickedFile _file(String name, int size) =>
    (name: name, size: size, read: () async => List<int>.filled(size, 1));

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSession.instance.emsToken = 'crm-student-token';
  });
  tearDown(() => EmsApiService.client = http.Client());

  test('đọc danh sách từ GET /student/me/papers', () async {
    EmsApiService.client = MockClient((req) async {
      expect(req.url.path, '/api/student/me/papers');
      expect(req.headers['Authorization'], 'Bearer crm-student-token');
      return http.Response(
        jsonEncode({
          'items': [
            _item(
              'anh_the',
              'Ảnh thẻ',
              'photo',
              files: [
                {
                  'id': 'f1',
                  'name': 'Ảnh 20-11.jpg',
                  'kind': 'photo',
                  'sent_at': '2026-11-20T03:00:00Z',
                  'review': 'pending',
                  'review_label': 'Chờ xem',
                },
              ],
            ),
          ],
          'empty_message': 'Trống',
          'max_file_mb': 12,
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final page = await StudentPapersApi.list();
    expect(page.items.single.label, 'Ảnh thẻ');
    expect(page.items.single.files.single.isPhoto, isTrue);
    expect(page.items.single.takesFile, isFalse);
    expect(page.maxFileBytes, 12 * 1024 * 1024);
  });

  testWidgets('không có yêu cầu: nói rõ là trống', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: StudentPapersScreen(load: () async => _page([]))),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Hiện trường chưa yêu cầu bạn nộp giấy tờ nào.'),
      findsOneWidget,
    );
  });

  testWidgets('trạng thái và lý do trả lại hiện đúng chữ của máy chủ', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StudentPapersScreen(
          load: () async => _page([
            _item(
              'anh_the',
              'Ảnh thẻ',
              'photo',
              state: 'bad',
              stateLabel: 'Bị trả lại, cần gửi lại',
              reasons: ['Ảnh bị lóa'],
            ),
            _item('giay_kham', 'Giấy khám', 'photo_or_pdf'),
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bị trả lại, cần gửi lại'), findsOneWidget);
    expect(find.text('Lý do: Ảnh bị lóa'), findsOneWidget);
    expect(find.text('Còn thiếu'), findsOneWidget);
    expect(find.text('Gửi ảnh'), findsOneWidget);
    expect(find.text('Gửi ảnh hoặc tệp'), findsOneWidget);
  });

  testWidgets(
    'mục chỉ nhận ảnh không có "Chọn tệp"; chọn ảnh thì gửi rồi tải lại',
    (tester) async {
      var loads = 0;
      final sent = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: StudentPapersScreen(
            load: () async {
              loads++;
              return _page([_item('anh_the', 'Ảnh thẻ', 'photo')]);
            },
            send: (code, bytes, name, max) async {
              sent.add('$code:$name:${bytes.length}');
              return null;
            },
            pickPhotos: () async => [_file('Ảnh 20-11 09.00.jpg', 2000)],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('paper-add-anh_the')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('paper-source-camera')), findsOneWidget);
      expect(find.byKey(const Key('paper-source-photos')), findsOneWidget);
      expect(find.byKey(const Key('paper-source-file')), findsNothing);

      await tester.tap(find.byKey(const Key('paper-source-photos')));
      await tester.pumpAndSettle();
      expect(sent, ['anh_the:Ảnh 20-11 09.00.jpg:2000']);
      expect(loads, 2);
      expect(find.text('Đã gửi.'), findsOneWidget);
    },
  );

  testWidgets('tệp quá lớn bị chặn trên máy, máy chủ từ chối thì hiện lời', (
    tester,
  ) async {
    final sent = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: StudentPapersScreen(
          load: () async =>
              _page([_item('giay_kham', 'Giấy khám', 'photo_or_pdf')]),
          send: (code, bytes, name, max) async {
            sent.add(name);
            throw EmsException('Chỉ nhận ảnh hoặc tệp PDF.', statusCode: 415);
          },
          pickFiles: (ext) async {
            expect(ext, contains('pdf'));
            return [_file('to.pdf', 13 * 1024 * 1024), _file('nho.pdf', 10)];
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('paper-add-giay_kham')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('paper-source-file')));
    await tester.pumpAndSettle();
    expect(sent, ['nho.pdf']);
    expect(find.text('Chỉ nhận ảnh hoặc tệp PDF.'), findsOneWidget);
  });

  testWidgets('leaving the screen while a photo is still sending does not '
      'fail when the answer arrives', (tester) async {
    final answer = Completer<PaperItem?>();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StudentPapersScreen(
                    load: () async =>
                        _page([_item('anh_the', 'Ảnh thẻ', 'photo')]),
                    send: (code, bytes, name, max) => answer.future,
                    pickPhotos: () async => [
                      _file('Ảnh 20-11 09.00.jpg', 2000),
                    ],
                  ),
                ),
              ),
              child: const Text('mở'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('paper-add-anh_the')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('paper-source-photos')));
    // The spinner keeps going while the answer is held back.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Đang gửi…'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('mở'), findsOneWidget);
    answer.complete(null);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('máy chủ chưa có Nộp hồ sơ (404 chung): nói rõ là chưa mở', (
    tester,
  ) async {
    EmsApiService.client = MockClient(
      (_) async => http.Response(
        jsonEncode({'error': 'Endpoint not found'}),
        404,
        headers: {'content-type': 'application/json'},
      ),
    );
    await tester.pumpWidget(const MaterialApp(home: StudentPapersScreen()));
    await tester.pumpAndSettle();
    expect(find.text(StudentPapersApi.notOpenMessage), findsOneWidget);
    expect(find.text('Thử lại'), findsNothing);
  });
}
