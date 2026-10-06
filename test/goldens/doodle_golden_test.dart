@Tags(['golden'])
library;

// The four header doodles, fully drawn, on the real header gradient in light
// and dark, so a reviewer can SEE them.
//
//   flutter test --update-goldens --tags golden test/goldens/   # regenerate
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viendongedu2_flutter/components/greeting_doodle.dart';
import 'package:viendongedu2_flutter/core/greeting.dart';
import 'package:viendongedu2_flutter/theme/vd_theme.dart';
import 'package:viendongedu2_flutter/theme/vd_tokens.dart';

Widget _sheet() => Builder(
  builder: (context) {
    final t = context.vd;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [t.headerTop, t.headerBottom]),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final s in DoodleScene.values)
            Padding(
              padding: const EdgeInsets.all(8),
              child: CustomPaint(
                size: const Size.square(120),
                painter: DoodlePainter(
                  scene: s,
                  progress: 1,
                  color: t.onHeader.withValues(alpha: 0.85),
                ),
              ),
            ),
        ],
      ),
    );
  },
);

void main() {
  for (final dark in [false, true]) {
    testWidgets('header doodles ${dark ? 'dark' : 'light'}', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dark ? VdTheme.dark() : VdTheme.light(),
          home: Scaffold(body: Center(child: _sheet())),
        ),
      );
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/doodles_${dark ? 'dark' : 'light'}.png'),
      );
    });
  }
}
