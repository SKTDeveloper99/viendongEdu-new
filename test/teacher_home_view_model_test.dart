import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viendongedu2_flutter/data/teacher_home_repository.dart';
import 'package:viendongedu2_flutter/features/teacher_home/teacher_home_screen.dart';
import 'package:viendongedu2_flutter/features/teacher_home/teacher_home_view_model.dart';
import 'package:viendongedu2_flutter/features/teacher_home/widgets/gv_class_chip.dart';
import 'package:viendongedu2_flutter/models/crm_teacher_class.dart';
import 'package:viendongedu2_flutter/models/crm_teacher_profile.dart';
import 'package:viendongedu2_flutter/services/crm_teacher_api.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';
import 'package:viendongedu2_flutter/services/startup_pace.dart';

CrmTeacherOverview _overview({String type = 'gvch', int sessions = 2}) =>
    CrmTeacherOverview(
      teacher: CrmTeacherProfile(
        teacherId: 'T-TEST-1',
        teacherCode: 'TESTGV01',
        name: 'Giảng Viên Thử Nghiệm',
        type: type,
      ),
      todaySessions: [
        for (var i = 0; i < sessions; i++)
          CrmScheduleSlot(
            lmhId: '$i',
            lmhMa: 'TN-$i',
            mhTen: 'Môn $i',
            phongTen: 'P.10$i',
          ),
      ],
    );

class _FakeRepo extends TeacherHomeRepository {
  Future<CachedOverview> Function(
    void Function(CrmTeacherOverview, DateTime)? onStored,
  )
  overviewFn = (_) async =>
      (data: _overview(), savedAt: DateTime(2026), fresh: true);
  Future<int> Function() unreadFn = () async => 3;
  bool ems = true;
  int overviewCalls = 0;
  int unreadCalls = 0;
  int cleared = 0;
  String? name = 'Giảng Viên Thử Nghiệm';

  @override
  Future<CachedOverview> overview({
    void Function(CrmTeacherOverview, DateTime)? onStored,
  }) {
    overviewCalls++;
    return overviewFn(onStored);
  }

  @override
  Future<int> unreadCount() {
    unreadCalls++;
    return unreadFn();
  }

  @override
  String get teacherId => 'T-TEST-1';
  @override
  String? get fullName => name;
  @override
  String? get teacherCode => 'TESTGV01';
  @override
  bool get hasEms => ems;
  @override
  Future<void> clearSession() async => cleared++;
}

void main() {
  late _FakeRepo repo;
  late List<Duration> delays;
  late List<(String, int)> paces;

  TeacherHomeViewModel make() => TeacherHomeViewModel(
    repo,
    pace: (id, {required windowMs}) {
      paces.add((id, windowMs));
      return Duration(milliseconds: windowMs ~/ 100);
    },
    delay: (d) async => delays.add(d),
  );

  setUp(() {
    repo = _FakeRepo();
    delays = [];
    paces = [];
  });

  test('overview loaded: sessions as maps, profile, not stale', () async {
    final vm = make();
    expect(vm.scheduleLoading, isTrue);
    await vm.loadOverview();

    expect(vm.todayClasses.map((c) => c['mhten']), ['Môn 0', 'Môn 1']);
    expect(vm.todayClasses.first['phongten'], 'P.100');
    expect(vm.profile?.isCoHuu, isTrue);
    expect(vm.scheduleLoading, isFalse);
    expect(vm.scheduleFailed, isFalse);
    expect(vm.scheduleStaleAt, isNull);
    expect(vm.unauthorized, isFalse);
  });

  test('stored copy paints first, fresh=false marks it stale', () async {
    final saved = DateTime(2026, 9, 29, 8, 30);
    var seenWhileLoading = false;
    late TeacherHomeViewModel vm;
    repo.overviewFn = (onStored) async {
      onStored!(_overview(sessions: 1), saved);
      seenWhileLoading = vm.todayClasses.length == 1 && !vm.scheduleLoading;
      return (data: _overview(sessions: 1), savedAt: saved, fresh: false);
    };
    vm = make();
    await vm.loadOverview();

    expect(seenWhileLoading, isTrue);
    expect(vm.scheduleStaleAt, saved);
    expect(vm.todayClasses, hasLength(1));
  });

  test('overview error: empty list, failed flag, retry recovers', () async {
    repo.overviewFn = (_) async => throw EmsException('boom', statusCode: 500);
    final vm = make();
    await vm.loadOverview();

    expect(vm.scheduleFailed, isTrue);
    expect(vm.scheduleLoading, isFalse);
    expect(vm.todayClasses, isEmpty);
    expect(vm.unauthorized, isFalse);

    repo.overviewFn = (_) async =>
        (data: _overview(), savedAt: DateTime(2026), fresh: true);
    await vm.loadOverview();
    expect(vm.scheduleFailed, isFalse);
    expect(vm.todayClasses, hasLength(2));
  });

  test(
    '401 sets the auth flag and is not shown as a failed schedule',
    () async {
      repo.overviewFn = (_) async => throw EmsException('no', statusCode: 401);
      final vm = make();
      await vm.loadOverview();

      expect(vm.unauthorized, isTrue);
      expect(vm.authError, isA<EmsException>());
      expect(vm.scheduleFailed, isFalse);
    },
  );

  test(
    'start: pace windows 900 (overview) and 1400 (+1200 ms) unread',
    () async {
      final vm = make();
      vm.start();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(paces, contains(('T-TEST-1', 900)));
      expect(paces, contains(('T-TEST-1', 1400)));
      expect(delays, contains(const Duration(milliseconds: 9)));
      expect(delays, contains(const Duration(milliseconds: 1214)));
      expect(repo.overviewCalls, 1);
      expect(repo.unreadCalls, 1);
      expect(vm.unreadCount, 3);
      expect(vm.todayClasses, hasLength(2));
    },
  );

  test('default pace is StartupPace for the session teacher id', () async {
    final vm = TeacherHomeViewModel(repo, delay: (d) async => delays.add(d));
    vm.start();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(
      delays,
      containsAll([
        StartupPace.forAccount('T-TEST-1', windowMs: 900),
        const Duration(milliseconds: 1200) +
            StartupPace.forAccount('T-TEST-1', windowMs: 1400),
      ]),
    );
    vm.dispose();
  });

  test('unread: skipped without EMS, errors swallowed', () async {
    repo.ems = false;
    final vm = make();
    await vm.loadUnreadCount();
    expect(repo.unreadCalls, 0);
    expect(vm.unreadCount, 0);

    repo.ems = true;
    repo.unreadFn = () async => throw EmsException('x', statusCode: 500);
    await vm.loadUnreadCount();
    expect(repo.unreadCalls, 1);
    expect(vm.unreadCount, 0);

    repo.unreadFn = () async => 7;
    await vm.loadUnreadCount();
    expect(vm.unreadCount, 7);
  });

  test('identity comes from the session; blank name shows a dash', () {
    final vm = make();
    expect(vm.displayName, 'Giảng Viên Thử Nghiệm');
    expect(vm.teacherCode, 'TESTGV01');
    repo.name = '';
    expect(vm.displayName, '–');
  });

  test('disposed view model ignores late results', () async {
    final vm = make();
    vm.dispose();
    await vm.loadOverview();
    await vm.loadUnreadCount();
    expect(vm.todayClasses, isEmpty);
  });

  testWidgets('injected view model: logout clears the session and leaves', (
    tester,
  ) async {
    final vm = make();
    await tester.pumpWidget(
      MaterialApp(
        routes: {
          '/': (_) => const Scaffold(body: Text('route:/')),
          '/gv': (_) => GvHomeScreen(viewModel: vm),
        },
        initialRoute: '/gv',
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Cá nhân'));
    await tester.pump();
    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();
    expect(repo.cleared, 1);
    expect(find.text('route:/'), findsOneWidget);
    vm.dispose();
  });

  testWidgets('chip shows the Buổi label when the map carries buoi', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              GvClassChip(data: {'mhten': 'A', 'buoi': 'S'}),
              GvClassChip(data: {'mhten': 'B', 'buoi': 'C'}),
              GvClassChip(data: {'mhten': 'C', 'buoi': 'T'}),
              GvClassChip(data: {'mhten': 'D'}),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Sáng'), findsOneWidget);
    expect(find.text('Chiều'), findsOneWidget);
    expect(find.text('Tối'), findsOneWidget);
  });
}
