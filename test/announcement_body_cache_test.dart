import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viendongedu2_flutter/components/announcement_body.dart';

void main() {
  testWidgets('rebuilds reuse parsed text and links use the latest callback', (
    tester,
  ) async {
    final opened = <String>[];
    Widget app(String callback) => MaterialApp(
      home: Scaffold(
        body: AnnouncementBody(
          body: '**TEST26** [Test link](https://example.test/test26)',
          openLink: (uri) async {
            opened.add('$callback:$uri');
            return true;
          },
        ),
      ),
    );
    await tester.pumpWidget(app('first'));
    final first = tester
        .widget<SelectableText>(find.byType(SelectableText))
        .textSpan!;
    await tester.pumpWidget(app('latest'));
    final next = tester
        .widget<SelectableText>(find.byType(SelectableText))
        .textSpan!;
    expect(identical(first, next), isTrue);
    final link = next.children!.cast<TextSpan>().firstWhere(
      (span) => span.recognizer != null,
    );
    (link.recognizer! as TapGestureRecognizer).onTap!();
    await tester.pump();
    expect(opened, ['latest:https://example.test/test26']);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('body and theme changes invalidate formatted text', (
    tester,
  ) async {
    Widget app(Brightness brightness, String body) => MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(body: AnnouncementBody(body: body)),
    );
    TextSpan span() =>
        tester.widget<SelectableText>(find.byType(SelectableText)).textSpan!;
    const body = '[blue]**TEST26**[/blue]';
    await tester.pumpWidget(app(Brightness.light, body));
    final light = span();
    await tester.pumpWidget(app(Brightness.dark, body));
    await tester.pumpAndSettle();
    final dark = span();
    expect(dark.toPlainText(), 'TEST26');
    final lightText = light.children!.cast<TextSpan>().firstWhere(
      (s) => s.text == 'TEST26',
    );
    final darkText = dark.children!.cast<TextSpan>().firstWhere(
      (s) => s.text == 'TEST26',
    );
    expect(darkText.style!.fontWeight, FontWeight.bold);
    expect(darkText.style!.color, isNot(lightText.style!.color));
    await tester.pumpWidget(app(Brightness.dark, 'TEST26 updated'));
    expect(span().toPlainText(), 'TEST26 updated');
    expect(tester.takeException(), isNull);
  });
}
