import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:viendongedu2_flutter/screens/notifications_screen.dart';

import 'helpers/screen_harness.dart';

const _notification = {
  'id': 'TEST26-NOTICE',
  'title': 'Thông báo thử nghiệm',
  'body': 'Nội dung thông báo tiếng Việt thử nghiệm',
  'status': 'unread',
  'sentAt': '2026-01-01T00:00:00Z',
};
const _path = '/api/teacher/notifications';

void main() {
  for (final width in [320.0, 430.0]) {
    testWidgets('notifications loading, error, retry, empty at $width', (
      t,
    ) async {
      final pending = Completer<http.Response>();
      var calls = 0;
      fakeScreenSession((r) async {
        expect(r.url.path, _path);
        return ++calls == 1 ? pending.future : jsonResponse({'data': []});
      }, teacher: true);
      await openScreen(t, const NotificationsScreen(), width, settle: false);
      expect(find.text('Thông báo'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Chưa có thông báo nào'), findsNothing);
      pending.complete(jsonResponse({'error': 'Lỗi thử nghiệm'}, 500));
      await t.pumpAndSettle();
      expect(find.text('Không thể tải thông báo'), findsOneWidget);
      expect(find.text('Chưa có thông báo nào'), findsNothing);
      await t.tap(find.text('Thử lại'));
      await t.pumpAndSettle();
      expect(calls, 2);
      expect(find.text('Chưa có thông báo nào'), findsOneWidget);
      expect(t.takeException(), isNull);
      await expectBack(t, icon: Icons.arrow_back_ios_new);
    });

    for (final failWrite in [false, true]) {
      testWidgets(
        'notifications detail, read and read-all ${failWrite ? 'failure' : 'success'} at $width',
        (t) async {
          final writes = <String>[];
          var reads = 0;
          fakeScreenSession((r) async {
            if (r.method == 'GET') {
              expect(r.url.path, _path);
              reads++;
              return jsonResponse({
                'data': [
                  _notification,
                  {
                    ..._notification,
                    'id': 'TEST26-NOTICE-2',
                    'title': 'Thông báo thứ hai',
                  },
                ],
              });
            }
            writes.add('${r.method} ${r.url.path}');
            if (r.method == 'PATCH') expect(jsonDecode(r.body), {'read': true});
            return jsonResponse(
              failWrite ? {'error': 'Lỗi thử nghiệm'} : {'ok': true},
              failWrite ? 500 : 200,
            );
          }, teacher: true);
          await openScreen(t, const NotificationsScreen(), width);
          expect(find.byIcon(Icons.notifications_active), findsNWidgets(2));
          await t.tap(find.text('Thông báo thử nghiệm'));
          await t.pumpAndSettle();
          expect(find.byType(BottomSheet), findsOneWidget);
          expect(find.text(_notification['body']!), findsWidgets);
          expect(writes, ['PATCH $_path/TEST26-NOTICE']);
          expect(
            find.byIcon(Icons.notifications_active),
            findsNWidgets(failWrite ? 2 : 1),
          );
          Navigator.of(t.element(find.byType(BottomSheet))).pop();
          await t.pumpAndSettle();
          await t.tap(find.text('Đọc tất cả'));
          await t.pumpAndSettle();
          expect(writes.last, 'POST $_path/mark-all-read');
          expect(
            find.text('Đọc tất cả'),
            failWrite ? findsOneWidget : findsNothing,
          );
          expect(
            find.byIcon(Icons.notifications_active),
            failWrite ? findsNWidgets(2) : findsNothing,
          );
          await t.drag(find.byType(ListView), const Offset(0, 350));
          await t.pumpAndSettle();
          expect(reads, 2);
          expect(t.takeException(), isNull);
          await expectBack(t, icon: Icons.arrow_back_ios_new);
        },
      );
    }
  }
}
