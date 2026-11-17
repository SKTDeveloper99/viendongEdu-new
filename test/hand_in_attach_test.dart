import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:viendongedu2_flutter/features/work/hand_in_sheet.dart';
import 'package:viendongedu2_flutter/features/work/work_api.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';
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
    final r = await WorkApi.attach('T1', 'A1', f.path, filename: 'anh.jpg');
    expect(r['ok'], isTrue);
    expect(seen.method, 'POST');
    expect(seen.url.path, endsWith('/v1/tasks/T1/attachments'));
    expect(seen.headers['Authorization'], 'Bearer tok');
    expect(seen.headers['content-type'], startsWith('multipart/form-data'));
    final body = seen.body;
    expect(body, contains('name="assignment_id"'));
    expect(body, contains('A1'));
    expect(body, contains('name="file"; filename="anh.jpg"'));
    await dir.delete(recursive: true);
  });

  test('a refused upload surfaces the server message', () async {
    final dir = await Directory.systemTemp.createTemp('handin');
    final f = File('${dir.path}/a.jpg')..writeAsBytesSync([1]);
    EmsApiService.client = MockClient(
      (_) async => http.Response.bytes(
        utf8.encode('{"error":"Tệp quá lớn"}'),
        413,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    await expectLater(
      WorkApi.attach('T1', 'A1', f.path),
      throwsA(
        isA<EmsException>()
            .having((e) => e.message, 'message', 'Tệp quá lớn')
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
                pick: () async => [(path: '/tmp/x.jpg', name: 'x.jpg')],
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.text('Đính kèm ảnh'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('handin-attach')));
    await t.pumpAndSettle();
    expect(find.text('x.jpg'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'xong');
    await t.tap(find.text('Nộp kèm 1 ảnh'));
    await t.pumpAndSettle();
    expect(got?.note, 'xong');
    expect(got?.files.single.name, 'x.jpg');
  });
}
