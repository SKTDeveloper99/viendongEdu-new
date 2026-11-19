// Server `overlord/next` 35c083e on the phone (2026-11-18): own-rows Nhóm
// tables (proposed LAW T-58), no "Đã nhận" on task screens (proposed T-59),
// the ring limits (P-32, P-45) and the directory's `?q=`.
//
//   flutter test test/own_rows_table_test.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:viendongedu2_flutter/features/nhom/small_group_screens.dart';
import 'package:viendongedu2_flutter/features/work/piece_table_link.dart';
import 'package:viendongedu2_flutter/features/work/work_api.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';
import 'package:viendongedu2_flutter/theme/vd_theme.dart';

Widget _app(Widget child) => MaterialApp(theme: VdTheme.light(), home: child);

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

const _cols = [
  {'id': 'c1', 'name': 'Ngày sinh', 'kind': 'date'},
  {'id': 'c2', 'name': 'Số CCCD', 'kind': 'text'},
];

Map<String, dynamic> _ownList({required bool shape, required List rows}) => {
  'list': {
    'id': 'L1',
    'title': 'Thông tin',
    'own_rows_only': true,
    'can_edit_columns': shape,
  },
  'columns': _cols,
  'rows': rows,
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

  test(
    'T-59: a new piece reads "Mới giao"; receipts only behind the switch',
    () {
      expect(taskShowsReceipt, isFalse);
      expect(statusLabel('assigned'), 'Mới giao');
      expect(statusLabel('assigned', acknowledged: true), 'Mới giao');
      expect(
        statusLabel('assigned', acknowledged: true, receipts: true),
        'Đã nhận',
      );
      expect(statusLabel('assigned', receipts: true), 'Chưa mở');
    },
  );

  test('a CCCD column is known by its name, marks and case ignored', () {
    expect(isCccdColumn('Số CCCD'), isTrue);
    expect(isCccdColumn('Căn cước công dân'), isTrue);
    expect(isCccdColumn('cccd'), isTrue);
    expect(isCccdColumn('Ngày sinh'), isFalse);
  });

  test('Nộp under a table offers only my open pieces linked to it', () {
    final p = tablePiecesOf([
      {
        'assignment_id': 'a1',
        'is_mine': true,
        'linked_list_id': 'L1',
        'status': 'assigned',
        'title': 'Điền',
      },
      {
        'assignment_id': 'a1',
        'is_mine': true,
        'linked_list_id': 'L1',
        'status': 'assigned',
      },
      {
        'assignment_id': 'a2',
        'is_mine': false,
        'linked_list_id': 'L1',
        'status': 'assigned',
      },
      {
        'assignment_id': 'a3',
        'is_mine': true,
        'linked_list_id': 'L1',
        'status': 'submitted',
      },
      {
        'assignment_id': 'a4',
        'is_mine': true,
        'linked_list_id': 'L2',
        'status': 'in_progress',
      },
    ], 'L1');
    expect(p.map((x) => x.assignmentId), ['a1']);
  });

  testWidgets('own-rows table, member: only my row, no "Thêm dòng"; Nộp '
      'starts then hands in', (tester) async {
    final moves = <String>[];
    EmsApiService.client = MockClient((req) async {
      if (req.method == 'GET' && req.url.path.endsWith('/student-lists/L1')) {
        return _json(
          _ownList(
            shape: false,
            rows: [
              {
                'id': 'r1',
                'kind': 'person',
                'person_user_id': 'me',
                'person_name': 'Tôi',
                'cells': {
                  'c1': {'value': '1990-05-02'},
                  'c2': {'value': '079190000001'},
                },
              },
            ],
          ),
        );
      }
      if (req.url.path.endsWith('/transition')) {
        moves.add(
          '${req.url.pathSegments[req.url.pathSegments.length - 2]}:'
          '${jsonDecode(req.body)['to_status']}',
        );
        return _json({'ok': true});
      }
      return _json({'error': 'not here'}, 404);
    });
    await tester.pumpWidget(
      _app(
        const TableScreen(
          spaceId: 'S1',
          listId: 'L1',
          title: 'Thông tin',
          handIn: [
            TablePiece(assignmentId: 'A1', status: 'assigned', title: 'Điền'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Bạn chỉ thấy và điền dòng của mình.'),
      findsOneWidget,
    );
    expect(find.text('Thêm dòng'), findsNothing);
    expect(find.text('02/05/1990'), findsOneWidget);
    expect(
      find.text('Bạn đã điền đủ. Bấm Nộp để báo người giao việc.'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Nộp'));
    await tester.pumpAndSettle();
    expect(moves, ['A1:in_progress', 'A1:submitted']);
    expect(find.widgetWithText(FilledButton, 'Nộp'), findsNothing);
  });

  testWidgets('own-rows table, member with no row yet: "Thêm dòng của tôi" '
      'adds my own person row', (tester) async {
    final added = <Object?>[];
    var rows = <Map<String, dynamic>>[];
    EmsApiService.client = MockClient((req) async {
      if (req.method == 'GET' && req.url.path.endsWith('/student-lists/L1')) {
        return _json(_ownList(shape: false, rows: rows));
      }
      if (req.method == 'POST' && req.url.path.endsWith('/L1/rows')) {
        added.add(jsonDecode(req.body)['rows']);
        rows = [
          {
            'id': 'r1',
            'kind': 'person',
            'person_user_id': 'me',
            'person_name': 'Tôi',
            'cells': <String, dynamic>{},
          },
        ];
        return _json({'added': 1});
      }
      return _json({'error': 'not here'}, 404);
    });
    await tester.pumpWidget(
      _app(const TableScreen(spaceId: 'S1', listId: 'L1', title: 'x')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Thêm dòng'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('add-my-row')));
    await tester.pumpAndSettle();
    expect(added, [
      [
        {'user_id': 'me'},
      ],
    ]);
    expect(find.text('Tôi'), findsOneWidget);
    expect(find.byKey(const ValueKey('add-my-row')), findsNothing);
  });

  testWidgets('a CCCD of 11 digits is refused on the phone, never sent', (
    tester,
  ) async {
    var puts = 0;
    EmsApiService.client = MockClient((req) async {
      if (req.method == 'PUT') {
        puts++;
        return _json({'ok': true});
      }
      return _json(
        _ownList(
          shape: false,
          rows: [
            {
              'id': 'r1',
              'kind': 'person',
              'person_user_id': 'me',
              'person_name': 'Tôi',
              'cells': {},
            },
          ],
        ),
      );
    });
    await tester.pumpWidget(
      _app(const TableScreen(spaceId: 'S1', listId: 'L1', title: 'x')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('—').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '0791 9000 001');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(find.text('Số CCCD phải đủ 12 chữ số.'), findsOneWidget);
    expect(puts, 0);
  });

  testWidgets('own-rows table, its maker: "Thêm cả nhóm" adds each member '
      'not yet on it', (tester) async {
    List? sent;
    EmsApiService.client = MockClient((req) async {
      final p = req.url.path;
      if (req.method == 'GET' && p.endsWith('/spaces/S1')) {
        return _json({
          'members': [
            {'user_id': 'me', 'is_active': true},
            {'user_id': 'u2', 'is_active': true},
            {'user_id': 'u3', 'is_active': false},
          ],
        });
      }
      if (req.method == 'POST' && p.endsWith('/rows')) {
        sent = jsonDecode(req.body)['rows'] as List;
        return _json({'results': []});
      }
      return _json(
        _ownList(
          shape: true,
          rows: [
            {'id': 'r1', 'kind': 'person', 'person_user_id': 'me', 'cells': {}},
          ],
        ),
      );
    });
    await tester.pumpWidget(
      _app(const TableScreen(spaceId: 'S1', listId: 'L1', title: 'x')),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Mỗi người chỉ thấy và điền dòng của mình; bạn thấy'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Thêm cả nhóm'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Thêm 1 thành viên của nhóm vào danh sách, mỗi người một dòng?',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Thêm'));
    await tester.pumpAndSettle();
    expect(sent, [
      {'user_id': 'u2'},
    ]);
  });

  testWidgets('a piece with a table: the lead sees each line, "Đã điền 1/2"', (
    tester,
  ) async {
    EmsApiService.client = MockClient((req) async {
      expect(req.url.path, endsWith('/spaces/S1/tasks/T1'));
      return _json({
        'assignments': [],
        'linked_list': {
          'id': 'L1',
          'title': 'Thông tin',
          'own_rows_only': true,
          'columns': _cols,
        },
        'assignee_rows': [
          {
            'name': 'Người A',
            'rows': [
              {
                'row_id': 'r1',
                'cells': {
                  'c1': {'value': '1990-05-02'},
                  'c2': {'value': '079190000001'},
                },
              },
            ],
          },
          {'name': 'Người B', 'rows': []},
        ],
      });
    });
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: PieceTableLink(
            spaceId: 'S1',
            taskId: 'T1',
            section: Text.new,
            onBack: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bảng cần điền'), findsOneWidget);
    expect(find.textContaining('Đã điền 1/2'), findsOneWidget);
    expect(find.text('Ngày sinh: 02/05/1990'), findsOneWidget);
    expect(find.text('Chưa có dòng.'), findsOneWidget);
    expect(find.text('Mở bảng'), findsOneWidget);
    expect(find.text('Mở dòng của bạn'), findsNothing);
  });

  testWidgets('a receiver with an open part gets "Mở dòng của bạn"', (
    tester,
  ) async {
    EmsApiService.client = MockClient(
      (_) async => _json({
        'linked_list': {
          'id': 'L1',
          'title': 'Thông tin',
          'own_rows_only': true,
          'columns': _cols,
        },
        'assignee_rows': [
          {'name': 'Tôi', 'rows': []},
        ],
      }),
    );
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: PieceTableLink(
            spaceId: 'S1',
            taskId: 'T1',
            mine: const {'id': 'A1', 'status': 'assigned'},
            section: Text.new,
            onBack: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mở dòng của bạn'), findsOneWidget);
    expect(
      find.textContaining('Bạn chỉ thấy và điền dòng của mình'),
      findsOneWidget,
    );
  });

  testWidgets('no table on the piece: nothing is shown', (tester) async {
    EmsApiService.client = MockClient(
      (_) async => _json({'assignments': [], 'linked_list': null}),
    );
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: PieceTableLink(
            spaceId: 'S1',
            taskId: 'T1',
            section: Text.new,
            onBack: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bảng cần điền'), findsNothing);
  });

  testWidgets('people search asks the server with ?q= and shows its answer', (
    tester,
  ) async {
    final asked = <String?>[];
    EmsApiService.client = MockClient((req) async {
      asked.add(req.url.queryParameters['q']);
      return req.url.queryParameters['q'] == null
          ? _json({
              'people': [
                {'id': '1', 'full_name': 'An'},
              ],
            })
          : _json({
              'people': [
                {'id': '9', 'full_name': 'Bình', 'hint': 'MGV 0601030'},
              ],
            });
    });
    await tester.pumpWidget(_app(const PeoplePicker(title: 'x')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '0601');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(asked, [null, '0601']);
    expect(find.text('Bình'), findsOneWidget);
  });

  testWidgets('Nhóm mới shows the ring limits and stops at 0 left today', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const NewGroupScreen(
          limits: {
            'lead': false,
            'member_max': 30,
            'open_per_day': 3,
            'open_left_today': 0,
          },
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Nhóm thử');
    await tester.pump();
    expect(
      find.text('Tối đa 30 người ngoài bạn · hôm nay còn mở được 0/3 nhóm'),
      findsOneWidget,
    );
    final b = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Mở nhóm'),
    );
    expect(b.onPressed, isNull);
  });

  test('Duyệt in a Nhóm whose head gave the work: one call finishes it, '
      'no second call (LAW T-46)', () async {
    final sent = <String>[];
    EmsApiService.client = MockClient((req) async {
      final to = jsonDecode(req.body)['to_status'] as String;
      sent.add(to);
      return _json({
        'ok': true,
        'assignment': {'status': 'done'},
      });
    });
    await WorkApi.approve('T1', 'A1', 'submitted');
    expect(sent, ['in_review']);
  });

  test('Duyệt when a second signer is still due: the 409 after my signature '
      'is not an error', () async {
    final sent = <String>[];
    EmsApiService.client = MockClient((req) async {
      final to = jsonDecode(req.body)['to_status'] as String;
      sent.add(to);
      return to == 'in_review'
          ? _json({
              'ok': true,
              'assignment': {'status': 'in_review'},
            })
          : _json({'error': 'Bạn đã ký duyệt việc này rồi'}, 409);
    });
    await WorkApi.approve('T1', 'A1', 'submitted');
    expect(sent, ['in_review', 'done']);
  });

  test('Duyệt outside a Nhóm still goes in_review then done', () async {
    final sent = <String>[];
    EmsApiService.client = MockClient((req) async {
      final to = jsonDecode(req.body)['to_status'] as String;
      sent.add(to);
      return _json({
        'ok': true,
        'assignment': {'status': to},
      });
    });
    await WorkApi.approve('T1', 'A1', 'submitted');
    expect(sent, ['in_review', 'done']);
  });

  test('a 409 on done without my signature first is still an error', () async {
    EmsApiService.client = MockClient(
      (_) async => _json({'error': 'Việc này chưa được nộp để duyệt'}, 409),
    );
    expect(
      () => WorkApi.approve('T1', 'A1', 'in_review'),
      throwsA(isA<EmsException>()),
    );
  });
}
