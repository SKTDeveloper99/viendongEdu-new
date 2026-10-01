// Characterization of the teacher attendance screen, written against the
// pre-refactor code and kept unchanged across the move (refactor 7/7).
// Fictional TEST26… students only.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viendongedu2_flutter/models/crm_identity.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/features/teacher_attendance/teacher_attendance_screen.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';
import 'package:viendongedu2_flutter/services/ems_attendance_cache.dart';

const _key = '123:18-00:2026-09-08';
const _a = 'TEST260001';
const _b = 'TEST260002';

http.Response _json(Object body, [int code = 200]) => http.Response(
  jsonEncode(body),
  code,
  headers: {'content-type': 'application/json'},
);

http.Response _ok(int saved) => _json({
  'saved': saved,
  'inserted': saved,
  'updated': 0,
  'late': false,
  'overridden_punches': [],
});

http.Response _conflict() => _json({
  'error': '1 học viên đã quẹt cổng nhưng bị ghi vắng — cần nêu lý do.',
  'code': 'punch_conflict_needs_reason',
  'students': [
    {'mssv': _a, 'punched_at': '2026-09-08T17:42:00+07:00'},
  ],
}, 422);

/// [roster] returns the students on every GET /roster; [onPost] answers
/// POST /marks and may mutate what [roster] returns next.
MockClient _mock({
  required List<Map<String, dynamic>> Function() roster,
  required http.Response Function(Map<String, dynamic> body) onPost,
  required List<Map<String, dynamic>> posts,
  List<String>? log,
}) {
  return MockClient((request) async {
    final p = request.url.path;
    if (p.endsWith('/attendance/my-sessions')) {
      return _json({
        'sessions': [
          {
            'section_id': '11111111-1111-1111-1111-111111111111',
            'section_code': 'LOP-THU',
            'subject_name': 'Môn thử nghiệm',
            'session_date': '2026-09-08',
            'start_time': '18:00',
            'end_time': '20:30',
            // Individual tests intentionally use partial rosters to exercise
            // merge/read-back behavior, so skip the independent size guard.
            'roster_size': 0,
            'marked_count': 0,
            'session_key': _key,
          },
        ],
      });
    }
    if (request.method == 'POST' && p.endsWith('/attendance/marks')) {
      log?.add('post');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      posts.add(body);
      return onPost(body);
    }
    if (p.endsWith('/attendance/roster')) {
      log?.add('roster');
      return _json({'session_key': _key, 'students': roster()});
    }
    return http.Response('{}', 404);
  });
}

Future<void> _open(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(home: EmsAttendanceTeacherScreen()),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Môn thử nghiệm'));
  await tester.pumpAndSettle();
}

Map<String, dynamic> _st(String mssv, String? status, {bool scanned = false}) =>
    {
      'mssv': mssv,
      'full_name': 'Học viên $mssv',
      'status': status,
      if (scanned) 'scanned': true,
      if (scanned) 'scanned_at': '2026-09-08T17:42:00+07:00',
      if (scanned) 'punch_id': 77,
    };

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSession.instance.emsToken = 'test-token';
    AppSession.instance.role = CrmRole.teacher;
    AppSession.instance.teacherId = 'teacher-1';
  });
  tearDown(() {
    EmsApiService.client = http.Client();
    AppSession.instance.emsToken = null;
    AppSession.instance.role = null;
    AppSession.instance.teacherId = null;
  });

  group('invariant 1: draft/server merge on load', () {
    testWidgets('clean merge keeps the intended mark and the queue', (
      tester,
    ) async {
      await EmsAttendanceCache.saveDraft(
        _key,
        {_a: 'present', _b: 'absent'},
        {_b: 'ốm'},
        queued: true,
        students: const [
          EmsRosterStudent(mssv: _a, fullName: 'Học viên A'),
          EmsRosterStudent(mssv: _b, fullName: 'Học viên B'),
        ],
      );
      final posts = <Map<String, dynamic>>[];
      EmsApiService.client = _mock(
        posts: posts,
        roster: () => [_st(_a, null), _st(_b, null)],
        onPost: (_) => _ok(2),
      );
      await _open(tester);
      expect(find.textContaining('Tự gửi đã dừng'), findsNothing);
      expect(find.textContaining('CHƯA GỬI • kết nối lại'), findsOneWidget);
      expect(
        find.textContaining(
          'Có 1 • Trễ 0 • Phép 0 • Vắng 1 • Chưa điểm danh 0',
        ),
        findsOneWidget,
      );
      expect(posts, isEmpty, reason: 'no automatic resend');
      final d = await EmsAttendanceCache.loadDraft(_key);
      expect(d?.queued, isTrue);
      expect(d?.marks, {_a: 'present', _b: 'absent'});
      expect(d?.notes, {_b: 'ốm'});
    });

    testWidgets('student gone from roster is a conflict; draft kept unqueued', (
      tester,
    ) async {
      await EmsAttendanceCache.saveDraft(
        _key,
        {_a: 'present', _b: 'present'},
        const {},
        queued: true,
        students: const [
          EmsRosterStudent(mssv: _a, fullName: 'Học viên A'),
          EmsRosterStudent(mssv: _b, fullName: 'Học viên B'),
        ],
      );
      final posts = <Map<String, dynamic>>[];
      EmsApiService.client = _mock(
        posts: posts,
        roster: () => [_st(_a, null)],
        onPost: (_) => _ok(1),
      );
      await _open(tester);
      expect(find.textContaining('Tự gửi đã dừng'), findsOneWidget);
      expect(find.textContaining('CHƯA GỬI • kết nối lại'), findsNothing);
      final d = await EmsAttendanceCache.loadDraft(_key);
      expect(d?.queued, isFalse);
      expect(d?.marks, {_a: 'present', _b: 'present'}, reason: 'draft kept');
      expect(d?.students.length, 2);
    });
  });

  group('invariant 3: save proves every row by read-back', () {
    testWidgets('read-back mismatch keeps the draft queued', (tester) async {
      final posts = <Map<String, dynamic>>[];
      EmsApiService.client = _mock(
        posts: posts,
        roster: () => [_st(_a, null)], // server never stores it
        onPost: (_) => _ok(1),
      );
      await _open(tester);
      await tester.tap(find.text('Có').first);
      await tester.pump();
      await tester.tap(find.text('Lưu điểm danh'));
      await tester.pumpAndSettle();
      expect(posts, hasLength(1));
      expect(
        find.textContaining(
          'CHƯA GỬI. Đã giữ trên máy, sẽ tự gửi khi có mạng. '
          'Máy chủ chưa xác nhận đủ 1 học viên',
        ),
        findsOneWidget,
      );
      final d = await EmsAttendanceCache.loadDraft(_key);
      expect(d?.queued, isTrue);
      expect(d?.marks, {_a: 'present'});
    });

    testWidgets('draft persisted before send; cleared after proof', (
      tester,
    ) async {
      final posts = <Map<String, dynamic>>[];
      final log = <String>[];
      String? status;
      EmsAttendanceDraft? atSend;
      EmsApiService.client = _mock(
        posts: posts,
        log: log,
        roster: () => [_st(_a, status)],
        onPost: (body) {
          status = (body['marks'] as List).single['status'] as String;
          return _ok(1);
        },
      );
      await _open(tester);
      await tester.tap(find.text('Có').first);
      await tester.pump();
      // Every mark change persists the draft at once (invariant 2).
      await tester.runAsync(() async {
        atSend = await EmsAttendanceCache.loadDraft(_key);
      });
      expect(atSend?.marks, {_a: 'present'});
      log.clear();
      await tester.tap(find.text('Lưu điểm danh'));
      await tester.pumpAndSettle();
      expect(log, ['post', 'roster'], reason: 'save then read-back');
      expect(find.text('Đã lưu 1 dòng'), findsOneWidget);
      expect(await EmsAttendanceCache.loadDraft(_key), isNull);
      expect(find.textContaining('CHƯA GỬI'), findsNothing);
    });
  });

  testWidgets('invariant 4: second punch conflict holds, never loops', (
    tester,
  ) async {
    final posts = <Map<String, dynamic>>[];
    EmsApiService.client = _mock(
      posts: posts,
      roster: () => [_st(_a, null, scanned: true)],
      onPost: (_) => _conflict(),
    );
    await _open(tester);
    await tester.tap(find.text('Vắng').first);
    await tester.pump();
    await tester.tap(find.text('Lưu điểm danh'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Cần nêu lý do'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'không vào lớp');
    await tester.pump();
    await tester.tap(find.text('Lưu kèm lý do'));
    await tester.pumpAndSettle();
    expect(posts, hasLength(2), reason: 'resend exactly once');
    expect((posts.last['marks'] as List).single['note'], 'không vào lớp');
    expect(find.text('Cần nêu lý do'), findsNothing);
    expect(find.textContaining('CHƯA LƯU • 1 SV quẹt cổng'), findsOneWidget);
    await tester.pump(const Duration(seconds: 65));
    await tester.pumpAndSettle();
    expect(posts, hasLength(2));
    final d = await EmsAttendanceCache.loadDraft(_key);
    expect(d?.queued, isFalse);
    expect(d?.notes, {_a: 'không vào lớp'});
  });

  group('invariant 5: refusal vs network', () {
    Future<EmsAttendanceDraft?> saveWith(
      WidgetTester tester,
      http.Response Function() answer,
      String toast,
    ) async {
      final posts = <Map<String, dynamic>>[];
      EmsApiService.client = _mock(
        posts: posts,
        roster: () => [_st(_a, null)],
        onPost: (_) => answer(),
      );
      await _open(tester);
      await tester.tap(find.text('Có').first);
      await tester.pump();
      await tester.tap(find.text('Lưu điểm danh'));
      await tester.pumpAndSettle();
      expect(posts, hasLength(1));
      expect(find.text(toast), findsOneWidget);
      await tester.pump(const Duration(seconds: 65));
      await tester.pumpAndSettle();
      expect(posts, hasLength(1), reason: 'no automatic resend');
      return EmsAttendanceCache.loadDraft(_key);
    }

    testWidgets('4xx is a refusal: unqueued', (tester) async {
      final d = await saveWith(
        tester,
        () => _json({'error': 'Buổi học đã chốt'}, 400),
        'Máy chủ từ chối: Buổi học đã chốt',
      );
      expect(d?.queued, isFalse);
      expect(d?.marks, {_a: 'present'});
    });

    testWidgets('5xx keeps the draft queued', (tester) async {
      final d = await saveWith(
        tester,
        () => _json({'error': 'Lỗi máy chủ'}, 500),
        'CHƯA GỬI. Đã giữ trên máy, sẽ tự gửi khi có mạng. '
        'Lỗi máy chủ',
      );
      expect(d?.queued, isTrue);
    });

    testWidgets('network failure keeps the draft queued', (tester) async {
      final posts = <Map<String, dynamic>>[];
      EmsApiService.client = _mock(
        posts: posts,
        roster: () => [_st(_a, null)],
        onPost: (_) => throw http.ClientException('offline'),
      );
      await _open(tester);
      await tester.tap(find.text('Có').first);
      await tester.pump();
      await tester.tap(find.text('Lưu điểm danh'));
      await tester.pumpAndSettle();
      expect(find.textContaining('CHƯA GỬI. Đã giữ trên máy'), findsOneWidget);
      expect(find.textContaining('CHƯA GỬI • kết nối lại'), findsOneWidget);
      expect((await EmsAttendanceCache.loadDraft(_key))?.queued, isTrue);
    });
  });
}
