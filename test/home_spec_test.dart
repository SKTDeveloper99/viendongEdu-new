// Server-led home (proposed P-50, server lib/app-home.js): what the app takes
// from `home` in /auth/app/me, what it drops, and that it falls back to the
// built-in home whenever the server sends nothing usable.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viendongedu2_flutter/core/crm_web/crm_web_target.dart';
import 'package:viendongedu2_flutter/features/work_home/home_prefs.dart';
import 'package:viendongedu2_flutter/features/work_home/home_spec.dart';
import 'package:viendongedu2_flutter/features/work_home/work_home_screen.dart';
import 'package:viendongedu2_flutter/models/crm_identity.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';
import 'package:viendongedu2_flutter/theme/vd_theme.dart';

Map<String, dynamic> _home(List<Map<String, dynamic>> tiles) => {
  'v': 1,
  'tiles': tiles,
  'pages': {
    'them': {
      'title': 'Thêm',
      'rows': [
        {'label': 'Viva', 'sub': 'Mọi trang Viva còn lại', 'open': 'web:/viva'},
      ],
    },
  },
  'words': {'create': 'Tạo mới'},
};

void main() {
  group('parse', () {
    test('nothing usable = null (the built-in home)', () {
      for (final raw in <Object?>[
        null,
        'x',
        <String, dynamic>{},
        {'v': 2, 'tiles': []},
        {'v': 1, 'tiles': []},
        {
          'v': 1,
          'tiles': [
            {'id': 'x', 'label': 'Lạ', 'open': 'app:rocket'},
          ],
        },
      ]) {
        expect(HomeSpec.parse(raw, teacher: true), isNull, reason: '$raw');
      }
    });

    test('keeps what this build knows, in order; drops the rest', () {
      final s = HomeSpec.parse(
        _home([
          {
            'id': 'nhom',
            'label': 'Nhóm',
            'icon': 'groups',
            'open': 'web:/nhom',
          },
          {'id': 'viec', 'label': 'Việc', 'open': 'app:viec', 'badge': 'work'},
          {'id': 'lop', 'label': 'Lớp', 'open': 'app:lop'},
          {'id': 'bad', 'label': 'Ngoài', 'open': 'web:https://evil.test/'},
          {'id': 'dots', 'label': 'Lùi', 'open': 'web:/a/../admin'},
          {'id': 'dbl', 'label': 'Hai', 'open': 'web://evil.test'},
          {'id': 'q', 'label': 'Hỏi', 'open': 'web:/tasks?next=/admin'},
          {'id': 'BAD', 'label': 'Tên', 'open': 'app:lich'},
          {'id': 'nhom', 'label': 'Trùng', 'open': 'app:nhom'},
          {'id': 'dai', 'label': 'x' * 25, 'open': 'app:lich'},
          {'id': 'ho_so', 'label': 'Hồ sơ', 'open': 'web:/ho-so'},
        ]),
        teacher: false,
      )!;
      expect(s.tiles.map((t) => t.id), ['nhom', 'viec', 'ho_so']);
      expect(s.tiles[0].open, const WebOpen('/nhom'));
      expect(s.tiles[1].open, const AppOpen('viec'));
      expect(s.tiles[1].badge, 'work');
      expect(s.pages['them']!.rows.single.sub, 'Mọi trang Viva còn lại');
      expect(s.word('create', 'Tạo'), 'Tạo mới');
      expect(s.word('give_work', 'Giao việc'), 'Giao việc');
      // A teacher keeps Lớp.
      expect(
        HomeSpec.parse(
          _home([
            {'id': 'lop', 'label': 'Lớp', 'open': 'app:lop'},
          ]),
          teacher: true,
        )!.tiles.single.id,
        'lop',
      );
    });

    test('web paths: one strict shape, same as the server', () {
      for (final ok in ['/tasks', '/ho-so', '/a/b_c/D-9']) {
        expect(HomeOpen.webPathOk(ok), isTrue, reason: ok);
        expect(CrmTarget.page(ok), isNotNull, reason: ok);
      }
      for (final bad in [
        'tasks',
        '//evil.test',
        '/a//b',
        '/a/../b',
        '/a\\b',
        '/a b',
        '/a?x=1',
        '/a#x',
        'https://x/y',
        '/a%2e%2e',
        '/a\u0000',
        '/',
        '/a/b/c/d/e',
      ]) {
        expect(HomeOpen.webPathOk(bad), isFalse, reason: bad);
        expect(CrmTarget.page(bad), isNull, reason: bad);
      }
      // The fixed seven keep their own targets; others carry the home's title.
      expect(CrmTarget.page('/tasks')!.relative, '/tasks');
      expect(CrmTarget.page('/tasks', label: 'Việc')!.title, 'Việc');
      final p = CrmTarget.page('/ho-so', label: 'Hồ sơ')!;
      expect(p.routeName, '/crm/ho-so');
      expect(p.title, 'Hồ sơ');
      expect(CrmTarget.fromRouteName('/crm/ho-so')!.title, 'Viva');
      expect(CrmTarget.fromRouteName('/crm/admin-access.html'), isNull);
    });

    test('the phone copy is only for the same account', () {
      final s = HomeSpec.parse(
        _home([
          {'id': 'viec', 'label': 'Việc', 'open': 'app:viec'},
        ]),
        teacher: false,
      )!;
      final stored = s.toCache('u1');
      expect(
        HomeSpec.fromCache(stored, userId: 'u1', teacher: false),
        isNotNull,
      );
      expect(HomeSpec.fromCache(stored, userId: 'u2', teacher: false), isNull);
      expect(HomeSpec.fromCache('{bad', userId: 'u1', teacher: false), isNull);
      expect(HomeSpec.fromCache(null, userId: 'u1', teacher: false), isNull);
    });
  });

  group('home screen', () {
    late Map<String, dynamic> me;
    final pushed = <String>[];

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      pushed.clear();
      EmsApiService.client = MockClient((req) async {
        final body = req.url.path.endsWith('/auth/app/me') ? me : {'data': []};
        return http.Response.bytes(
          utf8.encode(jsonEncode(body)),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      AppSession.instance
        ..emsToken = 'tok'
        ..role = CrmRole.staff
        ..userId = 'u1'
        ..isStaff = true;
    });

    Future<void> pump(WidgetTester t) async {
      await t.pumpWidget(
        MaterialApp(
          theme: VdTheme.light(),
          home: const WorkHomeScreen(),
          onGenerateRoute: (s) {
            pushed.add('${s.name}|${s.arguments}');
            return MaterialPageRoute<void>(
              settings: s,
              builder: (_) => const Scaffold(body: Text('trang')),
            );
          },
        ),
      );
      await t.pump(const Duration(milliseconds: 50));
    }

    Future<void> done(WidgetTester t) async {
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    }

    testWidgets('no home from the server: the built-in tiles', (t) async {
      me = {
        'counts': {},
        'can': {},
        'kinds': ['staff'],
      };
      await pump(t);
      for (final l in ['Việc', 'Nhóm', 'Lịch', 'Văn phòng', 'Thêm']) {
        expect(find.text(l), findsWidgets, reason: l);
      }
      expect(await HomePrefs.homeSpec(), isNull);
      await done(t);
    });

    testWidgets('home from the server: its tiles and words; Việc as a Viva '
        'page; kept for the next start', (t) async {
      me = {
        'counts': {},
        'can': {'give_work': true},
        'kinds': ['staff'],
        'home': _home([
          {
            'id': 'viec',
            'label': 'Việc',
            'open': 'web:/tasks',
            'badge': 'work',
          },
          {'id': 'nhom', 'label': 'Nhóm ơi', 'open': 'web:/nhom'},
          {'id': 'them', 'label': 'Thêm', 'open': 'app:them'},
        ]),
      };
      await pump(t);
      expect(find.text('Nhóm ơi'), findsOneWidget);
      expect(find.text('Lịch'), findsNothing);
      expect(find.text('Tạo mới'), findsOneWidget);
      await t.tap(find.text('Việc'));
      await t.pump(const Duration(milliseconds: 50));
      expect(pushed.last, '/crm/tasks|Việc');
      expect(await HomePrefs.homeSpec(), contains('"user":"u1"'));
      await done(t);
    });

    testWidgets('the server drops home again: back to the built-in tiles', (
      t,
    ) async {
      SharedPreferences.setMockInitialValues({
        'work_home.home_spec': jsonEncode({
          'user': 'u1',
          'home': _home([
            {'id': 'nhom', 'label': 'Nhóm ơi', 'open': 'web:/nhom'},
          ]),
        }),
      });
      me = {
        'counts': {},
        'can': {},
        'kinds': ['staff'],
        'home': null,
      };
      await pump(t);
      expect(find.text('Nhóm ơi'), findsNothing);
      expect(find.text('Lịch'), findsOneWidget);
      expect(await HomePrefs.homeSpec(), isNull);
      await done(t);
    });
  });

  test('Nhóm feed posts show words, never the rich-text marker', () {
    final src = File(
      'lib/features/nhom/nhom_screens_parts_1.dart',
    ).readAsStringSync();
    expect(src.contains("plainDescription(p['body'])"), isTrue);
    expect(src.contains("Text('\${p['body'] ?? ''}'"), isFalse);
  });
}
