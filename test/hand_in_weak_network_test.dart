// A Việc hand-in on a weak network: each file resends twice on its own after
// a network failure, the person sees "đang gửi lại (lần 2/3)", and files that
// already went are not sent again on "Thử lại".
//
//   flutter test test/hand_in_weak_network_test.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:viendongedu2_flutter/features/work/hand_in_sheet.dart';
import 'package:viendongedu2_flutter/features/work/hand_in_uploads.dart';
import 'package:viendongedu2_flutter/features/work/piece_screen.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';
import 'package:viendongedu2_flutter/services/ems_upload.dart';
import 'package:viendongedu2_flutter/services/upload_sender.dart';
import 'package:viendongedu2_flutter/theme/vd_theme.dart';

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

PickedFile _f(String name) =>
    (name: name, size: 3, read: () async => <int>[1, 2, 3]);

void main() {
  group('rule e: HandInUploads', () {
    test('file 3 of 5 fails: the next try sends 3, 4, 5 only', () async {
      final up = HandInUploads([for (final n in 'abcde'.split('')) _f(n)]);
      final went = <String>[];
      var failC = true;
      Future<void> send(PickedFile f, void Function(UploadStatus) s) async {
        if (f.name == 'c' && failC) throw EmsException('mạng');
        went.add(f.name);
      }

      await expectLater(up.sendRest(send), throwsA(isA<EmsException>()));
      expect(went, ['a', 'b']);
      expect(up.sentCount, 2);
      expect(
        up.keptLine,
        'Đã gửi 2/5 tệp. Bấm Thử lại để gửi tiếp các tệp còn lại.',
      );
      failC = false;
      await up.sendRest(send);
      expect(went, ['a', 'b', 'c', 'd', 'e']);
      expect(up.allSent, isTrue);
      expect(up.keptLine, isNull);
    });

    test('the line names the file on its way', () {
      final up = HandInUploads([_f('a'), _f('b'), _f('c')]);
      expect(
        up.lineFor(1, const UploadStatus(attempt: 2, attempts: 3)),
        'Tệp 2/3: Mạng yếu, đang gửi lại (lần 2/3)…',
      );
      expect(
        HandInUploads([
          _f('a'),
        ]).lineFor(0, const UploadStatus(attempt: 1, attempts: 3)),
        'Đang gửi…',
      );
    });
  });

  group('the piece screen', () {
    setUp(() {
      AppSession.instance
        ..emsToken = 'tok-TEST26APP01'
        ..userId = 'me';
    });
    tearDown(() {
      EmsApiService.client = http.Client();
      UploadSender.sleep = Future<void>.delayed;
      AppSession.instance
        ..emsToken = null
        ..userId = null;
    });

    testWidgets('rules c, d, e: resends show, sent files stay sent', (
      tester,
    ) async {
      final posted = <String>[]; // file names the server took
      final tries = <String, int>{};
      var networkDown = true;
      var handedIn = 0;
      EmsApiService.client = MockClient((req) async {
        final p = req.url.path;
        if (p.endsWith('/v1/tasks/T1')) {
          return _json({
            'task': {
              'id': 'T1',
              'title': 'Nộp ảnh lớp học',
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
        if (p.endsWith('/v1/tasks/T1/attachments')) {
          final name = RegExp(r'filename="([^"]+)"').firstMatch(req.body)![1]!;
          tries[name] = (tries[name] ?? 0) + 1;
          if (name == 'Ảnh 2.jpg' && networkDown) {
            throw const SocketException('Connection reset by peer');
          }
          posted.add(name);
          return _json({'ok': true}, 201);
        }
        if (p.endsWith('/v1/tasks/my/A1/transition')) {
          handedIn++;
          return _json({'ok': true});
        }
        return _json({'error': 'not here'}, 404);
      });
      // Each pause waits until the test lets it go.
      final gates = <Completer<void>>[];
      UploadSender.sleep = (_) {
        final c = Completer<void>();
        gates.add(c);
        return c.future;
      };
      Future<void> settleSome() async {
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
      }

      await tester.pumpWidget(
        MaterialApp(
          theme: VdTheme.light(),
          home: PieceScreen(
            taskId: 'T1',
            pickPhotos: () async => [
              _f('Ảnh 1.jpg'),
              _f('Ảnh 2.jpg'),
              _f('Ảnh 3.jpg'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Nộp'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('handin-attach')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('attach-photo')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('handin-send')));
      await settleSome();

      // File 2 failed once: the line says it is sending again.
      expect(gates, hasLength(1));
      expect(
        find.text('Tệp 2/3: Mạng yếu, đang gửi lại (lần 2/3)…'),
        findsOneWidget,
      );
      gates.last.complete();
      await settleSome();
      expect(gates, hasLength(2));
      expect(
        find.text('Tệp 2/3: Mạng yếu, đang gửi lại (lần 3/3)…'),
        findsOneWidget,
      );
      gates.last.complete();
      await settleSome();

      // Three attempts, then the screen says so and keeps file 1.
      expect(tries['Ảnh 2.jpg'], 3);
      expect(find.text(EmsUpload.networkMessage), findsOneWidget);
      expect(
        find.text('Đã gửi 1/3 tệp. Bấm Thử lại để gửi tiếp các tệp còn lại.'),
        findsOneWidget,
      );
      expect(handedIn, 0);

      // The network is back: "Thử lại" sends files 2 and 3 only.
      networkDown = false;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(posted, ['Ảnh 1.jpg', 'Ảnh 2.jpg', 'Ảnh 3.jpg']);
      expect(tries['Ảnh 1.jpg'], 1);
      expect(handedIn, 1);
      expect(find.byKey(const ValueKey('handin-line')), findsNothing);
      // Let the screen's own short timers (the check mark) run out.
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('rule d: the report sheet\'s one request shows its resend', (
      tester,
    ) async {
      var tries = 0;
      EmsApiService.client = MockClient((req) async {
        final p = req.url.path;
        if (p.endsWith('/v1/tasks/T1')) {
          return _json({
            'task': {
              'id': 'T1',
              'title': 'Báo cáo trực tuần',
              'is_report': true,
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
              {'assignment_id': 'A1', 'is_report': true, 'max_photos': 8},
            ],
          });
        }
        if (p.endsWith('/v1/teacher/tasks/A1/report')) {
          tries++;
          if (tries == 1) throw const SocketException('Network is unreachable');
          return _json({'ok': true});
        }
        return _json({'error': 'not here'}, 404);
      });
      final gate = Completer<void>();
      UploadSender.sleep = (_) => gate.future;
      await tester.pumpWidget(
        MaterialApp(
          theme: VdTheme.light(),
          home: PieceScreen(
            taskId: 'T1',
            pickPhotos: () async => [_f('Ảnh 1.jpg')],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Nộp'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('report-text')),
        'Trực tuần ổn',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('report-add-photo')),
      );
      await tester.tap(find.byKey(const ValueKey('report-add-photo')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('attach-photo')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('report-send')));
      await tester.tap(find.byKey(const ValueKey('report-send')));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(tries, 1);
      expect(find.text('Mạng yếu, đang gửi lại (lần 2/3)…'), findsOneWidget);
      gate.complete();
      await tester.pumpAndSettle();
      expect(tries, 2);
      expect(find.byKey(const ValueKey('handin-line')), findsNothing);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('rule c: a server refusal is final and shown as it is', (
      tester,
    ) async {
      var tries = 0;
      EmsApiService.client = MockClient((req) async {
        final p = req.url.path;
        if (p.endsWith('/v1/tasks/T1')) {
          return _json({
            'task': {
              'id': 'T1',
              'title': 'Nộp ảnh lớp học',
              'assignments': [
                {'id': 'A1', 'assignee_user_id': 'me', 'status': 'in_progress'},
              ],
            },
          });
        }
        if (p.endsWith('/comments')) return _json({'comments': []});
        if (p.endsWith('/v1/tasks/my')) return _json({'tasks': []});
        if (p.endsWith('/attachments')) {
          tries++;
          return _json({'error': 'Máy chủ đang quá tải, thử lại sau.'}, 503);
        }
        return _json({'error': 'not here'}, 404);
      });
      var paused = 0;
      UploadSender.sleep = (_) async => paused++;
      await tester.pumpWidget(
        MaterialApp(
          theme: VdTheme.light(),
          home: PieceScreen(
            taskId: 'T1',
            pickPhotos: () async => [_f('Ảnh 1.jpg')],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Nộp'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('handin-attach')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('attach-photo')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('handin-send')));
      await tester.pumpAndSettle();
      expect(tries, 1);
      expect(paused, 0);
      expect(find.text('Máy chủ đang quá tải, thử lại sau.'), findsOneWidget);
    });
  });
}
