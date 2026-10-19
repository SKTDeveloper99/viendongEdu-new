import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viendongedu2_flutter/components/announcement_body.dart';

void main() {
  testWidgets('red deadline and bold formatting wrap on a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: AnnouncementBody(
      body: 'Kính chào PH em Học Viên Hư Cấu\n[red]**16g00 ngày 20/10/2026**[/red]',
    ))));
    final text = tester.widget<SelectableText>(find.byType(SelectableText));
    final spans = text.textSpan!.children!.cast<TextSpan>();
    final deadline = spans.firstWhere((s) => s.text == '16g00 ngày 20/10/2026');
    expect(deadline.style!.color, const Color(0xFFDC2626));
    expect(deadline.style!.fontWeight, FontWeight.bold);
    expect(text.textSpan!.toPlainText(), isNot(contains('[red]')));
    expect(tester.takeException(), isNull);
  });
  testWidgets('Zalo link launches its exact URL; HTML stays literal', (tester) async {
    Uri? opened;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AnnouncementBody(
      body: 'https://zalo.me/g/example). <script>example</script>',
      openLink: (uri) async { opened = uri; return true; },
    ))));
    final text = tester.widget<SelectableText>(find.byType(SelectableText));
    final spans = text.textSpan!.children!.cast<TextSpan>();
    final link = spans.firstWhere((s) => s.recognizer != null);
    (link.recognizer! as TapGestureRecognizer).onTap!();
    await tester.pump();
    expect(opened.toString(), 'https://zalo.me/g/example');
    expect(text.textSpan!.toPlainText(), contains('<script>example</script>'));
  });
  test('list summary removes formatting while retaining message and URL', () {
    expect(AnnouncementBody.plainText('[red]**Hạn chót**[/red] https://zalo.me/g/example'),
      'Hạn chót https://zalo.me/g/example');
  });
  testWidgets('any colour, italic, underline, strike, highlight and labelled link', (tester) async {
    Uri? opened;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AnnouncementBody(
      body: '[blue]*nghiêng*[/blue] [color=#0a0]__gạch__[/color] ~~cũ~~ ==mới== '
          '[color=url(x)]lạ[/color] [Nhóm **Zalo**](https://zalo.me/g/x) 5 * 3',
      openLink: (uri) async { opened = uri; return true; },
    ))));
    final text = tester.widget<SelectableText>(find.byType(SelectableText));
    final spans = text.textSpan!.children!.cast<TextSpan>();
    TextSpan span(String t) => spans.firstWhere((s) => s.text == t);
    expect(span('nghiêng').style!.fontStyle, FontStyle.italic);
    expect(span('nghiêng').style!.color, const Color(0xFF2563EB));
    expect(span('gạch').style!.color, const Color(0xFF00AA00));
    expect(span('gạch').style!.decoration, TextDecoration.underline);
    expect(span('cũ').style!.decoration, TextDecoration.lineThrough);
    expect(span('mới').style!.backgroundColor, isNotNull);
    expect(span('lạ').style!.color, isNull);
    (span('Nhóm Zalo').recognizer! as TapGestureRecognizer).onTap!();
    await tester.pump();
    expect(opened.toString(), 'https://zalo.me/g/x');
    expect(text.textSpan!.toPlainText(), endsWith(' 5 * 3'));
  });
  test('summary strips every marker but keeps a plain URL', () {
    expect(AnnouncementBody.plainText('[green]**Hạn**[/green] *nộp* __đơn__ ~~cũ~~ ==ngay== [Nhóm](https://zalo.me/g/x) https://a.vn/a__b__'),
      'Hạn nộp đơn cũ ngay Nhóm https://a.vn/a__b__');
  });
}
