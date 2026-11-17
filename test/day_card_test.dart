import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viendongedu2_flutter/features/work_home/day_card.dart';
import 'package:viendongedu2_flutter/features/work_home/home_prefs.dart';
import 'package:viendongedu2_flutter/theme/vd_theme.dart';

const _card = <String, dynamic>{
  'id': '2026-11-20:teachers_day',
  'date': '2026-11-20',
  'title': 'Chúc mừng Ngày Nhà giáo Việt Nam 20/11',
  'line':
      'Nhà trường trân trọng gửi đến quý thầy cô và cán bộ, nhân viên lời '
      'chúc sức khỏe, hạnh phúc và thành công.\nTrường Cao đẳng Viễn Đông',
  'art': 'teachers_day',
};

Widget _app(Map<String, dynamic>? card) => MaterialApp(
  theme: VdTheme.light(),
  home: Scaffold(
    body: Column(
      children: [
        DayCardSlot(card: card),
        const Text('focus'),
      ],
    ),
  ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('day card shows the server text when day_card is present', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_card));
    await tester.pumpAndSettle();
    expect(find.byType(DayCard), findsOneWidget);
    expect(find.text(_card['title'] as String), findsOneWidget);
    expect(find.text('Trường Cao đẳng Viễn Đông'), findsOneWidget);
    expect(find.text('focus'), findsOneWidget);
  });

  testWidgets('no day_card: nothing is drawn', (tester) async {
    await tester.pumpWidget(_app(null));
    await tester.pumpAndSettle();
    expect(find.byType(DayCard), findsNothing);
    expect(find.text('focus'), findsOneWidget);
  });

  testWidgets('one tap closes it and the phone remembers that card', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_card));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('day-card')));
    await tester.pumpAndSettle();
    expect(find.byType(DayCard), findsNothing);
    expect(await HomePrefs.dayCardDismissed(), _card['id']);

    // Reopened: stays closed.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_app(_card));
    await tester.pumpAndSettle();
    expect(find.byType(DayCard), findsNothing);
  });

  testWidgets('a different card id shows again after an older one was closed', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'work_home.day_card_closed': '2025-11-20:teachers_day',
    });
    await tester.pumpWidget(_app(_card));
    await tester.pumpAndSettle();
    expect(find.byType(DayCard), findsOneWidget);
  });

  testWidgets('fits a 360 x 640 phone without overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(_card));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final h = tester.getSize(find.byType(DayCard)).height;
    // Test glyphs are wider than the real font; the card stays one compact block.
    expect(h, lessThan(200));
  });
}
