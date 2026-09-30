// Modern home: "Tiếp theo" card (frozen clock, minute ticker), header greeting,
// QR button clearance, teacher Điểm danh button and the Buổi fix.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viendongedu2_flutter/data/student_home_repository.dart';
import 'package:viendongedu2_flutter/data/teacher_home_repository.dart';
import 'package:viendongedu2_flutter/features/student_home/must_read_gate.dart';
import 'package:viendongedu2_flutter/features/student_home/student_home_screen.dart';
import 'package:viendongedu2_flutter/features/student_home/student_home_view_model.dart';
import 'package:viendongedu2_flutter/features/teacher_home/teacher_home_screen.dart';
import 'package:viendongedu2_flutter/features/teacher_home/teacher_home_view_model.dart';
import 'package:viendongedu2_flutter/features/teacher_home/widgets/gv_class_chip.dart';
import 'package:viendongedu2_flutter/models/crm_student_schedule.dart';
import 'package:viendongedu2_flutter/models/crm_teacher_class.dart';
import 'package:viendongedu2_flutter/models/crm_teacher_profile.dart';
import 'package:viendongedu2_flutter/services/crm_teacher_api.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';
import 'package:viendongedu2_flutter/theme/vd_theme.dart';

class _StudentRepo extends StudentHomeRepository {
  @override
  Future<CachedSchedule> schedule({
    void Function(List<CrmScheduleItem>, DateTime)? onStored,
  }) async => (
    data: [
      const CrmScheduleItem(
        subjectName: 'Môn thử nghiệm sáng',
        dayCode: '4',
        startTime: '07:30',
        endTime: '09:30',
        room: 'P.101',
      ),
    ],
    savedAt: DateTime(2026),
    fresh: true,
  );
  @override
  Future<CachedBoard> board({
    void Function(List<AnnouncementItem>, DateTime)? onStored,
  }) async =>
      (data: <AnnouncementItem>[], savedAt: DateTime(2026), fresh: true);
  @override
  Future<BoardUnread> unreadCount() async =>
      const BoardUnread(unread: 0, mustReadPending: 0);
  @override
  Future<String?> classCode() async => '06CDTHUNGHIEM';
  @override
  String? get fullName => 'Học Viên Thử Nghiệm';
  @override
  String? get mssv => 'TEST260001';
  @override
  bool get hasEms => true;
  @override
  bool get emsDenied => false;
}

class _TeacherRepo extends TeacherHomeRepository {
  @override
  Future<CachedOverview> overview({
    void Function(CrmTeacherOverview, DateTime)? onStored,
  }) async => (
    data: CrmTeacherOverview(
      teacher: const CrmTeacherProfile(
        teacherId: 'T-TEST-1',
        teacherCode: 'TESTGV01',
        name: 'Giảng Viên Thử Nghiệm',
        type: 'gvch',
      ),
      todaySessions: const [
        CrmScheduleSlot(
          lmhId: '1',
          lmhMa: 'TN-1',
          mhTen: 'Môn thử nghiệm',
          phongTen: 'P.101',
          thoiGianBd: '07:30',
          thoiGianKt: '2026-09-30T09:30:00',
        ),
      ],
    ),
    savedAt: DateTime(2026),
    fresh: true,
  );
  @override
  Future<int> unreadCount() async => 0;
  @override
  String get teacherId => 'T-TEST-1';
  @override
  String? get fullName => 'Giảng Viên Thử Nghiệm';
  @override
  String? get teacherCode => 'TESTGV01';
  @override
  bool get hasEms => true;
  @override
  Future<void> clearSession() async {}
}

Future<void> _noDelay(Duration _) async {}

Widget _app(Widget home, {Map<String, WidgetBuilder>? routes}) =>
    MaterialApp(theme: VdTheme.light(), routes: routes ?? const {}, home: home);

void main() {
  // 2026-09-30 is a Wednesday → day_code '4'.
  var clock = DateTime(2026, 9, 30, 7, 0);

  setUp(() => clock = DateTime(2026, 9, 30, 7, 0));

  testWidgets('student: header greeting, Tiếp theo card, minute ticker', (
    tester,
  ) async {
    final vm = StudentHomeViewModel(
      _StudentRepo(),
      gate: MustReadGate(),
      now: () => clock,
      delay: _noDelay,
    );
    await tester.pumpWidget(_app(HomeScreen(viewModel: vm)));
    await tester.pumpAndSettle();

    expect(find.text('Chào buổi sáng,'), findsOneWidget);
    expect(find.text('MSSV: TEST260001'), findsOneWidget);
    expect(find.text('Tiếp theo'), findsOneWidget);
    expect(find.text('bắt đầu sau 30 phút'), findsOneWidget);

    clock = DateTime(2026, 9, 30, 7, 31);
    await tester.pump(const Duration(minutes: 1));
    expect(find.text('Đang diễn ra'), findsOneWidget);
    expect(find.text('còn 119 phút'), findsOneWidget);

    // Leaving the screen cancels the timer (the framework fails a test that
    // ends with one pending).
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  });

  testWidgets('student: friendly empty state after the last class', (
    tester,
  ) async {
    clock = DateTime(2026, 9, 30, 21, 0);
    final vm = StudentHomeViewModel(
      _StudentRepo(),
      gate: MustReadGate(),
      now: () => clock,
      delay: _noDelay,
      tickEvery: null,
    );
    await tester.pumpWidget(_app(HomeScreen(viewModel: vm)));
    await tester.pumpAndSettle();
    expect(find.text('Chào buổi tối,'), findsOneWidget);
    expect(find.text('Hôm nay bạn không còn tiết nào'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  });

  testWidgets('student: last menu row is clear of the QR button at 390x844', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // The test font (Ahem) is far wider than BeVietnamPro, so unrelated rows
    // report overflow here; only the geometry below matters.
    final prev = FlutterError.onError;
    FlutterError.onError = (d) {
      if (!d.exceptionAsString().contains('overflowed')) prev!(d);
    };
    addTearDown(() => FlutterError.onError = prev);
    final vm = StudentHomeViewModel(
      _StudentRepo(),
      gate: MustReadGate(),
      now: () => clock,
      delay: _noDelay,
      tickEvery: null,
    );
    await tester.pumpWidget(_app(HomeScreen(viewModel: vm)));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -2000),
    );
    await tester.pumpAndSettle();

    final label = tester.getRect(find.text('Hỏi nhà trường'));
    final qr = tester.getRect(find.byIcon(Icons.qr_code_rounded));
    expect(label.bottom, lessThanOrEqualTo(qr.top - 8));
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  });

  testWidgets('teacher: card with class code and Điểm danh -> route', (
    tester,
  ) async {
    final vm = TeacherHomeViewModel(
      _TeacherRepo(),
      pace: (id, {required windowMs}) => Duration.zero,
      delay: _noDelay,
      now: () => clock,
    );
    await tester.pumpWidget(
      _app(
        GvHomeScreen(viewModel: vm),
        routes: {'/ems_attendance_gv': (_) => const Text('route:attendance')},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chào buổi sáng,'), findsOneWidget);
    expect(find.text('Tiếp theo'), findsOneWidget);
    expect(find.text('bắt đầu sau 30 phút'), findsOneWidget);
    expect(find.text('TN-1'), findsWidgets);
    expect(find.text('Cơ hữu'), findsOneWidget);
    expect(find.text('Mã GV: TESTGV01'), findsOneWidget);
    await tester.tap(find.text('Điểm danh'));
    await tester.pumpAndSettle();
    expect(find.text('route:attendance'), findsOneWidget);
    vm.dispose();
  });

  testWidgets('teacher: chip shows Buổi from the start time (no buoi key)', (
    tester,
  ) async {
    Map<String, dynamic> slot(String start) => CrmScheduleSlot(
      lmhId: '1',
      lmhMa: 'X',
      mhTen: 'Môn $start',
      thoiGianBd: start,
    ).toJson();
    expect(slot('07:30').containsKey('buoi'), isFalse);
    await tester.pumpWidget(
      MaterialApp(
        theme: VdTheme.light(),
        home: Scaffold(
          body: Column(
            children: [
              GvClassChip(data: slot('07:30')),
              GvClassChip(data: slot('11:59')),
              GvClassChip(data: slot('12:00')),
              GvClassChip(data: slot('17:59')),
              GvClassChip(data: slot('18:00')),
              GvClassChip(data: slot('2026-09-30T19:00:00')),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Sáng'), findsNWidgets(2));
    expect(find.text('Chiều'), findsNWidgets(2));
    expect(find.text('Tối'), findsNWidgets(2));
  });
}
