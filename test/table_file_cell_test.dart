// A Nhóm table's "Tệp / ảnh" cell on the phone (CRM LAW T-64): the server's
// file_rules, the checks before sending, the upload with progress, the
// server's refusal, who sees "+".
//
//   flutter test test/table_file_cell_test.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:viendongedu2_flutter/features/nhom/small_group_screens.dart';
import 'package:viendongedu2_flutter/features/nhom/table_file_cell.dart';
import 'package:viendongedu2_flutter/features/nhom/table_file_sheet.dart';
import 'package:viendongedu2_flutter/features/work/hand_in_sheet.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';
import 'package:viendongedu2_flutter/services/ems_upload.dart';
import 'package:viendongedu2_flutter/theme/vd_theme.dart';

Widget _app(Widget child) => MaterialApp(theme: VdTheme.light(), home: child);

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

PickedFile _file(String name, int size) =>
    (name: name, size: size, read: () async => List.filled(size, 1));

const _api = CellFilesApi('S1', 'L1', 'R1', 'C1');

Map<String, dynamic> _pdf(String id) => {
  'id': id,
  'name': 'Bản sao $id.pdf',
  'mime': 'application/pdf',
  'size': 2048,
  'thumb': false,
  'can_remove': true,
};

Map<String, dynamic> _table({
  required List rows,
  bool own = false,
  bool shape = false,
  Map? rules,
}) => {
  'list': {
    'id': 'L1',
    'title': 'Hồ sơ',
    'own_rows_only': own,
    'can_edit_columns': shape,
  },
  'columns': [
    {'id': 'C0', 'name': 'Số CCCD', 'kind': 'text'},
    {'id': 'C1', 'name': 'Ảnh CCCD', 'kind': 'file'},
  ],
  'rows': rows,
  'file_rules': ?rules,
};

void main() {
  setUp(() {
    AppSession.instance
      ..emsToken = 'tok'
      ..userId = 'me';
  });
  tearDown(() {
    EmsApiService.client = http.Client();
    AppSession.instance
      ..emsToken = null
      ..userId = null;
  });

  test('file_rules from the server win; missing or odd values fall back', () {
    final r = CellFileRules.of({
      'accept': ['PDF', 'png'],
      'file_bytes': 1000,
      'per_cell': 2,
      'type_text': 'Chỉ nhận PDF hoặc PNG.',
    });
    expect(r.accept, ['pdf', 'png']);
    expect(r.fileBytes, 1000);
    expect(r.perCell, 2);
    expect(r.typeText, 'Chỉ nhận PDF hoặc PNG.');
    expect(r.tooLargeText, CellFileRules.fallback.tooLargeText);
    expect(r.takes('Bản sao.PDF'), isTrue);
    expect(r.takes('a.docx'), isFalse);
    final none = CellFileRules.of(null);
    expect(none.perCell, 5);
    expect(none.fileBytes, 25 * 1024 * 1024);
    expect(CellFileRules.of({'per_cell': -1, 'accept': []}).perCell, 5);
  });

  test('before sending: wrong type, too large and over the count are left '
      'out with the server\'s words', () {
    final rules = CellFileRules.of({
      'accept': ['jpg', 'pdf'],
      'file_bytes': 100,
      'per_cell': 3,
      'too_large_text': 'Mỗi tệp tối đa 100 B.',
    });
    final c = checkCellFiles(
      [
        _file('a.jpg', 10),
        _file('b.exe', 10),
        _file('c.pdf', 200),
        _file('d.pdf', 10),
        _file('e.pdf', 10),
      ],
      rules,
      1,
    );
    expect(c.ok.map((f) => f.name), ['a.jpg', 'd.pdf']);
    expect(c.notes, [
      'b.exe: ${rules.typeText}',
      'c.pdf: Mỗi tệp tối đa 100 B.',
      'e.pdf: mỗi ô giữ tối đa 3 tệp.',
    ]);
  });

  test(
    'upload: the web cell route, field "files", progress to the end',
    () async {
      late http.Request seen;
      EmsApiService.client = MockClient((req) async {
        seen = req;
        return _json({'ok': true, 'files': []}, 201);
      });
      final steps = <(int, int)>[];
      await _api.add(
        [(bytes: List.filled(200 * 1024, 7), filename: 'Ảnh 20-11.jpg')],
        maxBytes: 1024 * 1024,
        onProgress: (s, t) => steps.add((s, t)),
      );
      expect(seen.method, 'POST');
      expect(
        seen.url.path,
        endsWith('/spaces/S1/student-lists/L1/rows/R1/cells/C1/files'),
      );
      expect(seen.headers['Authorization'], 'Bearer tok');
      expect(seen.headers['content-type'], startsWith('multipart/form-data'));
      expect(
        utf8.decode(seen.bodyBytes, allowMalformed: true),
        contains('name="files"; filename='),
      );
      expect(steps.length, greaterThan(3));
      expect(steps.last.$1, steps.last.$2);
      expect(steps.last.$2, seen.bodyBytes.length);
    },
  );

  test('a file over the server\'s ceiling is never sent', () async {
    var sent = false;
    EmsApiService.client = MockClient((_) async {
      sent = true;
      return _json({});
    });
    await expectLater(
      _api.add([(bytes: List.filled(11, 1), filename: 'a.pdf')], maxBytes: 10),
      throwsA(isA<EmsException>()),
    );
    expect(sent, isFalse);
  });

  test('remove: DELETE on the file', () async {
    late http.Request seen;
    EmsApiService.client = MockClient((req) async {
      seen = req;
      return _json({'ok': true});
    });
    await _api.remove('F9');
    expect(seen.method, 'DELETE');
    expect(seen.url.path, endsWith('/rows/R1/cells/C1/files/F9'));
  });

  testWidgets('a refused upload shows the server\'s Vietnamese message', (
    tester,
  ) async {
    EmsApiService.client = MockClient(
      (_) async => _json({
        'error': 'Nội dung tệp không khớp với loại tệp.',
        'code': 'unsupported_type',
      }, 415),
    );
    late BuildContext ctx;
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    final done = addCellFiles(
      ctx,
      api: _api,
      rules: CellFileRules.fallback,
      already: 0,
      pickers: CellPickers(
        files: (_) async => [_file('gia.pdf', 10)],
        photos: () async => const [],
        camera: () async => const [],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chụp ảnh'), findsOneWidget);
    expect(find.text('Chọn ảnh'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('cell-pick-file')));
    await tester.pumpAndSettle();
    expect(await done, isFalse);
    expect(find.text('Nội dung tệp không khớp với loại tệp.'), findsOneWidget);
    expect(find.byKey(const ValueKey('cell-upload-progress')), findsNothing);
  });

  testWidgets('the table shows a file cell with its count and "+"; a full '
      'cell (server per_cell) has no "+"', (tester) async {
    EmsApiService.client = MockClient(
      (_) async => _json(
        _table(
          rules: {'per_cell': 2},
          rows: [
            {
              'id': 'R1',
              'kind': 'text',
              'label': 'Dòng một',
              'created_by': 'me',
              'cells': {
                'C1': {
                  'value': '1 tệp',
                  'count': 1,
                  'files': [_pdf('F1')],
                },
              },
            },
            {
              'id': 'R2',
              'kind': 'text',
              'label': 'Dòng hai',
              'created_by': 'me',
              'cells': {
                'C1': {
                  'value': '2 tệp',
                  'count': 2,
                  'files': [_pdf('F2'), _pdf('F3')],
                },
              },
            },
          ],
        ),
      ),
    );
    await tester.pumpWidget(
      _app(const TableScreen(spaceId: 'S1', listId: 'L1', title: 'Hồ sơ')),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 tệp'), findsOneWidget);
    expect(find.text('2 tệp'), findsOneWidget);
    expect(find.text('PDF'), findsNWidgets(3));
    expect(find.byKey(const ValueKey('cell-file-add')), findsOneWidget);
    // The cell lists its files; each can be removed (server can_remove).
    await tester.tap(find.text('2 tệp'));
    await tester.pumpAndSettle();
    expect(find.text('Ảnh CCCD · 2/2 tệp'), findsOneWidget);
    expect(find.byKey(const ValueKey('cell-remove-F2')), findsOneWidget);
    expect(find.byKey(const ValueKey('cell-sheet-add')), findsNothing);
  });

  testWidgets('own-rows table: a row that is not mine shows its files '
      'without "+" or ✕', (tester) async {
    EmsApiService.client = MockClient(
      (_) async => _json(
        _table(
          own: true,
          rows: [
            {
              'id': 'R9',
              'kind': 'person',
              'person_user_id': 'someone',
              'person_name': 'Người khác',
              'cells': {
                'C1': {
                  'value': '1 tệp',
                  'count': 1,
                  'files': [
                    {..._pdf('F9'), 'can_remove': false},
                  ],
                },
              },
            },
          ],
        ),
      ),
    );
    await tester.pumpWidget(
      _app(const TableScreen(spaceId: 'S1', listId: 'L1', title: 'Hồ sơ')),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 tệp'), findsOneWidget);
    expect(find.byKey(const ValueKey('cell-file-add')), findsNothing);
    await tester.tap(find.text('1 tệp'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('cell-sheet-file-F9')), findsOneWidget);
    expect(find.byKey(const ValueKey('cell-remove-F9')), findsNothing);
    expect(find.byKey(const ValueKey('cell-sheet-add')), findsNothing);
  });

  test('EmsUpload.files keeps its 25 MB default for other callers', () {
    expect(EmsUpload.maxFileBytes, 25 * 1024 * 1024);
  });
}
