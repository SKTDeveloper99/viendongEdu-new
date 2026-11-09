import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viendongedu2_flutter/components/student_notices.dart';
import 'package:viendongedu2_flutter/models/student_notice.dart';

// 10/11/2026 09:00 in Vietnam, whatever the test machine's zone.
final _now = DateTime.utc(2026, 11, 10, 2);

void main() {
  group('parseStudentNotices (contract S3)', () {
    test('missing, null, wrong type and empty all mean nothing', () {
      expect(parseStudentNotices(null), isEmpty);
      expect(parseStudentNotices(<String, dynamic>{}), isEmpty);
      expect(parseStudentNotices({'notices': null}), isEmpty);
      expect(parseStudentNotices({'notices': 'urgent'}), isEmpty);
      expect(parseStudentNotices({'notices': {}}), isEmpty);
      expect(parseStudentNotices({'notices': []}), isEmpty);
      expect(parseStudentNotices([1, 2]), isEmpty);
    });

    test('keeps server order, skips entries without text', () {
      final list = parseStudentNotices({
        'notices': [
          {'id': 'b', 'level': 'urgent', 'text': 'Thông báo B'},
          'rác',
          {'id': 'x', 'level': 'info'},
          {'id': 'y', 'level': 'info', 'text': '   '},
          {'id': 'a', 'level': 'warning', 'text': ' Thông báo A '},
        ],
      });
      expect(list.map((n) => n.id), ['b', 'a']);
      expect(list.map((n) => n.level), [
        StudentNoticeLevel.urgent,
        StudentNoticeLevel.warning,
      ]);
      expect(list.last.text, 'Thông báo A');
    });

    test('unknown level is info; missing id gets a stable fallback', () {
      final list = parseStudentNotices({
        'notices': [
          {'level': 'critical', 'text': 'Một'},
          {'id': 7, 'text': 'Hai'},
        ],
      });
      expect(list[0].level, StudentNoticeLevel.info);
      expect(list[0].id, 'notice-0');
      expect(list[1].id, 'notice-1');
    });

    test('until is a Vietnam day: shown through that day, hidden after', () {
      final list = parseStudentNotices({
        'notices': [
          {'id': 'past', 'text': 'Hôm qua', 'until': '2026-11-09'},
          {'id': 'today', 'text': 'Hôm nay', 'until': '2026-11-10'},
          {'id': 'later', 'text': 'Sau này', 'until': '2026-11-14'},
          {'id': 'none', 'text': 'Không hạn'},
          {'id': 'bad', 'text': 'Ngày hỏng', 'until': '14/11/2026'},
          {'id': 'impossible', 'text': 'Ngày sai', 'until': '2026-02-31'},
        ],
      });
      expect(visibleStudentNotices(list, _now).map((n) => n.id), [
        'today',
        'later',
        'none',
        'bad',
        'impossible',
      ]);
      // 23:30 on 10/11 UTC is already 11/11 in Vietnam.
      final lateEvening = DateTime.utc(2026, 11, 10, 17, 30);
      expect(
        visibleStudentNotices(list, lateEvening).map((n) => n.id),
        isNot(contains('today')),
      );
    });
  });

  group('StudentNoticeList', () {
    Future<void> pump(WidgetTester t, List<StudentNotice> notices) =>
        t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  StudentNoticeList(notices: notices, now: () => _now),
                  const Text('nội dung'),
                ],
              ),
            ),
          ),
        );

    testWidgets('draws nothing at all when empty or all expired', (t) async {
      await pump(t, const []);
      expect(find.byType(StudentNoticeBanner), findsNothing);
      expect(t.getSize(find.byType(StudentNoticeList)).height, 0);

      await pump(t, [
        StudentNotice(
          id: 'old',
          level: StudentNoticeLevel.urgent,
          text: 'Đã hết hạn',
          until: DateTime(2026, 11, 1),
        ),
      ]);
      expect(find.byType(StudentNoticeBanner), findsNothing);
      expect(find.text('Đã hết hạn'), findsNothing);
    });

    testWidgets('draws every visible notice in order with its level', (
      t,
    ) async {
      await pump(t, [
        const StudentNotice(
          id: 'u',
          level: StudentNoticeLevel.urgent,
          text: 'Khẩn',
        ),
        const StudentNotice(
          id: 'i',
          level: StudentNoticeLevel.info,
          text: 'Tin',
        ),
      ]);
      final banners = t
          .widgetList<StudentNoticeBanner>(find.byType(StudentNoticeBanner))
          .toList();
      expect(banners.map((b) => b.text), ['Khẩn', 'Tin']);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
    });
  });
}
