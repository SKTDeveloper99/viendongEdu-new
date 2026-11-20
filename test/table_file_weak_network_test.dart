// A Nhóm "Tệp / ảnh" cell on a weak network: the upload dialog says it is
// sending again; a refusal is final; the server's file_rules still apply.
//
//   flutter test test/table_file_weak_network_test.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:viendongedu2_flutter/features/nhom/table_file_cell.dart';
import 'package:viendongedu2_flutter/features/nhom/table_file_sheet.dart';
import 'package:viendongedu2_flutter/features/work/hand_in_sheet.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';
import 'package:viendongedu2_flutter/services/upload_sender.dart';
import 'package:viendongedu2_flutter/theme/vd_theme.dart';

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

PickedFile _file(String name, int size) =>
    (name: name, size: size, read: () async => List.filled(size, 1));

const _api = CellFilesApi('S1', 'L1', 'R1', 'C1');

Future<BuildContext> _host(WidgetTester tester) async {
  late BuildContext ctx;
  await tester.pumpWidget(
    MaterialApp(
      theme: VdTheme.light(),
      home: Scaffold(
        body: Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox();
          },
        ),
      ),
    ),
  );
  return ctx;
}

void main() {
  setUp(() => AppSession.instance.emsToken = 'tok-TEST26APP01');
  tearDown(() {
    EmsApiService.client = http.Client();
    UploadSender.sleep = Future<void>.delayed;
    AppSession.instance.emsToken = null;
  });

  testWidgets('a dropped connection: "đang gửi lại (lần 2/3)", then it goes', (
    tester,
  ) async {
    var tries = 0;
    EmsApiService.client = MockClient((_) async {
      tries++;
      if (tries == 1) throw const SocketException('Connection reset by peer');
      return _json({'ok': true, 'files': []}, 201);
    });
    final gate = Completer<void>();
    UploadSender.sleep = (_) => gate.future;
    final ctx = await _host(tester);
    final done = addCellFiles(
      ctx,
      api: _api,
      rules: CellFileRules.fallback,
      already: 0,
      pickers: CellPickers(
        files: (_) async => [_file('Bản sao CCCD.pdf', 10)],
        photos: () async => const [],
        camera: () async => const [],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cell-pick-file')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Mạng yếu, đang gửi lại (lần 2/3)…'), findsOneWidget);
    gate.complete();
    await tester.pumpAndSettle();
    expect(await done, isTrue);
    expect(tries, 2);
    expect(find.text('Đã thêm 1 tệp.'), findsOneWidget);
  });

  testWidgets('a 429 refusal is final: sent once, the server\'s words shown', (
    tester,
  ) async {
    var tries = 0;
    EmsApiService.client = MockClient((_) async {
      tries++;
      return _json({'error': 'Bạn gửi quá nhanh, chờ một chút.'}, 429);
    });
    var paused = 0;
    UploadSender.sleep = (_) async => paused++;
    final ctx = await _host(tester);
    final done = addCellFiles(
      ctx,
      api: _api,
      rules: CellFileRules.fallback,
      already: 0,
      pickers: CellPickers(
        files: (_) async => [_file('Bản sao CCCD.pdf', 10)],
        photos: () async => const [],
        camera: () async => const [],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cell-pick-file')));
    await tester.pumpAndSettle();
    expect(await done, isFalse);
    expect(tries, 1);
    expect(paused, 0);
    expect(find.text('Bạn gửi quá nhanh, chờ một chút.'), findsOneWidget);
  });

  test('the server\'s per-file limit still applies to what is sent', () async {
    var tries = 0;
    EmsApiService.client = MockClient((_) async {
      tries++;
      return _json({});
    });
    await expectLater(
      _api.add([(bytes: List.filled(11, 1), filename: 'a.jpg')], maxBytes: 10),
      throwsA(isA<EmsException>().having((e) => e.statusCode, 's', 413)),
    );
    expect(tries, 0);
  });
}
