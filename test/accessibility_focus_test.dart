import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viendongedu2_flutter/components/vd_nav_item.dart';
import 'package:viendongedu2_flutter/features/student_home/widgets/home_bottom_nav.dart';
import 'package:viendongedu2_flutter/screens/login_screen.dart';
import 'package:viendongedu2_flutter/theme/vd_theme.dart';

String? _focusedNavigationLabel() {
  String? label;
  FocusManager.instance.primaryFocus?.context?.visitAncestorElements((element) {
    final widget = element.widget;
    if (widget is VdNavItem) {
      label = widget.label;
      return false;
    }
    if (widget is Semantics && widget.properties.label == 'Mã QR cá nhân') {
      label = widget.properties.label;
      return false;
    }
    return true;
  });
  return label;
}

void main() {
  testWidgets(
    'student navigation follows visual order for keyboard and reader',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: VdTheme.light(),
          home: Scaffold(
            bottomNavigationBar: HomeBottomNav(
              currentIndex: 0,
              onSelect: (_) {},
            ),
          ),
        ),
      );
      for (final label in ['Trang chủ', 'Mã QR cá nhân', 'Cá nhân']) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(_focusedNavigationLabel(), label);
      }
      final home = tester.getSemantics(find.bySemanticsLabel('Trang chủ'));
      final qr = tester.getSemantics(find.bySemanticsLabel('Mã QR cá nhân'));
      final profile = tester.getSemantics(find.bySemanticsLabel('Cá nhân'));
      expect((home.sortKey! as OrdinalSortKey).order, 0);
      expect((qr.sortKey! as OrdinalSortKey).order, 1);
      expect((profile.sortKey! as OrdinalSortKey).order, 2);
      semantics.dispose();
    },
  );

  testWidgets('login next action moves from identity to password', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: VdTheme.light(), home: const LoginScreen()),
    );
    final fields = find.byType(EditableText);
    await tester.tap(fields.first);
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    expect(tester.widget<EditableText>(fields.last).focusNode.hasFocus, isTrue);
    expect(
      tester.widget<EditableText>(fields.first).focusNode.hasFocus,
      isFalse,
    );
  });
}
