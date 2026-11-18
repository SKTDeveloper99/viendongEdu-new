import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:viendongedu2_flutter/features/nhom/small_group_screens.dart';
import 'package:viendongedu2_flutter/features/work/work_api.dart';
import 'package:viendongedu2_flutter/features/work_home/give_task_screen.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';
import 'package:viendongedu2_flutter/theme/vd_theme.dart';

Widget _app(Widget child) => MaterialApp(theme: VdTheme.light(), home: child);

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  tearDown(() {
    EmsApiService.client = http.Client();
    AppSession.instance.emsToken = null;
  });

  test('a giver file sent in both lists is shown once', () {
    final files = pieceFiles({
      'instruction_attachments': [
        {'id': 'a', 'filename': 'Bao cao.docx'},
        {'id': 'b', 'filename': 'Bang.xlsx'},
      ],
      'attachments': [
        {'id': 'a', 'filename': 'Bao cao.docx'},
        {'id': 'b', 'filename': 'Bang.xlsx'},
        {'id': 'c', 'filename': 'Nop.jpg', 'assignment_id': 'x'},
      ],
    });
    expect(files.map((f) => f['id']), ['a', 'b']);
  });

  testWidgets('Giao việc sends the files on the piece; a retry sends only '
      'the file that failed and never a second piece', (tester) async {
    AppSession.instance.emsToken = 'tok';
    var creates = 0;
    final uploads = <String>[];
    var failWord = true;
    EmsApiService.client = MockClient((req) async {
      final path = req.url.path;
      if (req.method == 'POST' && path.endsWith('/v1/tasks')) {
        creates++;
        return _json({
          'task': {'id': 'T1'},
        }, 201);
      }
      if (req.method == 'POST' && path.endsWith('/v1/tasks/T1/attachments')) {
        final body = latin1.decode(req.bodyBytes);
        final name = body.contains('Bao cao.docx') ? 'docx' : 'xlsx';
        expect(body.contains('assignment_id'), isFalse);
        uploads.add(name);
        if (name == 'docx' && failWord) {
          failWord = false;
          return _json({'error': 'Lỗi máy chủ'}, 500);
        }
        return _json({'ok': true}, 201);
      }
      return _json({'error': 'not here'}, 404);
    });
    Future<List<int>> bytes() async => utf8.encode('x');
    await tester.pumpWidget(
      _app(
        GiveTaskScreen(
          people: const {'u1': 'Người A', 'u2': 'Người B'},
          pickFiles: () async => [
            (name: 'Bang.xlsx', size: 1, read: bytes),
            (name: 'Bao cao.docx', size: 1, read: bytes),
          ],
        ),
      ),
    );
    await tester.enterText(find.byType(TextField).first, '[THỬ] Báo cáo');
    await tester.tap(find.byKey(const ValueKey('give-attach')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('attach-file')));
    await tester.pumpAndSettle();
    expect(find.text('Giao việc kèm 2 tệp'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('give-send')));
    await tester.pumpAndSettle();
    expect(creates, 1);
    expect(uploads, ['xlsx', 'docx']);
    expect(find.text('Gửi lại 1 tệp chưa gửi'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('give-send')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(creates, 1, reason: 'the piece is never made twice');
    expect(uploads, ['xlsx', 'docx', 'docx']);
  });

  testWidgets('people search finds a sign-in name or a teacher code', (
    tester,
  ) async {
    EmsApiService.client = MockClient(
      (_) async => _json({
        'people': [
          {
            'id': '1',
            'full_name': 'Mạnh Dũng',
            'hint': 'Tuyển sinh · manhdung',
          },
          {'id': '2', 'full_name': 'Trần Quốc Huy', 'hint': 'MGV 0501013'},
        ],
      }),
    );
    await tester.pumpWidget(_app(const PeoplePicker(work: false, title: 'x')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'manhdung');
    await tester.pumpAndSettle();
    expect(find.text('Mạnh Dũng'), findsOneWidget);
    expect(find.text('Trần Quốc Huy'), findsNothing);
    await tester.enterText(find.byType(TextField), '0501013');
    await tester.pumpAndSettle();
    expect(find.text('Trần Quốc Huy'), findsOneWidget);
  });
}
