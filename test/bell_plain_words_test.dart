// The bell list shows a Nhóm post's words, not the web editor's HTML.
//
//   flutter test test/bell_plain_words_test.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:viendongedu2_flutter/features/bell/bell_screen.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';
import 'package:viendongedu2_flutter/theme/vd_theme.dart';

void main() {
  tearDown(() {
    EmsApiService.client = http.Client();
    AppSession.instance.emsToken = null;
  });

  testWidgets('a rich Nhóm post reads as plain words in Thông báo', (t) async {
    AppSession.instance.emsToken = 'tok';
    EmsApiService.client = MockClient((req) async {
      final body = req.url.path.endsWith('/v1/notifications')
          ? {
              'notifications': [
                {
                  'id': 'n1',
                  'kind': 'work',
                  'title': 'Quản trị Thử đăng trong nhóm',
                  'body': '<!--task-rich-v1--><p><b>Họp tổ bộ môn</b> lúc 14:00</p><ul><li>Mang sổ điểm</li></ul>',
                  'created_at': '2026-11-20T10:00:00Z',
                  'payload': {'space_id': 's1'},
                },
              ],
            }
          : <String, dynamic>{};
      return http.Response.bytes(
        utf8.encode(jsonEncode(body)),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    await t.pumpWidget(
      MaterialApp(theme: VdTheme.light(), home: const BellScreen()),
    );
    await t.pumpAndSettle();
    expect(find.textContaining('Họp tổ bộ môn lúc 14:00'), findsOneWidget);
    expect(find.textContaining('• Mang sổ điểm'), findsOneWidget);
    expect(find.textContaining('<'), findsNothing);
  });
}
