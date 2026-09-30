@Tags(['golden'])
library;

// Screenshots of the key screens in VdTheme.light() and VdTheme.dark(), so a
// reviewer can SEE both modes. Fictional data only (TEST26… / THUNGHIEM).
//
//   flutter test --update-goldens --tags golden test/goldens/   # regenerate
//   flutter test --exclude-tags golden                          # skip on CI
//
// Real fonts are loaded (BeVietnamPro + MaterialIcons) so the PNGs are
// readable. Screens that print today's date (schedule, home) differ by a few
// pixels day to day, so comparison allows a small diff ratio.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viendongedu2_flutter/features/class_manager/class_manager_screen.dart';
import 'package:viendongedu2_flutter/features/grades/grades_screen.dart';
import 'package:viendongedu2_flutter/data/student_home_repository.dart';
import 'package:viendongedu2_flutter/data/teacher_home_repository.dart';
import 'package:viendongedu2_flutter/features/student_home/must_read_gate.dart';
import 'package:viendongedu2_flutter/features/student_home/student_home_screen.dart';
import 'package:viendongedu2_flutter/features/student_home/student_home_view_model.dart';
import 'package:viendongedu2_flutter/features/teacher_attendance/teacher_attendance_screen.dart';
import 'package:viendongedu2_flutter/features/teacher_home/teacher_home_screen.dart';
import 'package:viendongedu2_flutter/features/teacher_home/teacher_home_view_model.dart';
import 'package:viendongedu2_flutter/models/crm_identity.dart';
import 'package:viendongedu2_flutter/models/crm_student_schedule.dart';
import 'package:viendongedu2_flutter/screens/login_screen.dart';
import 'package:viendongedu2_flutter/screens/schedule_screen.dart';
import 'package:viendongedu2_flutter/screens/student_board_screen.dart';
import 'package:viendongedu2_flutter/services/app_session.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';
import 'package:viendongedu2_flutter/theme/vd_theme.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

http.Response _ok(Object body) =>
    http.Response(jsonEncode(body), 200, headers: _json);

// ── fixtures (fictional) ────────────────────────────────────────────────────
Map<String, dynamic> _todayClass(String name, String start, String end) => {
  'subject_code': 'TN101',
  'subject_name': name,
  'semester_code': '262',
  'section_code': '06CDTHUNGHIEM-$start',
  'day_code': dayCodeForWeekday(DateTime.now().weekday),
  'start_time': start,
  'end_time': end,
  'room_name': 'P.101',
  'teacher_name': 'GV Thử Nghiệm',
};

Map<String, dynamic> _grade(
  int id,
  String sem,
  String code,
  String name,
  int credits,
  double? score,
) => {
  'grade_id': id,
  'semester_code': sem,
  'class_code': '06CD15THUNGHIEM',
  'final_score': score,
  'recorded_at': '2026-0${id + 1}-01T00:00:00.000Z',
  'subject_code': code,
  'subject_name': name,
  'credits': credits,
  'teacher_name': 'GV Thử Nghiệm',
};

Map<String, dynamic> _boardItem(
  String id,
  String title,
  String category,
  bool mustRead,
  String? readAt,
) => {
  'id': id,
  'title': title,
  'body': 'Nội dung thử nghiệm cho thông báo này.',
  'category': category,
  'must_read': mustRead,
  'is_correction': false,
  'published_at': '2026-09-01T13:05:35.805Z',
  'read_at': readAt,
  'acknowledged_at': null,
};

Map<String, dynamic> _cmClass(
  String id,
  String code,
  String subj,
  String name,
  int credits,
  int enrolled,
  String sem,
) => {
  'section_id': id,
  'section_code': code,
  'semester_code': sem,
  'room': 'P.101',
  'ngay_bat_dau': '2026-02-16T00:00:00.000Z',
  'ngay_ket_thuc': '2026-06-20T00:00:00.000Z',
  'ngay_thi': '2026-06-28T00:00:00.000Z',
  'subject_code': subj,
  'subject_name': name,
  'credits': credits,
  'enrolled_students': enrolled,
};

Map<String, dynamic> _slot(String name, String start, String end) => {
  'lmhid': '9001',
  'lmhma': '06CDTHUNGHIEM-$start',
  'mhten': name,
  'phongten': 'P.101',
  'thoigianbd': start,
  'thoigiankt': '2026-09-30T$end:00',
};

const _rosterKey = '123:18-00:2026-09-08';

http.Response _route(http.Request req) {
  final p = req.url.path;
  if (p.endsWith('/student/me/schedule')) {
    return _ok({
      'schedule': [
        _todayClass('Môn thử nghiệm sáng', '07:30', '09:30'),
        _todayClass('Môn thử nghiệm tối', '18:30', '20:30'),
      ],
    });
  }
  if (p.endsWith('/student/me/grades')) {
    return _ok({
      'mssv': 'TEST260001',
      'summary': {
        'total': 4,
        'scored': 3,
        'passed': 2,
        'failed': 1,
        'average_score': 6.0,
      },
      'grades': [
        _grade(1, '251', 'TN101', 'Môn thử nghiệm A', 3, 9.0),
        _grade(2, '251', 'TN102', 'Môn thử nghiệm B', 2, 3.0),
        _grade(3, '252', 'TN102', 'Môn thử nghiệm B', 2, 6.0),
        _grade(4, '252', 'TN103', 'Môn thử nghiệm D', 1, null),
      ],
    });
  }
  if (p.endsWith('/student/me/graduation-summary')) {
    return _ok({
      'academic': {
        'total': 4,
        'scored': 3,
        'passed': 2,
        'failed': 1,
        'average_score': 6.0,
        'has_curriculum': true,
        'required_subjects': 5,
        'required_passed': 2,
        'remaining_subjects_count': 3,
        'academically_clear': false,
      },
      'remaining_subjects': [
        {
          'subject_code': 'TN201',
          'subject_name': 'Môn thử nghiệm E',
          'credits': 2,
          'completion_status': 'pending',
        },
        {
          'subject_code': 'TN202',
          'subject_name': 'Môn thử nghiệm F',
          'credits': 3,
          'completion_status': 'failed',
        },
      ],
    });
  }
  if (p.endsWith('/student/me')) {
    return _ok({
      'student': {'mssv': 'TEST260001', 'class_code': '06CDTHUNGHIEM'},
    });
  }
  if (p.endsWith('/board/unread-count')) {
    return _ok({'unread': 2, 'must_read_pending': 1});
  }
  if (p.endsWith('/v1/student/board')) {
    return _ok({
      'items': [
        _boardItem('b1', 'Thông báo thử nghiệm A', 'general', false, null),
        _boardItem('b2', 'KHẨN: kiểm thử bảng tin', 'urgent', true, null),
        _boardItem(
          'b3',
          'Thông báo đã đọc C',
          'general',
          false,
          '2026-08-02T00:00:00.000Z',
        ),
      ],
    });
  }
  if (p.endsWith('/teacher/me/overview')) {
    return _ok({
      'teacher': {
        'teacher_id': 'T-TEST-1',
        'teacher_code': 'TESTGV01',
        'name': 'Giảng Viên Thử Nghiệm',
        'type': 'gvch',
      },
      'today_sessions': [
        _slot('Môn thử nghiệm sáng', '07:30', '09:30'),
        _slot('Môn thử nghiệm tối', '18:30', '20:30'),
      ],
    });
  }
  if (p.endsWith('/teacher/notifications/unread-count')) {
    return _ok({'count': 3});
  }
  if (p.endsWith('/teacher/me/semesters')) {
    return _ok([
      {'id': 252, 'ma': '252', 'ten': 'Học kỳ 2, 2025 - 2026'},
      {'id': 261, 'ma': '261', 'ten': 'Học kỳ 1, 2026 - 2027'},
    ]);
  }
  if (p.endsWith('/teacher/me/schedule/semester')) {
    return _ok({
      'data': [
        {'lmhid': '90001', 'lmhma': 'TN261A'},
      ],
    });
  }
  if (p.endsWith('/teacher/me/classes')) {
    return _ok({
      'classes': [
        _cmClass('sec-a', 'TN261A', 'TN101', 'Môn thử nghiệm A', 3, 3, '261'),
        _cmClass('sec-b', 'TN261B', 'TN102', 'Môn thử nghiệm B', 2, 2, '261'),
      ],
    });
  }
  if (p.endsWith('/attendance/my-sessions')) {
    return _ok({
      'sessions': [
        {
          'section_id': '11111111-1111-1111-1111-111111111111',
          'section_code': 'LOP-THU',
          'subject_name': 'Môn thử nghiệm',
          'session_date': '2026-09-08',
          'start_time': '18:00',
          'end_time': '20:30',
          'roster_size': 5,
          'marked_count': 4,
          'session_key': _rosterKey,
        },
      ],
    });
  }
  if (p.endsWith('/attendance/roster')) {
    Map<String, dynamic> s(String mssv, String name, String? st) => {
      'mssv': mssv,
      'full_name': name,
      'status': st,
    };
    return _ok({
      'session_key': _rosterKey,
      'students': [
        s('TEST260001', 'An Thử Nghiệm', 'present'),
        s('TEST260002', 'Bình Thử Nghiệm', 'late'),
        s('TEST260003', 'Chi Thử Nghiệm', 'absent'),
        s('TEST260004', 'Dũng Thử Nghiệm', 'present'),
        s('TEST260005', 'Em Thử Nghiệm', null),
      ],
    });
  }
  return http.Response('{}', 200, headers: _json);
}

// ── harness ─────────────────────────────────────────────────────────────────
/// Passes when the picture differs by at most [tolerance] of its pixels.
class _TolerantComparator extends LocalFileComparator {
  _TolerantComparator(super.testFile, this.tolerance);
  final double tolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final goldenBytes = await getGoldenBytes(golden);
    final r = await GoldenFileComparator.compareLists(imageBytes, goldenBytes);
    if (r.passed || r.diffPercent <= tolerance) return true;
    final error = await generateFailureOutput(r, golden, basedir);
    throw FlutterError(error);
  }
}

String? _flutterRoot() {
  final env = Platform.environment['FLUTTER_ROOT'];
  if (env != null && env.isNotEmpty) return env;
  try {
    final r = Process.runSync('which', ['flutter']);
    if (r.exitCode == 0) {
      final bin = File((r.stdout as String).trim()).resolveSymbolicLinksSync();
      return File(bin).parent.parent.path;
    }
  } catch (_) {}
  return null;
}

Future<void> _loadFonts() async {
  final be = FontLoader('BeVietnamPro');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    be.addFont(rootBundle.load('assets/fonts/BeVietnamPro-$w.ttf'));
  }
  await be.load();
  final root = _flutterRoot();
  if (root == null) return;
  final f = File(
    '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (!f.existsSync()) return;
  final icons = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
  await icons.load();
}

// Home goldens freeze the time of day at 07:00 so the "Tiếp theo" card always
// shows the 07:30 class ("bắt đầu sau 30 phút") and the greeting is "sáng".
DateTime _homeClock() {
  final d = DateTime.now();
  return DateTime(d.year, d.month, d.day, 7);
}

// A gate that already fired: the board's must-read item must not push the
// board screen over the home (that is what the old golden captured).
StudentHomeViewModel _studentHomeVm() => StudentHomeViewModel(
  const StudentHomeRepository(),
  gate: MustReadGate()..tryShow(),
  now: _homeClock,
  tickEvery: null,
);

TeacherHomeViewModel _teacherHomeVm() => TeacherHomeViewModel(
  const TeacherHomeRepository(),
  now: _homeClock,
  tickEvery: null,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadFonts();
    final base = goldenFileComparator as LocalFileComparator;
    goldenFileComparator = _TolerantComparator(
      base.basedir.resolve('screens_golden_test.dart'),
      0.02,
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    EmsApiService.client = MockClient((req) async => _route(req));
  });

  tearDown(() {
    EmsApiService.client = http.Client();
    AppSession.instance
      ..emsToken = null
      ..role = null
      ..mssv = null
      ..teacherId = null
      ..teacherCode = null
      ..fullName = null
      ..emsDenied = false;
  });

  void asStudent() => AppSession.instance
    ..emsToken = 'test-token'
    ..role = CrmRole.student
    ..mssv = 'TEST260001'
    ..fullName = 'Học Viên Thử Nghiệm'
    ..emsDenied = false;

  void asTeacher() => AppSession.instance
    ..emsToken = 'test-token'
    ..role = CrmRole.teacher
    ..teacherId = 'T-TEST-1'
    ..teacherCode = 'TESTGV01'
    ..fullName = 'Giảng Viên Thử Nghiệm';

  Future<void> settle(WidgetTester t) async {
    await t.pump();
    // Pace delays of the cached/paced fetchers (900 ms, 2.6 s) and retries.
    await t.pump(const Duration(milliseconds: 900));
    await t.pump(const Duration(milliseconds: 2600));
    await t.pump(const Duration(seconds: 2));
    await t.pumpAndSettle();
  }

  final screens =
      <
        String,
        ({
          Widget Function() build,
          void Function() who,
          Future<void> Function(WidgetTester)? after,
        })
      >{
        'login': (build: () => const LoginScreen(), who: () {}, after: null),
        'student_home': (
          build: () => HomeScreen(viewModel: _studentHomeVm()),
          who: asStudent,
          after: null,
        ),
        'grades': (
          build: () => const GradesScreen(),
          who: asStudent,
          after: null,
        ),
        'schedule': (
          build: () => const ScheduleScreen(),
          who: asStudent,
          after: null,
        ),
        'student_board': (
          build: () => const StudentBoardScreen(),
          who: asStudent,
          after: null,
        ),
        'teacher_home': (
          build: () => GvHomeScreen(viewModel: _teacherHomeVm()),
          who: asTeacher,
          after: null,
        ),
        'class_manager': (
          build: () => const GvQuanLyLopScreen(),
          who: asTeacher,
          after: null,
        ),
        'teacher_attendance_roster': (
          build: () => const EmsAttendanceTeacherScreen(),
          who: asTeacher,
          after: (t) async {
            await t.tap(find.text('Môn thử nghiệm'));
            await t.pumpAndSettle();
          },
        ),
      };

  for (final mode in ['light', 'dark']) {
    for (final e in screens.entries) {
      testWidgets('${e.key} ($mode)', (tester) async {
        tester.view.physicalSize = const Size(780, 1688);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        e.value.who();
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: VdTheme.light(),
            darkTheme: VdTheme.dark(),
            themeMode: mode == 'dark' ? ThemeMode.dark : ThemeMode.light,
            routes: {'/student_board': (_) => const StudentBoardScreen()},
            home: e.value.build(),
          ),
        );
        await settle(tester);
        await e.value.after?.call(tester);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/${e.key}_$mode.png'),
        );
      });
    }
  }
}
