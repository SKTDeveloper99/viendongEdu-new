import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viendongedu2_flutter/features/teacher_conversations/widgets/message_composer.dart';
import 'package:viendongedu2_flutter/models/crm_identity.dart';
import 'package:viendongedu2_flutter/screens/profile_edit_screen.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSession.instance.emsToken = 'test-token';
  });
  tearDown(() {
    EmsApiService.client.close();
    EmsApiService.client = http.Client();
    AppSession.instance.emsToken = null;
    AppSession.instance.role = null;
  });

  for (final role in [CrmRole.student, CrmRole.teacher]) {
    testWidgets('$role profile loads once and ignores a late response', (
      tester,
    ) async {
      AppSession.instance.role = role;
      final response = Completer<http.Response>();
      var calls = 0;
      EmsApiService.client = MockClient((request) {
        expect(request.url.path, endsWith('/${role.name}/me'));
        calls++;
        return response.future;
      });
      Widget app(Brightness brightness) => MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: const ProfileEditScreen(),
      );

      await tester.pumpWidget(app(Brightness.light));
      await tester.pump();
      await tester.pumpWidget(app(Brightness.dark));
      await tester.pump();
      expect(calls, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      response.complete(
        http.Response(
          jsonEncode({
            role.name: {'email': 'test26@example.test'},
          }),
          200,
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(calls, 1);
    });

    testWidgets('$role profile controllers are disposed on close', (
      tester,
    ) async {
      AppSession.instance.role = role;
      EmsApiService.client = MockClient(
        (_) async => http.Response(
          jsonEncode({
            role.name: {'email': 'test26@example.test'},
          }),
          200,
        ),
      );
      await tester.pumpWidget(const MaterialApp(home: ProfileEditScreen()));
      await tester.pumpAndSettle();
      final controllers = tester
          .widgetList<TextFormField>(find.byType(TextFormField))
          .map((field) => field.controller!)
          .toList();
      expect(controllers, isNotEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      for (final controller in controllers) {
        expect(() => controller.addListener(() {}), throwsFlutterError);
      }
    });
  }

  testWidgets('successful send after composer closes ignores disposed draft', (
    tester,
  ) async {
    final sent = Completer<bool>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageComposer(
            sending: false,
            onSend: (text) {
              expect(text, 'TEST26 message');
              return sent.future;
            },
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'TEST26 message');
    final controller = tester
        .widget<TextField>(find.byType(TextField))
        .controller!;
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpWidget(const SizedBox.shrink());
    expect(() => controller.addListener(() {}), throwsFlutterError);
    sent.complete(true);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(controller.text, 'TEST26 message');
  });
}
