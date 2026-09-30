import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viendongedu2_flutter/components/vd_fade_in.dart';
import 'package:viendongedu2_flutter/theme/vd_motion.dart';

Widget _host(Widget child, {bool disable = false, bool accessible = false}) {
  return MediaQuery(
    data: MediaQueryData(
      disableAnimations: disable,
      accessibleNavigation: accessible,
    ),
    child: Directionality(textDirection: TextDirection.ltr, child: child),
  );
}

void main() {
  testWidgets('VdMotion is zero when animations are disabled', (tester) async {
    late VdMotion m;
    await tester.pumpWidget(_host(
      Builder(builder: (c) {
        m = VdMotion.of(c);
        return const SizedBox();
      }),
      disable: true,
    ));
    expect(m.reduced, isTrue);
    expect(m.standard, Duration.zero);
    expect(m.quick, Duration.zero);
    expect(m.press, Duration.zero);
    expect(m.countUp, Duration.zero);
    expect(m.staggerDelay(5), Duration.zero);
  });

  testWidgets('VdMotion is zero with accessible navigation', (tester) async {
    late VdMotion m;
    await tester.pumpWidget(_host(
      Builder(builder: (c) {
        m = VdMotion.of(c);
        return const SizedBox();
      }),
      accessible: true,
    ));
    expect(m.standard, Duration.zero);
  });

  testWidgets('VdMotion durations stay in 120-600 ms and stagger is capped',
      (tester) async {
    late VdMotion m;
    await tester.pumpWidget(_host(Builder(builder: (c) {
      m = VdMotion.of(c);
      return const SizedBox();
    })));
    expect(m.reduced, isFalse);
    expect(m.quick, const Duration(milliseconds: 150));
    expect(m.staggerDelay(2), const Duration(milliseconds: 60));
    expect(m.staggerDelay(50), const Duration(milliseconds: 240));
  });

  testWidgets('VdFadeIn is fully visible at rest', (tester) async {
    await tester.pumpWidget(
      _host(const VdFadeIn(index: 3, child: Text('xin chào'))),
    );
    await tester.pumpAndSettle();
    final op = tester.widget<Opacity>(find.byType(Opacity));
    expect(op.opacity, 1.0);
    expect(find.text('xin chào'), findsOneWidget);
  });

  testWidgets('VdFadeIn under reduced motion shows content immediately',
      (tester) async {
    await tester.pumpWidget(_host(
      const VdFadeIn(index: 8, child: Text('ngay')),
      disable: true,
    ));
    final op = tester.widget<Opacity>(find.byType(Opacity));
    expect(op.opacity, 1.0);
  });
}
