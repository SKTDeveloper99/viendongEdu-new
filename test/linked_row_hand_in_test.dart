// A hand-in on a piece linked to a Nhóm table, refused by the server while
// my row is empty (proposed LAW T-60): the message shows and leads to my row.
//
//   flutter test test/linked_row_hand_in_test.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:viendongedu2_flutter/features/nhom/small_group_screens.dart';
import 'package:viendongedu2_flutter/features/work/piece_screen.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';
import 'package:viendongedu2_flutter/theme/vd_theme.dart';

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

const _refusal =
    'Việc này gắn với một bảng trong Nhóm. Bạn chưa điền dòng của mình '
    'trong bảng đó — hãy mở trong Nhóm, điền dòng của mình rồi nộp.';

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

  testWidgets('an empty-row refusal shows and opens my row', (tester) async {
    EmsApiService.client = MockClient((req) async {
      final p = req.url.path;
      if (p.endsWith('/v1/tasks/T1')) {
        return _json({
          'task': {
            'id': 'T1',
            'title': 'Điền CCCD',
            'space_id': 'S1',
            'title_meta': {'for_list_id': 'L1'},
            'requires_review': true,
            'assignments': [
              {'id': 'A1', 'assignee_user_id': 'me', 'status': 'in_progress'},
            ],
          },
        });
      }
      if (p.endsWith('/comments')) return _json({'comments': []});
      if (p.endsWith('/v1/tasks/my')) {
        return _json({
          'tasks': [
            {'assignment_id': 'A1', 'is_report': false},
          ],
        });
      }
      if (p.endsWith('/v1/tasks/my/A1/transition')) {
        return _json({'error': _refusal, 'listRowEmpty': true}, 400);
      }
      if (p.endsWith('/student-lists/L1')) {
        return _json({
          'list': {'id': 'L1', 'own_rows_only': true},
          'columns': [],
          'rows': [],
        });
      }
      return _json({'error': 'not here'}, 404);
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: VdTheme.light(),
        home: const PieceScreen(taskId: 'T1'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Nộp'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('handin-send')));
    await tester.pumpAndSettle();
    expect(find.text(_refusal), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('open-my-row')));
    await tester.pumpAndSettle();
    expect(find.byType(TableScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('add-my-row')), findsOneWidget);
  });
}
