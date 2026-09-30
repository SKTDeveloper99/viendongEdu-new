import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viendongedu2_flutter/components/app_version_label.dart';

void main() {
  testWidgets('shows the plain name first, then "phiên bản X (build)"', (
    tester,
  ) async {
    final c = Completer<String?>();
    await tester.pumpWidget(
      MaterialApp(home: AppVersionLabel(loadVersion: () => c.future)),
    );
    final h0 = tester.getSize(find.byType(AppVersionLabel)).height;
    expect(find.text('Phần mềm Viendongedu'), findsOneWidget);
    c.complete('6.1.0 (91)');
    await tester.pump();
    expect(
      find.text('Phần mềm Viendongedu phiên bản 6.1.0 (91)'),
      findsOneWidget,
    );
    expect(tester.getSize(find.byType(AppVersionLabel)).height, h0);
  });

  testWidgets('a failing loader leaves the plain name, no crash', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppVersionLabel(loadVersion: () async => throw StateError('x')),
      ),
    );
    await tester.pump();
    expect(find.text('Phần mềm Viendongedu'), findsOneWidget);
  });
}
