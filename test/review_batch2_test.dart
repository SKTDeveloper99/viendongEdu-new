import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:viendongedu2_flutter/features/common/load_error.dart';
import 'package:viendongedu2_flutter/features/nhom/small_group_screens.dart';
import 'package:viendongedu2_flutter/features/work/work_api.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';
import 'package:viendongedu2_flutter/services/ems_upload.dart';
import 'package:viendongedu2_flutter/theme/vd_theme.dart';

Widget _app(Widget child) => MaterialApp(theme: VdTheme.light(), home: child);

void main() {
  tearDown(() {
    EmsApiService.client = http.Client();
    AppSession.instance.emsToken = null;
  });

  test('Duyệt carries on when the first step answers 409', () async {
    AppSession.instance.emsToken = 'tok';
    final to = <String>[];
    EmsApiService.client = MockClient((req) async {
      final s = req.body.contains('in_review') ? 'in_review' : 'done';
      to.add(s);
      return s == 'in_review'
          ? http.Response.bytes(
              utf8.encode('{"error":"Nhiệm vụ đã ở trạng thái này"}'),
              409,
              headers: {'content-type': 'application/json; charset=utf-8'},
            )
          : http.Response('{"ok":true}', 200);
    });
    await WorkApi.approve('T', 'A', 'submitted');
    expect(to, ['in_review', 'done']);
  });

  test('sign-out purge deletes saved attachments and never throws', () async {
    final root = await Directory.systemTemp.createTemp('vdfiles');
    final old = EmsUpload.filesRoot;
    EmsUpload.filesRoot = '${root.path}/vd_files';
    File('${root.path}/vd_files/9/a.pdf')
      ..createSync(recursive: true)
      ..writeAsBytesSync([1]);
    await EmsUpload.purgeSavedFiles();
    expect(Directory('${root.path}/vd_files').existsSync(), isFalse);
    await EmsUpload.purgeSavedFiles(); // nothing there: still fine
    EmsUpload.filesRoot = old;
    await root.delete(recursive: true);
  });

  testWidgets('LoadError shows the message and retries', (tester) async {
    var n = 0;
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: LoadError(message: 'Lỗi mạng', onRetry: () => n++),
        ),
      ),
    );
    expect(find.text('Lỗi mạng'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    expect(n, 1);
  });

  testWidgets('people picker refuses a pick beyond max', (tester) async {
    EmsApiService.client = MockClient(
      (_) async => http.Response(
        '{"people":[{"id":"1","full_name":"An"},{"id":"2","full_name":"Bình"}]}',
        200,
      ),
    );
    await tester.pumpWidget(
      _app(const PeoplePicker(work: false, title: 'x', max: 1)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('An'));
    await tester.pump();
    expect(find.text('Đã chọn đủ số người tối đa cho lần này.'), findsNothing);
    await tester.tap(find.text('Bình'));
    await tester.pump();
    expect(find.text('Đã chọn đủ số người tối đa cho lần này.'), findsOneWidget);
    expect(find.text('Xong (1)'), findsOneWidget);
  });

  testWidgets('people picker offers a retry after a failed load', (
    tester,
  ) async {
    var fail = true;
    EmsApiService.client = MockClient(
      (_) async => fail
          ? http.Response('{"error":"x"}', 500)
          : http.Response('{"people":[{"id":"1","full_name":"An"}]}', 200),
    );
    await tester.pumpWidget(_app(const PeoplePicker(work: false, title: 'x')));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.text('Thử lại'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('An'), findsOneWidget);
  });
}
