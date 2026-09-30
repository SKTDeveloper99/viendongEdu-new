// Week strip above "Lịch dạy": dot counts (max 3, coloured by buổi) and
// tap-to-select, plus the list/title switching through the view model.
// Fictional data only (TESTGV01).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viendongedu2_flutter/data/teacher_home_repository.dart';
import 'package:viendongedu2_flutter/features/teacher_home/teacher_home_view_model.dart';
import 'package:viendongedu2_flutter/features/teacher_home/widgets/home_tab.dart';
import 'package:viendongedu2_flutter/features/teacher_home/widgets/week_strip.dart';
import 'package:viendongedu2_flutter/models/crm_teacher_class.dart';
import 'package:viendongedu2_flutter/models/crm_teacher_profile.dart';
import 'package:viendongedu2_flutter/services/crm_teacher_api.dart';
import 'package:viendongedu2_flutter/theme/vd_tokens.dart';

// Wed 2026-09-30.
final _now = DateTime(2026, 9, 30, 8);

CrmScheduleSlot _pat(String day, String start) => CrmScheduleSlot(
  lmhId: '1',
  lmhMa: 'TN-1',
  mhTen: 'Môn mẫu',
  ngayMa: day,
  tgBatDau: start,
  tgKetThuc: '23:00',
);

class _Repo extends TeacherHomeRepository {
  final requested = <String>[];
  @override
  Future<CachedOverview> overview({
    void Function(CrmTeacherOverview, DateTime)? onStored,
  }) async => (
    data: CrmTeacherOverview(
      teacher: const CrmTeacherProfile(
        teacherId: 'T-TEST-1',
        teacherCode: 'TESTGV01',
        name: 'Giảng Viên Thử Nghiệm',
      ),
      currentSemester: '261',
      semesters: [
        const CrmSemester(
          id: 1,
          ma: '261',
          ten: 'HK1',
          ngayBatDau: '2026-09-01',
          ngayKetThuc: '2027-01-31',
        ),
      ],
      semesterSlots: [
        _pat('4', '07:30'), // Wed: Sáng + Tối = 2 dots
        _pat('4', '18:30'),
        _pat('5', '07:30'), // Thu: 4 slots, capped at 3
        _pat('5', '13:30'),
        _pat('5', '18:30'),
        _pat('5', '19:30'),
      ],
    ),
    savedAt: DateTime(2026),
    fresh: true,
  );

  @override
  Future<List<CrmScheduleSlot>> scheduleForDate(String date) async {
    requested.add(date);
    return [
      CrmScheduleSlot(
        lmhId: '2',
        lmhMa: 'TN-2',
        mhTen: 'Môn ngày khác',
        thoiGianBd: '13:30',
        thoiGianKt: '2026-10-01T15:30:00',
      ),
    ];
  }

  @override
  String get teacherId => 'T-TEST-1';
  @override
  String? get fullName => 'Giảng Viên Thử Nghiệm';
  @override
  String? get teacherCode => 'TESTGV01';
}

void main() {
  Widget host(Widget child) => MaterialApp(
    theme: ThemeData(extensions: [VdTokens.light]),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );

  testWidgets('WeekStrip: dots per day (max 3) and tap reports the date', (
    tester,
  ) async {
    DateTime? tapped;
    await tester.pumpWidget(
      host(
        WeekStrip(
          today: DateTime(2026, 9, 30),
          selected: DateTime(2026, 9, 30),
          dotStartsFor: (d) => switch (d.day) {
            28 => const [],
            29 => const ['07:30'],
            30 => const ['07:30', '18:30'],
            _ => const ['07:30', '13:30', '18:30', '19:30'],
          },
          onSelect: (d) => tapped = d,
        ),
      ),
    );
    int dots(int day, [String ym = '2026-9']) => find
        .descendant(
          of: find.byKey(ValueKey('week-day-$ym-$day')),
          matching: find.byWidgetPredicate(
            (w) => '${w.key}'.contains('week-dot'),
          ),
        )
        .evaluate()
        .length;
    expect([dots(28), dots(29), dots(30)], [0, 1, 2]);
    expect(find.text('T2'), findsOneWidget);
    expect(find.text('CN'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('week-day-2026-9-29')));
    expect(tapped, DateTime(2026, 9, 29));
    // Next week via chevron.
    await tester.tap(find.byTooltip('Tuần sau'));
    await tester.pump();
    expect(find.byKey(const ValueKey('week-day-2026-10-5')), findsOneWidget);
    expect(dots(6, '2026-10'), 3); // 4 sessions, capped at 3
  });

  testWidgets('HomeTab: tapping a day swaps title + list; today returns', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _Repo();
    final vm = TeacherHomeViewModel(
      repo,
      now: () => _now,
      tickEvery: null,
      pace: (id, {required windowMs}) => Duration.zero,
      delay: (_) async {},
    );
    await vm.loadOverview();
    // Weekly pattern -> dots: Wed 2, Thu capped at 3, Fri 0.
    expect(vm.dotStartsFor(DateTime(2026, 9, 30)).length, 2);
    expect(vm.dotStartsFor(DateTime(2026, 10, 1)).length, 3);
    expect(vm.dotStartsFor(DateTime(2026, 10, 2)).length, 0);
    expect(vm.dotStartsFor(DateTime(2026, 8, 12)).length, 0); // before term

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [VdTokens.light]),
        home: Scaffold(
          body: ListenableBuilder(
            listenable: vm,
            builder: (_, _) => HomeTab(
              vm: vm,
              scheduleExpanded: true,
              onToggleExpanded: () {},
              onBell: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('Lịch dạy hôm nay'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('week-day-2026-10-1')));
    await tester.pumpAndSettle();
    expect(repo.requested, ['2026-10-01']);
    expect(find.text('Lịch dạy Thứ 5, 01/10'), findsOneWidget);
    expect(find.text('Môn ngày khác'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('week-day-2026-9-30')));
    await tester.pumpAndSettle();
    expect(find.text('Lịch dạy hôm nay'), findsOneWidget);
    expect(find.text('Môn ngày khác'), findsNothing);
    expect(repo.requested.length, 1); // today needs no extra call
  });
}
