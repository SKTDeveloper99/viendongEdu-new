// Header greeting doodle: scene by device hour, draws in once, instant under
// reduced motion, tap redraws, and both homes' header carries it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viendongedu2_flutter/components/greeting_doodle.dart';
import 'package:viendongedu2_flutter/components/home_header_bar.dart';
import 'package:viendongedu2_flutter/core/greeting.dart';
import 'package:viendongedu2_flutter/theme/vd_theme.dart';

DateTime _at(int h) => DateTime(2026, 10, 7, h, 30);

DoodlePainter _painter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.descendant(
                of: find.byType(GreetingDoodle),
                matching: find.byType(CustomPaint),
              ),
            )
            .painter!
        as DoodlePainter;

Widget _host(Widget child, {bool reduced = false}) => MaterialApp(
  theme: VdTheme.light(),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  test('scene follows the device hour at each boundary', () {
    final expected = {
      0: DoodleScene.sleepyMoon,
      3: DoodleScene.sleepyMoon,
      4: DoodleScene.sunrise,
      11: DoodleScene.sunrise,
      12: DoodleScene.sunCloud,
      17: DoodleScene.sunCloud,
      18: DoodleScene.moonStars,
      21: DoodleScene.moonStars,
      22: DoodleScene.sleepyMoon,
      23: DoodleScene.sleepyMoon,
    };
    expected.forEach((h, s) => expect(doodleSceneFor(_at(h)), s, reason: '$h'));
  });

  testWidgets('draws in once over time and settles fully drawn', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(GreetingDoodle(now: _at(8), color: Colors.black)),
    );
    expect(_painter(tester).progress, 0);
    await tester.pump(const Duration(milliseconds: 800));
    final mid = _painter(tester).progress;
    expect(mid, greaterThan(0));
    expect(mid, lessThan(1));
    await tester.pumpAndSettle();
    expect(_painter(tester).progress, 1);
    expect(_painter(tester).scene, DoodleScene.sunrise);
  });

  testWidgets('reduced motion shows the finished doodle immediately', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(GreetingDoodle(now: _at(20), color: Colors.black), reduced: true),
    );
    await tester.pump();
    expect(_painter(tester).progress, 1);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('a tap redraws it from the start', (tester) async {
    await tester.pumpWidget(
      _host(GreetingDoodle(now: _at(14), color: Colors.black)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(GreetingDoodle));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_painter(tester).progress, lessThan(0.5));
    await tester.pumpAndSettle();
    expect(_painter(tester).progress, 1);
  });

  testWidgets('the shared home header carries the doodle for its hour', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        HomeHeaderBar(
          now: _at(23),
          name: 'Học Viên Thử Nghiệm',
          chips: const ['MSSV: TEST26001'],
          unreadCount: 0,
          onBell: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GreetingDoodle), findsOneWidget);
    expect(_painter(tester).scene, DoodleScene.sleepyMoon);
    expect(find.text('Chào buổi tối,'), findsOneWidget);
  });
}
