import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viendongedu2_flutter/data/teacher_attendance_repository.dart';
import 'package:viendongedu2_flutter/features/teacher_attendance/roster_screen.dart';
import 'package:viendongedu2_flutter/models/crm_identity.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/screens/ems_attendance_student_screen.dart';
import 'package:viendongedu2_flutter/features/teacher_attendance/teacher_attendance_screen.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';
import 'package:viendongedu2_flutter/services/ems_attendance_cache.dart';

/// Mock EMS with a two-student roster. [onPost] decides what POST /marks
/// returns; the roster reflects [status] per mssv after a successful save.
MockClient _teacherMock({
  required http.Response Function(Map<String, dynamic> body) onPost,
  required List<Map<String, dynamic>> Function() students,
  required List<Map<String, dynamic>> posts,
  int rosterSize = 2,
}) {
  return MockClient((request) async {
    if (request.url.path.endsWith('/attendance/my-sessions')) {
      return http.Response(
        jsonEncode({
          'sessions': [
            {
              'section_id': '11111111-1111-1111-1111-111111111111',
              'section_code': 'LOP-THU',
              'subject_name': 'Môn thử nghiệm',
              'session_date': '2026-09-08',
              'start_time': '18:00',
              'end_time': '20:30',
              'roster_size': rosterSize,
              'marked_count': 0,
              'session_key': '123:18-00:2026-09-08',
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (request.method == 'POST' &&
        request.url.path.endsWith('/attendance/marks')) {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      posts.add(body);
      return onPost(body);
    }
    if (request.url.path.endsWith('/attendance/roster')) {
      return http.Response(
        jsonEncode({
          'session_key': '123:18-00:2026-09-08',
          'students': students(),
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.Response('{}', 404);
  });
}

Future<void> _openClass(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(home: EmsAttendanceTeacherScreen()),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Môn thử nghiệm'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSession.instance.emsToken = 'test-token';
    AppSession.instance.role = CrmRole.teacher;
    AppSession.instance.teacherId = 'teacher-1';
    AppSession.instance.mssv = 'student-1';
  });
  tearDown(() {
    EmsApiService.client = http.Client();
    AppSession.instance.emsToken = null;
    AppSession.instance.role = null;
    AppSession.instance.teacherId = null;
    AppSession.instance.mssv = null;
  });

  testWidgets('offline teacher sees no saved roster or session', (
    tester,
  ) async {
    await EmsAttendanceCache.saveTeacherSessions('2026-09-08', const [
      EmsSession(
        sectionId: 'section-1',
        sectionCode: 'OLD-CLASS',
        sessionDate: '2026-09-08',
        sessionKey: 'old-session',
      ),
    ]);
    EmsApiService.client = MockClient(
      (_) async => throw http.ClientException('offline'),
    );
    await tester.pumpWidget(
      const MaterialApp(home: EmsAttendanceTeacherScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Không có kết nối'), findsOneWidget);
    expect(find.text('OLD-CLASS'), findsNothing);
  });

  testWidgets('offline roster shows cached students, marks and banner', (
    tester,
  ) async {
    const session = EmsSession(
      sectionId: 'section-d14',
      sectionCode: 'D14',
      sessionDate: '2026-09-08',
      sessionKey: 'd14:18-00:2026-09-08',
      subjectName: 'Lớp D14',
    );
    await EmsAttendanceCache.saveDraft(
      session.sessionKey,
      const {'2600000001': 'present'},
      const {},
      queued: false,
      students: const [
        EmsRosterStudent(mssv: '2600000001', fullName: 'Nguyễn Văn A'),
      ],
      session: session,
    );
    EmsApiService.client = MockClient(
      (_) async => throw http.ClientException('offline'),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: TeacherRosterScreen(
          repository: TeacherAttendanceRepository(),
          session: session,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nguyễn Văn A'), findsOneWidget);
    expect(
      find.textContaining('Đang ngoại tuyến – danh sách lưu lúc'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Điểm danh sẽ tự gửi khi có mạng.'),
      findsOneWidget,
    );
    expect(find.text('Lưu điểm danh'), findsOneWidget);
  });

  testWidgets(
    'student attendance does not poll and hides saved history offline',
    (tester) async {
      AppSession.instance.role = CrmRole.student;
      await EmsAttendanceCache.saveStudentHistory(const [
        EmsStudentMark(
          sessionDate: '2026-09-08',
          status: 'present',
          subjectName: 'OLD-SUBJECT',
        ),
      ]);
      var requests = 0;
      EmsApiService.client = MockClient((_) async {
        requests++;
        throw http.ClientException('offline');
      });
      await tester.pumpWidget(
        const MaterialApp(home: EmsAttendanceStudentScreen()),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 31));
      expect(requests, 1);
      expect(find.textContaining('Không có kết nối'), findsOneWidget);
      expect(find.text('OLD-SUBJECT'), findsNothing);
    },
  );

  testWidgets(
    'new server mark stops a queued offline mark from overwriting it',
    (tester) async {
      const key = '123:18-00:2026-09-08';
      await EmsAttendanceCache.saveDraft(
        key,
        {'2600000001': 'present'},
        const {},
        queued: true,
        students: const [
          EmsRosterStudent(mssv: '2600000001', fullName: 'Nguyễn Văn A'),
        ],
      );
      final posts = <Map<String, dynamic>>[];
      EmsApiService.client = _teacherMock(
        rosterSize: 1,
        onPost: (body) => http.Response('{}', 200),
        students: () => [
          {
            'mssv': '2600000001',
            'full_name': 'Nguyễn Văn A',
            'status': 'absent',
          },
        ],
        posts: posts,
      );

      await _openClass(tester);
      expect(find.textContaining('Tự gửi đã dừng'), findsOneWidget);
      expect(posts, isEmpty);
      expect((await EmsAttendanceCache.loadDraft(key))?.queued, isFalse);
    },
  );

  testWidgets('student sees pending class and independent gate arrival', (
    tester,
  ) async {
    EmsApiService.client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'marks': [
            {
              'session_key': '123:18-00:2026-09-08',
              'session_date': '2026-09-08',
              'start_time': '18:00',
              'end_time': '20:30',
              'subject_name': 'Môn thử nghiệm',
              'status': null,
              'arrived_at': '2026-09-08T17:42:00+07:00',
              'arrival_on_time': true,
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(home: EmsAttendanceStudentScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Chờ giáo viên xác nhận'), findsOneWidget);
    expect(find.textContaining('Đã vào trường lúc 17:42'), findsOneWidget);
    expect(find.textContaining('trước giờ học'), findsOneWidget);
  });

  testWidgets('teacher save carries punch evidence and waits for read-back', (
    tester,
  ) async {
    var saved = false;
    Map<String, dynamic>? posted;
    EmsApiService.client = MockClient((request) async {
      if (request.url.path.endsWith('/attendance/my-sessions')) {
        return http.Response(
          jsonEncode({
            'sessions': [
              {
                'section_id': '11111111-1111-1111-1111-111111111111',
                'section_code': 'LOP-THU',
                'subject_name': 'Môn thử nghiệm',
                'session_date': '2026-09-08',
                'start_time': '18:00',
                'end_time': '20:30',
                'roster_size': 1,
                'marked_count': saved ? 1 : 0,
                'session_key': '123:18-00:2026-09-08',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.method == 'POST' &&
          request.url.path.endsWith('/attendance/marks')) {
        posted = jsonDecode(request.body) as Map<String, dynamic>;
        saved = true;
        return http.Response(
          jsonEncode({
            'saved': 1,
            'inserted': 1,
            'updated': 0,
            'late': false,
            'overridden_punches': [],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path.endsWith('/attendance/roster')) {
        return http.Response(
          jsonEncode({
            'session_key': '123:18-00:2026-09-08',
            'students': [
              {
                'mssv': '2600000001',
                'full_name': 'Học viên thử nghiệm',
                'status': saved ? 'present' : null,
                'scanned': true,
                'scanned_at': '2026-09-08T17:42:00+07:00',
                'punch_id': 77,
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{}', 404);
    });

    await tester.pumpWidget(
      const MaterialApp(home: EmsAttendanceTeacherScreen()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Môn thử nghiệm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đã quẹt → có mặt (còn 1)'));
    await tester.pump();
    await tester.tap(find.text('Lưu điểm danh'));
    await tester.pumpAndSettle();

    expect(posted, isNotNull);
    final marks = posted!['marks'] as List<dynamic>;
    expect(marks.single['punch_id'], 77);
    expect(marks.single['status'], 'present');
    expect(find.textContaining('Đã lưu 1 dòng'), findsOneWidget);
  });

  // 17/09 Huy 43461: 12 học viên chưa chạm, Lưu vẫn xanh. Lưu phải hỏi trước.
  testWidgets('Lưu with undecided students asks first and never writes them', (
    tester,
  ) async {
    final posts = <Map<String, dynamic>>[];
    final status = <String, String?>{'2600000001': null, '2600000002': null};
    EmsApiService.client = _teacherMock(
      posts: posts,
      students: () => [
        for (final e in status.entries)
          {'mssv': e.key, 'full_name': 'Học viên ${e.key}', 'status': e.value},
      ],
      onPost: (body) {
        for (final m in body['marks'] as List) {
          status[m['mssv'] as String] = m['status'] as String;
        }
        return http.Response(
          jsonEncode({
            'saved': 1,
            'inserted': 1,
            'updated': 0,
            'late': false,
            'overridden_punches': [],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      },
    );
    await _openClass(tester);
    // Tick only the first student present.
    await tester.tap(find.text('Có').first);
    await tester.pump();
    await tester.tap(find.text('Lưu điểm danh'));
    await tester.pumpAndSettle();

    expect(find.text('Còn 1 học viên chưa điểm danh'), findsOneWidget);
    expect(find.textContaining('Học viên 2600000002'), findsWidgets);
    expect(posts, isEmpty, reason: 'nothing sent before the teacher answers');

    await tester.tap(find.text('Quay lại điểm danh'));
    await tester.pumpAndSettle();
    expect(posts, isEmpty);

    await tester.tap(find.text('Lưu điểm danh'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Lưu 1 đã chọn'));
    await tester.pumpAndSettle();

    expect(posts, hasLength(1));
    final marks = posts.single['marks'] as List;
    expect(marks, hasLength(1));
    expect(marks.single['mssv'], '2600000001');
    expect(status['2600000002'], isNull, reason: 'undecided is never absent');
    expect(find.textContaining('Đã lưu 1 dòng'), findsOneWidget);
  });

  // 17/09 Hậu 43194: bốn lần 422 y hệt trong 30 giây vì hàng đợi 20 s gửi lại.
  testWidgets('punch-conflict 422 stops the retry queue until Lưu is tapped', (
    tester,
  ) async {
    final posts = <Map<String, dynamic>>[];
    final status = <String, String?>{'2600000001': null, '2600000002': null};
    EmsApiService.client = _teacherMock(
      posts: posts,
      students: () => [
        {
          'mssv': '2600000001',
          'full_name': 'Học viên quẹt cổng',
          'status': status['2600000001'],
          'scanned': true,
          'scanned_at': '2026-09-08T17:42:00+07:00',
          'punch_id': 77,
        },
        {
          'mssv': '2600000002',
          'full_name': 'Học viên hai',
          'status': status['2600000002'],
        },
      ],
      onPost: (body) {
        final marks = body['marks'] as List;
        final noReason = marks.any(
          (m) =>
              m['status'] == 'absent' &&
              (m['note'] == null || (m['note'] as String).trim().isEmpty),
        );
        if (noReason) {
          return http.Response(
            jsonEncode({
              'error':
                  '1 học viên đã quẹt cổng nhưng bị ghi vắng — cần nêu lý do.',
              'code': 'punch_conflict_needs_reason',
              'students': [
                {
                  'mssv': '2600000001',
                  'punched_at': '2026-09-08T17:42:00+07:00',
                },
              ],
            }),
            422,
            headers: {'content-type': 'application/json'},
          );
        }
        for (final m in marks) {
          status[m['mssv'] as String] = m['status'] as String;
        }
        return http.Response(
          jsonEncode({
            'saved': 2,
            'inserted': 2,
            'updated': 0,
            'late': false,
            'overridden_punches': [77],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      },
    );
    await _openClass(tester);
    // Scanned student marked absent, the other present → no undecided.
    await tester.tap(find.text('Vắng').first);
    await tester.tap(find.text('Có').last);
    await tester.pump();
    await tester.tap(find.text('Lưu điểm danh'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(posts, hasLength(1));
    expect(find.text('Cần nêu lý do'), findsOneWidget);

    // Teacher closes the dialog. The 20 s queue must NOT resend the same body.
    await tester.tap(find.text('Huỷ'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 65));
    await tester.pumpAndSettle();
    expect(posts, hasLength(1), reason: 'no silent identical retries');
    expect(find.textContaining('CHƯA LƯU'), findsWidgets);

    // Lưu again → dialog → reason → save goes through with the note.
    await tester.tap(find.text('Lưu điểm danh'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(posts, hasLength(2));
    await tester.enterText(find.byType(TextField).first, 'không thấy tại lớp');
    await tester.pump();
    await tester.tap(find.text('Lưu kèm lý do'));
    await tester.pumpAndSettle();

    expect(posts, hasLength(3));
    final last = posts.last['marks'] as List;
    final absent = last.firstWhere((m) => m['mssv'] == '2600000001');
    expect(absent['note'], 'không thấy tại lớp');
    await tester.pump(const Duration(seconds: 65));
    await tester.pumpAndSettle();
    expect(posts, hasLength(3), reason: 'queue cleared after success');
  });

  // 18/09 Dũng, lớp 43443: "Quẹt cổng: có mặt (0)" về 0 ngay khi đánh xong;
  // bấm nhầm "Tất cả có mặt" không có đường lui. Tổng đã quẹt / chưa quẹt phải
  // đứng yên; "Bỏ chọn tất cả" trả về đúng người đã quẹt (+ dấu máy chủ đã lưu).
  testWidgets('scan totals stay put; Bỏ chọn tất cả restores scanned + saved', (
    tester,
  ) async {
    final posts = <Map<String, dynamic>>[];
    EmsApiService.client = _teacherMock(
      rosterSize: 3,
      posts: posts,
      students: () => [
        {'mssv': '2600000001', 'full_name': 'Trần Văn An', 'scanned': true},
        {'mssv': '2600000002', 'full_name': 'Lê Thị Bích', 'scanned': false},
        {
          'mssv': '2600000003',
          'full_name': 'Phạm Cường',
          'scanned': false,
          'status': 'absent',
        },
      ],
      onPost: (_) => http.Response('{}', 500),
    );
    await tester.pumpWidget(
      const MaterialApp(home: EmsAttendanceTeacherScreen()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Môn thử nghiệm'));
    await tester.pumpAndSettle();

    expect(find.text('Đã quẹt 1 • Chưa quẹt 2 • Sĩ số 3'), findsOneWidget);
    expect(find.text('Đã quẹt → có mặt (còn 1)'), findsOneWidget);

    await tester.tap(find.text('Đã quẹt → có mặt (còn 1)'));
    await tester.pump();
    // Tổng không đổi; chỉ nút nói "xong".
    expect(find.text('Đã quẹt 1 • Chưa quẹt 2 • Sĩ số 3'), findsOneWidget);
    expect(find.text('Đã quẹt → có mặt (xong)'), findsOneWidget);
    expect(find.textContaining('Có 1 • '), findsOneWidget);

    await tester.tap(find.text('Tất cả có mặt'));
    await tester.pump();
    expect(find.textContaining('Có 3 • '), findsOneWidget);
    expect(find.text('Bỏ chọn tất cả'), findsOneWidget);

    await tester.tap(find.text('Bỏ chọn tất cả'));
    await tester.pump();
    // An (quẹt) có mặt, Cường giữ dấu VẮNG máy chủ đã lưu, Bích về chưa điểm danh.
    expect(
      find.textContaining('Có 1 • Trễ 0 • Phép 0 • Vắng 1 • Chưa điểm danh 1'),
      findsOneWidget,
    );
    expect(find.text('Tất cả có mặt'), findsOneWidget);
    expect(posts, isEmpty, reason: 'chỉ đổi trên máy, chưa gửi gì');
  });

  // 18/09 Dũng: xếp tên A–Z để dò tay. Theo TÊN (chữ cuối), bỏ dấu.
  testWidgets('A–Z sorts by given name without diacritics', (tester) async {
    EmsApiService.client = _teacherMock(
      rosterSize: 4,
      posts: [],
      students: () => [
        {'mssv': '2600000001', 'full_name': 'Nguyễn Thị Lan Phương'},
        {'mssv': '2600000002', 'full_name': 'Huỳnh Thị Mỹ Lộc'},
        {'mssv': '2600000003', 'full_name': 'Ngô Anh Thư'},
        {'mssv': '2600000004', 'full_name': 'Lê Ngọc Ánh'},
      ],
      onPost: (_) => http.Response('{}', 500),
    );
    await tester.pumpWidget(
      const MaterialApp(home: EmsAttendanceTeacherScreen()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Môn thử nghiệm'));
    await tester.pumpAndSettle();

    List<String> order() => tester
        .widgetList<Text>(
          find.byWidgetPredicate(
            (w) =>
                w is Text &&
                const [
                  'Nguyễn Thị Lan Phương',
                  'Huỳnh Thị Mỹ Lộc',
                  'Ngô Anh Thư',
                  'Lê Ngọc Ánh',
                ].contains(w.data),
          ),
        )
        .map((t) => t.data!)
        .toList();

    expect(order(), [
      'Nguyễn Thị Lan Phương',
      'Huỳnh Thị Mỹ Lộc',
      'Ngô Anh Thư',
      'Lê Ngọc Ánh',
    ], reason: 'mặc định giữ thứ tự IMS');

    await tester.tap(find.byIcon(Icons.sort_by_alpha));
    await tester.pump();
    expect(order(), [
      'Lê Ngọc Ánh', // anh
      'Huỳnh Thị Mỹ Lộc', // loc
      'Nguyễn Thị Lan Phương', // phuong
      'Ngô Anh Thư', // thu
    ]);

    await tester.tap(find.byIcon(Icons.sort_by_alpha));
    await tester.pump();
    expect(
      order().first,
      'Nguyễn Thị Lan Phương',
      reason: 'tắt = về thứ tự IMS',
    );
  });
}
