// T1 conditions (chief of staff 2026-11-10): each new package behind one
// file, no JavaScript bridge, no file access from URLs, teachers only.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viendongedu2_flutter/core/crm_web/crm_web_target.dart';
import 'package:viendongedu2_flutter/features/crm_web/crm_web_routes.dart';
import 'package:viendongedu2_flutter/features/teacher_home/widgets/menu_grid.dart';
import 'package:viendongedu2_flutter/models/crm_identity.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';

Iterable<File> _lib() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

List<String> _importers(String package) => [
  for (final f in _lib())
    if (f.readAsStringSync().contains("import 'package:$package/"))
      f.path.replaceAll('\\', '/'),
];

void main() {
  test('webview_flutter lives in two files, image_picker in one', () {
    expect(_importers('webview_flutter')..sort(), [
      'lib/features/crm_web/crm_webview_surface.dart',
    ]);
    expect(_importers('webview_flutter_android')..sort(), [
      'lib/features/crm_web/android_photo_picker.dart',
      'lib/features/crm_web/crm_webview_surface.dart',
    ]);
    expect(_importers('image_picker'), [
      'lib/features/crm_web/android_photo_picker.dart',
    ]);
  });

  test('no JavaScript bridge; file and content access off', () {
    for (final f in _lib()) {
      final s = f.readAsStringSync();
      expect(s.contains('addJavaScriptChannel'), isFalse, reason: f.path);
      expect(s.contains('runJavaScript'), isFalse, reason: f.path);
      expect(s.contains('loadFile('), isFalse, reason: f.path);
    }
    final surface = File(
      'lib/features/crm_web/crm_webview_surface.dart',
    ).readAsStringSync();
    expect(surface.contains('setAllowFileAccess(false)'), isTrue);
    expect(surface.contains('setAllowContentAccess(false)'), isTrue);
    expect(surface.contains('crmNavigation('), isTrue);
  });

  group('routes', () {
    tearDown(() => AppSession.instance.role = null);

    test('teachers get allow-listed CRM pages; students and others none', () {
      AppSession.instance.role = CrmRole.teacher;
      expect(
        crmPageRoute(RouteSettings(name: CrmTarget.tasks().routeName)),
        isNotNull,
      );
      expect(
        crmPageRoute(const RouteSettings(name: '/crm/admin.html')),
        isNull,
      );
      AppSession.instance.role = CrmRole.student;
      expect(
        crmPageRoute(RouteSettings(name: CrmTarget.tasks().routeName)),
        isNull,
      );
    });
  });

  testWidgets('teacher home: Việc của tôi and Nhóm open their pages', (
    t,
  ) async {
    final opened = <String>[];
    await t.pumpWidget(
      MaterialApp(
        home: const Scaffold(body: SingleChildScrollView(child: MenuGrid())),
        onGenerateRoute: (s) {
          opened.add(s.name ?? '');
          return MaterialPageRoute<void>(builder: (_) => const Scaffold());
        },
      ),
    );
    await t.tap(find.text('Việc của tôi'));
    await t.pumpAndSettle();
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    await t.tap(find.text('Nhóm'));
    await t.pumpAndSettle();
    expect(opened, ['/crm/tasks', '/crm/nhom']);
  });
}
