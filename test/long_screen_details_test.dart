import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viendongedu2_flutter/screens/capbu_screen.dart';
import 'package:viendongedu2_flutter/screens/notifications_screen.dart';
import 'package:viendongedu2_flutter/screens/stale_note.dart';

import 'helpers/screen_harness.dart';

void main() {
  for (final width in [320.0, 430.0]) {
    for (final notifications in [false, true]) {
      testWidgets(
        'long ${notifications ? 'notification' : 'compensation'} detail scrolls at $width',
        (t) async {
          final longBody =
              '${List.filled(50, 'Nội dung thử nghiệm tiếng Việt dài.').join(' ')} Kết thúc thử nghiệm';
          fakeScreenSession((r) async {
            if (r.method != 'GET') return jsonResponse({'ok': true});
            expect(
              r.url.path,
              notifications
                  ? '/api/teacher/notifications'
                  : '/api/student/me/capbu',
            );
            return jsonResponse(
              notifications
                  ? {
                      'data': [
                        {
                          'id': 'TEST26-LONG',
                          'title': 'Thông báo dài thử nghiệm',
                          'body': longBody,
                          'status': 'read',
                        },
                      ],
                    }
                  : {
                      'items': [
                        {
                          'id': 'TEST26-LONG',
                          'ma': 'TEST26-CB',
                          'ten': 'Cấp bù dài thử nghiệm',
                          'thanh_tien': 12345,
                          'ghi_chu': longBody,
                        },
                      ],
                    },
            );
          }, teacher: notifications);
          await openScreen(
            t,
            notifications ? const NotificationsScreen() : const CapBuScreen(),
            width,
          );
          await t.tap(
            find.text(
              notifications
                  ? 'Thông báo dài thử nghiệm'
                  : 'Cấp bù dài thử nghiệm',
            ),
          );
          await t.pumpAndSettle();
          expect(find.byType(BottomSheet), findsOneWidget);
          expect(t.takeException(), isNull);
          final scroll = find.descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(SingleChildScrollView),
          );
          expect(scroll, findsOneWidget);
          final position = t
              .state<ScrollableState>(
                find.descendant(of: scroll, matching: find.byType(Scrollable)),
              )
              .position;
          expect(position.maxScrollExtent, greaterThan(0));
          await t.drag(scroll, const Offset(0, -500));
          await t.pumpAndSettle();
          expect(position.pixels, greaterThan(0));
          expect(t.takeException(), isNull);
          Navigator.of(t.element(find.byType(BottomSheet))).pop();
          await t.pumpAndSettle();
          await expectBack(
            t,
            icon: notifications
                ? Icons.arrow_back_ios_new
                : Icons.arrow_back_ios,
          );
        },
      );
    }
    testWidgets('stale note timestamp and Vietnamese text at $width', (
      t,
    ) async {
      await openScreen(
        t,
        Scaffold(body: StaleNote(DateTime(2026, 10, 20, 8, 5))),
        width,
      );
      expect(
        find.text('Chưa cập nhật được — dữ liệu lúc 08:05 20/10'),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    });
  }
}
