import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:viendongedu2_flutter/features/work/file_pick.dart';
import 'package:viendongedu2_flutter/features/work/hand_in_sheet.dart';
import 'package:viendongedu2_flutter/features/work/work_api.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';
import 'package:viendongedu2_flutter/services/ems_upload.dart';
import 'package:viendongedu2_flutter/theme/vd_theme.dart';

void main() {
  tearDown(() {
    EmsApiService.client = http.Client();
    AppSession.instance.emsToken = null;
  });

  test('a hand-in file goes as the web sends it', () async {
    final dir = await Directory.systemTemp.createTemp('handin');
    final f = File('${dir.path}/anh.jpg')..writeAsBytesSync([1, 2, 3]);
    AppSession.instance.emsToken = 'tok';
    late http.Request seen;
    EmsApiService.client = MockClient((req) async {
      seen = req;
      return http.Response('{"ok":true,"attachment":{"id":"9"}}', 201);
    });
    final r = await WorkApi.attach(
      'T1',
      'A1',
      f.readAsBytesSync(),
      filename: 'anh.jpg',
    );
    expect(r['ok'], isTrue);
    expect(seen.method, 'POST');
    expect(seen.url.path, endsWith('/v1/tasks/T1/attachments'));
    expect(seen.headers['Authorization'], 'Bearer tok');
    expect(seen.headers['content-type'], startsWith('multipart/form-data'));
    final body = seen.body;
    expect(body, contains('name="assignment_id"'));
    expect(body, contains('A1'));
    expect(body, contains('name="file"; filename="anh.jpg"'));
    expect(body, contains('content-type: image/jpeg'));
    await dir.delete(recursive: true);
  });

  test('a refused upload surfaces the server message', () async {
    final dir = await Directory.systemTemp.createTemp('handin');
    final f = File('${dir.path}/a.jpg')..writeAsBytesSync([1]);
    EmsApiService.client = MockClient(
      (_) async => http.Response.bytes(
        utf8.encode('{"error":"file_too_large"}'),
        413,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    await expectLater(
      WorkApi.attach('T1', 'A1', f.readAsBytesSync(), filename: 'a.jpg'),
      throwsA(
        isA<EmsException>()
            .having(
              (e) => e.message,
              'message',
              'Tệp quá lớn (tối đa 25 MB mỗi tệp).',
            )
            .having((e) => e.statusCode, 'status', 413),
      ),
    );
    await dir.delete(recursive: true);
  });

  testWidgets('the hand-in sheet offers Đính kèm and returns picked photos', (
    t,
  ) async {
    HandInResult? got;
    await t.pumpWidget(
      MaterialApp(
        theme: VdTheme.light(),
        home: Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () async => got = await showHandInSheet(
                ctx,
                pickPhotos: () async => [
                  (name: 'x.jpg', size: 1, read: () async => <int>[1]),
                ],
                pickFiles: () async => [
                  (name: 'bao-cao.pdf', size: 1, read: () async => <int>[2]),
                ],
                attach: true,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.text('Đính kèm'), findsOneWidget);
    for (final k in ['attach-photo', 'attach-file']) {
      await t.tap(find.byKey(const ValueKey('handin-attach')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(ValueKey(k)));
      await t.pumpAndSettle();
    }
    expect(find.text('x.jpg'), findsOneWidget);
    expect(find.text('bao-cao.pdf'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'xong');
    await t.tap(find.text('Nộp kèm 2 tệp'));
    await t.pumpAndSettle();
    expect(got?.note, 'xong');
    expect(got?.files.map((f) => f.name), ['x.jpg', 'bao-cao.pdf']);
  });

  test('a PDF keeps its name and type', () async {
    final dir = await Directory.systemTemp.createTemp('handin');
    final f = File('${dir.path}/Báo cáo.pdf')..writeAsBytesSync([37, 80]);
    late http.Request seen;
    EmsApiService.client = MockClient((req) async {
      seen = req;
      return http.Response('{"ok":true}', 201);
    });
    await WorkApi.attach(
      'T1',
      'A1',
      f.readAsBytesSync(),
      filename: 'bao-cao.pdf',
    );
    expect(seen.body, contains('filename="bao-cao.pdf"'));
    expect(seen.body, contains('content-type: application/pdf'));
    await dir.delete(recursive: true);
  });

  testWidgets('switched off: no Đính kèm in the sheet', (t) async {
    expect(handInAttachEnabled, isTrue);
    await t.pumpWidget(
      MaterialApp(
        theme: VdTheme.light(),
        home: Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () => showHandInSheet(ctx, attach: false),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.text('Nộp phần việc'), findsOneWidget);
    expect(find.byKey(const ValueKey('handin-attach')), findsNothing);
  });

  test('a file opens from a download made with the session', () async {
    AppSession.instance.emsToken = 'tok';
    late http.Request seen;
    EmsApiService.client = MockClient((req) async {
      seen = req;
      return http.Response.bytes([37, 80, 68, 70], 200);
    });
    final f = await EmsUpload.download(
      '/v1/tasks/T1/attachments/9',
      filename: 'Báo cáo.pdf',
      key: '9',
    );
    expect(seen.method, 'GET');
    expect(seen.url.path, endsWith('/v1/tasks/T1/attachments/9'));
    expect(seen.headers['Authorization'], 'Bearer tok');
    expect(f.path, endsWith('/vd_files/9/Báo cáo.pdf'));
    expect(f.readAsBytesSync(), [37, 80, 68, 70]);
    await f.delete();
  });

  test('a missing file reads plainly', () async {
    EmsApiService.client = MockClient(
      (_) async => http.Response('{"error":"file_missing"}', 404),
    );
    await expectLater(
      EmsUpload.download('/v1/tasks/T1/attachments/9', filename: 'a', key: '9'),
      throwsA(
        isA<EmsException>().having(
          (e) => e.message,
          'message',
          'Tệp không còn trên máy chủ.',
        ),
      ),
    );
  });

  test('picked photos get friendly names', () {
    expect(
      photoNames([
        'image_picker_A1B2.jpg',
        'scaled_1000000020.JPEG',
        'x',
      ], DateTime(2026, 11, 17, 12, 4)),
      [
        'Ảnh 17-11 12.04.jpg',
        'Ảnh 17-11 12.04 (2).jpeg',
        'Ảnh 17-11 12.04 (3).jpg',
      ],
    );
  });

  test('a file over 25 MB is refused before sending', () async {
    var sent = false;
    EmsApiService.client = MockClient((_) async {
      sent = true;
      return http.Response('{}', 201);
    });
    await expectLater(
      WorkApi.attach(
        'T1',
        'A1',
        List<int>.filled(EmsUpload.maxFileBytes + 1, 0),
        filename: 'to.pdf',
      ),
      throwsA(
        isA<EmsException>().having(
          (e) => e.message,
          'message',
          'Tệp quá lớn (tối đa 25 MB mỗi tệp).',
        ),
      ),
    );
    expect(sent, isFalse);
  });

  testWidgets('a file over 25 MB is refused when picked, not read', (t) async {
    var read = false;
    await t.pumpWidget(
      MaterialApp(
        theme: VdTheme.light(),
        home: Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () => showHandInSheet(
                ctx,
                attach: true,
                pickPhotos: () async => const [],
                pickFiles: () async => [
                  (
                    name: 'to.pdf',
                    size: EmsUpload.maxFileBytes + 1,
                    read: () async {
                      read = true;
                      return <int>[];
                    },
                  ),
                ],
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('handin-attach')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('attach-file')));
    await t.pumpAndSettle();
    expect(find.text('to.pdf'), findsNothing);
    expect(find.textContaining('Tệp quá lớn'), findsOneWidget);
    expect(read, isFalse);
  });
}
