import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viendongedu2_flutter/components/announcement_body.dart';
import 'package:viendongedu2_flutter/theme/announcement_palette.dart';

void main() {
  const named = {
    'red': (Color(0xFFDC2626), Color(0xFFF87171)),
    'blue': (Color(0xFF2563EB), Color(0xFF60A5FA)),
    'green': (Color(0xFF16A34A), Color(0xFF4ADE80)),
    'orange': (Color(0xFFEA580C), Color(0xFFFB923C)),
    'purple': (Color(0xFF9333EA), Color(0xFFC084FC)),
    'pink': (Color(0xFFDB2777), Color(0xFFF472B6)),
    'gray': (Color(0xFF6B7280), Color(0xFF9CA3AF)),
  };

  for (final brightness in Brightness.values) {
    final dark = brightness == Brightness.dark;

    test('named announcement colours preserve the $brightness palette', () {
      for (final entry in named.entries) {
        final expected = dark ? entry.value.$2 : entry.value.$1;
        expect(AnnouncementPalette.parse(entry.key, brightness), expected);
        expect(
          AnnouncementPalette.parse(
            '  ${entry.key.toUpperCase()}  ',
            brightness,
          ),
          expected,
        );
      }
    });

    test('short and full hex colours stay opaque in $brightness', () {
      for (final value in ['#0aF', '#00aaff', '  #00AAFF  ']) {
        expect(
          AnnouncementPalette.parse(value, brightness),
          const Color(0xFF00AAFF),
        );
      }
      expect(
        AnnouncementPalette.parse('#000', brightness),
        const Color(0xFF000000),
      );
      expect(
        AnnouncementPalette.parse('#fff', brightness),
        const Color(0xFFFFFFFF),
      );
    });

    test('invalid colours defer to the default style in $brightness', () {
      for (final value in [
        '',
        ' ',
        'unknown',
        'url(x)',
        'rgb(0,0,0)',
        'transparent',
        '00aaff',
        '#12',
        '#1234',
        '#12345',
        '#1234567',
        '#ff00aaff',
        '#ggg',
        '#0 a',
        '#123456 trailing',
      ]) {
        expect(
          AnnouncementPalette.parse(value, brightness),
          isNull,
          reason: value,
        );
      }
    });

    testWidgets('announcement styles and fallback render in $brightness', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: const Scaffold(
            body: AnnouncementBody(
              body:
                  '[color=invalid]default[/color] '
                  '[red][color=invalid]inherited[/color][/red] '
                  '[color=#0aF]**hex**[/color] '
                  '*italic* __underline__ ~~strike~~ ==highlight== '
                  '[Label](https://example.com/announcement)',
            ),
          ),
        ),
      );
      final text = tester.widget<SelectableText>(find.byType(SelectableText));
      final spans = text.textSpan!.children!.cast<TextSpan>();
      TextSpan span(String value) => spans.firstWhere((s) => s.text == value);

      expect(span('default').style!.color, isNull);
      expect(
        span('inherited').style!.color,
        dark ? named['red']!.$2 : named['red']!.$1,
      );
      expect(span('hex').style!.color, const Color(0xFF00AAFF));
      expect(span('hex').style!.fontWeight, FontWeight.bold);
      expect(span('italic').style!.fontStyle, FontStyle.italic);
      expect(span('underline').style!.decoration, TextDecoration.underline);
      expect(span('strike').style!.decoration, TextDecoration.lineThrough);
      expect(
        span('highlight').style!.backgroundColor,
        dark ? const Color(0x66CA8A04) : const Color(0xFFFEF08A),
      );
      expect(
        span('Label').style!.color,
        dark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
      );
      expect(span('Label').style!.decoration, TextDecoration.underline);
      expect(span('Label').recognizer, isNotNull);
      expect(
        text.textSpan!.toPlainText(),
        'default inherited hex italic underline strike highlight Label',
      );
      expect(tester.takeException(), isNull);
    });
  }
}
