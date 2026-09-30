import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viendongedu2_flutter/features/student_home/student_home_screen.dart';
import 'package:viendongedu2_flutter/data/student_home_repository.dart';
import 'package:viendongedu2_flutter/features/student_home/must_read_gate.dart';
import 'package:viendongedu2_flutter/features/student_home/student_home_view_model.dart';
import 'package:viendongedu2_flutter/models/crm_student_schedule.dart';
import 'package:viendongedu2_flutter/services/ems_api_service.dart';

// 2026-09-30 is a Wednesday → day_code '4'.
final _today = DateTime(2026, 9, 30, 9);

CrmScheduleItem _class(String name, {String day = '4'}) =>
    CrmScheduleItem(subjectName: name, dayCode: day, startTime: '07:30');

AnnouncementItem _item(
  String id, {
  bool read = false,
  bool mustRead = false,
  bool acked = false,
}) => AnnouncementItem(
  id: id,
  title: 'Tin $id',
  body: '',
  mustRead: mustRead,
  readAt: read ? DateTime(2026, 9, 1) : null,
  acknowledgedAt: acked ? DateTime(2026, 9, 1) : null,
);

class _FakeRepo extends StudentHomeRepository {
  Future<CachedSchedule> Function(
    void Function(List<CrmScheduleItem>, DateTime)? onStored,
  )
  scheduleFn = (_) async =>
      (data: <CrmScheduleItem>[], savedAt: DateTime(2026), fresh: true);
  Future<CachedBoard> Function(
    void Function(List<AnnouncementItem>, DateTime)? onStored,
  )
  boardFn = (_) async =>
      (data: <AnnouncementItem>[], savedAt: DateTime(2026), fresh: true);
  Future<BoardUnread> Function() unreadFn = () async =>
      const BoardUnread(unread: 0, mustReadPending: 0);
  Future<String?> Function() classFn = () async => '06CDTHUNGHIEM';
  bool ems = true;
  bool denied = false;
  int boardCalls = 0;
  int unreadCalls = 0;
  int cleared = 0;
  final order = <String>[];

  @override
  Future<CachedSchedule> schedule({
    void Function(List<CrmScheduleItem>, DateTime)? onStored,
  }) {
    order.add('schedule');
    return scheduleFn(onStored);
  }

  @override
  Future<CachedBoard> board({
    void Function(List<AnnouncementItem>, DateTime)? onStored,
  }) {
    boardCalls++;
    order.add('board');
    return boardFn(onStored);
  }

  @override
  Future<BoardUnread> unreadCount() {
    unreadCalls++;
    order.add('unread');
    return unreadFn();
  }

  @override
  Future<String?> classCode() {
    order.add('profile');
    return classFn();
  }

  @override
  String? get fullName => 'Học Viên Thử Nghiệm';
  @override
  String? get mssv => 'TEST260001';
  @override
  bool get hasEms => ems;
  @override
  bool get emsDenied => denied;
  @override
  Future<void> clearSession() async => cleared++;
}

void main() {
  late _FakeRepo repo;
  late MustReadGate gate;
  late List<Duration> delays;

  StudentHomeViewModel make() => StudentHomeViewModel(
    repo,
    gate: gate,
    now: () => _today,
    delay: (d) async => delays.add(d),
  );

  setUp(() {
    repo = _FakeRepo();
    gate = MustReadGate();
    delays = [];
  });

  test('schedule keeps only today, clears loading, not stale', () async {
    repo.scheduleFn = (_) async => (
      data: [
        _class('Hôm nay'),
        _class('Ngày khác', day: '5'),
      ],
      savedAt: DateTime(2026),
      fresh: true,
    );
    final vm = make();
    expect(vm.scheduleLoading, isTrue);
    await vm.loadTodaySchedule();

    expect(vm.todayClasses.map((c) => c.subjectName), ['Hôm nay']);
    expect(vm.scheduleLoading, isFalse);
    expect(vm.scheduleFailed, isFalse);
    expect(vm.scheduleStaleAt, isNull);
  });

  test('stored copy paints first, then the fresh result replaces it', () async {
    final gateOpen = Completer<void>();
    repo.scheduleFn = (onStored) async {
      onStored!([_class('Bản lưu')], DateTime(2026, 9, 29));
      await gateOpen.future;
      return (data: [_class('Mới')], savedAt: DateTime(2026), fresh: true);
    };
    final vm = make();
    final f = vm.loadTodaySchedule();
    await Future<void>.delayed(Duration.zero);

    expect(vm.todayClasses.single.subjectName, 'Bản lưu');
    expect(vm.scheduleLoading, isFalse);
    gateOpen.complete();
    await f;
    expect(vm.todayClasses.single.subjectName, 'Mới');
  });

  test('refresh failed with stored copy → stale timestamp', () async {
    final saved = DateTime(2026, 9, 29, 8, 5);
    repo.scheduleFn = (_) async =>
        (data: [_class('Bản lưu')], savedAt: saved, fresh: false);
    final vm = make();
    await vm.loadTodaySchedule();

    expect(vm.scheduleStaleAt, saved);
    expect(vm.todayClasses, hasLength(1));
    expect(vm.scheduleFailed, isFalse);
  });

  test('schedule error → failed, empty, not loading; retry recovers', () async {
    repo.scheduleFn = (_) async => throw EmsException('mất mạng');
    final vm = make();
    await vm.loadTodaySchedule();

    expect(vm.scheduleFailed, isTrue);
    expect(vm.scheduleLoading, isFalse);
    expect(vm.todayClasses, isEmpty);
    expect(vm.unauthorized, isFalse);

    repo.scheduleFn = (_) async =>
        (data: [_class('Lại')], savedAt: DateTime(2026), fresh: true);
    await vm.loadTodaySchedule();
    expect(vm.scheduleFailed, isFalse);
    expect(vm.todayClasses, hasLength(1));
  });

  test('401 on schedule flags unauthorized instead of failed', () async {
    repo.scheduleFn = (_) async =>
        throw EmsException('hết phiên', statusCode: 401);
    final vm = make();
    await vm.loadTodaySchedule();

    expect(vm.unauthorized, isTrue);
    expect(vm.authError, isA<EmsException>());
    expect(vm.scheduleFailed, isFalse);
  });

  test(
    'start: schedule now, profile after 900 ms, then 500 ms → bell+board',
    () async {
      repo.unreadFn = () async => BoardUnread(unread: 2, mustReadPending: 1);
      repo.boardFn = (_) async => (
        data: [_item('a'), _item('b', read: true)],
        savedAt: DateTime(2026),
        fresh: true,
      );
      final vm = make()..start();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(delays, [
        const Duration(milliseconds: 900),
        const Duration(milliseconds: 500),
      ]);
      expect(repo.order.first, 'schedule');
      expect(repo.order.indexOf('profile'), 1);
      expect(repo.order.sublist(2).toSet(), {'unread', 'board'});
      expect(vm.classCode, '06CDTHUNGHIEM');
      expect(vm.unreadCount, 3);
      expect(vm.boardUnread, 1);
      expect(vm.latestBoardItem?.id, 'a');
      expect(vm.name, 'Học Viên Thử Nghiệm');
      expect(vm.mssv, 'TEST260001');
    },
  );

  test('class code stays "–" when the profile call fails', () async {
    repo.classFn = () async => throw EmsException('x');
    final vm = make()..start();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(vm.classCode, '–');
  });

  test('unread count: skipped without EMS, error swallowed', () async {
    repo.ems = false;
    final vm = make();
    await vm.loadUnreadCount();
    expect(repo.unreadCalls, 0);

    repo.ems = true;
    repo.unreadFn = () async => throw EmsException('x');
    await vm.loadUnreadCount();
    expect(repo.unreadCalls, 1);
    expect(vm.unreadCount, 0);
  });

  test('board error is swallowed and offers retry', () async {
    repo.boardFn = (_) async => throw EmsException('boom');
    final vm = make();
    await vm.loadBoard();

    expect(vm.boardFailed, isTrue);
    expect(vm.latestBoardItem, isNull);
    expect(vm.boardUnread, 0);
  });

  test('board error with a deliberate EMS denial is NOT a failure', () async {
    repo.denied = true;
    repo.boardFn = (_) async => throw EmsException('denied', statusCode: 403);
    final vm = make();
    await vm.loadBoard();

    expect(vm.boardFailed, isFalse);
    expect(vm.latestBoardItem, isNull);
  });

  test('board stored copy paints first; recovery clears boardFailed', () async {
    repo.boardFn = (_) async => throw EmsException('boom');
    final vm = make();
    await vm.loadBoard();
    expect(vm.boardFailed, isTrue);

    repo.boardFn = (onStored) async {
      onStored!([_item('old')], DateTime(2026));
      return (data: [_item('new')], savedAt: DateTime(2026), fresh: true);
    };
    await vm.loadBoard();
    expect(vm.latestBoardItem?.id, 'new');
    expect(vm.boardFailed, isFalse);
  });

  test('loadBoard is re-entrancy guarded', () async {
    final open = Completer<void>();
    repo.boardFn = (_) async {
      await open.future;
      return (data: [_item('a')], savedAt: DateTime(2026), fresh: true);
    };
    final vm = make();
    final first = vm.loadBoard();
    final second = vm.loadBoard();
    open.complete();
    await Future.wait([first, second]);

    expect(repo.boardCalls, 1);
    await vm.loadBoard(); // guard released afterwards (resume reload)
    expect(repo.boardCalls, 2);
  });

  test('must-read prompt is raised once per session, even on reload', () async {
    repo.boardFn = (_) async => (
      data: [_item('m', mustRead: true, read: true)],
      savedAt: DateTime(2026),
      fresh: true,
    );
    final vm = make();
    await vm.loadBoard();
    expect(vm.mustReadPrompt, isTrue);
    expect(vm.takeMustReadPrompt(), isTrue);
    expect(vm.takeMustReadPrompt(), isFalse);

    await vm.loadBoard(); // e.g. app resume
    expect(vm.mustReadPrompt, isFalse);
  });

  test('acknowledged or plain items never raise the prompt', () async {
    repo.boardFn = (_) async => (
      data: [_item('a'), _item('b', mustRead: true, acked: true)],
      savedAt: DateTime(2026),
      fresh: true,
    );
    final vm = make();
    await vm.loadBoard();
    expect(vm.mustReadPrompt, isFalse);
    expect(gate.shown, isFalse);
  });

  test(
    'logout re-arms the prompt for the next student and clears session',
    () async {
      repo.boardFn = (_) async => (
        data: [_item('m', mustRead: true)],
        savedAt: DateTime(2026),
        fresh: true,
      );
      final vm = make();
      await vm.loadBoard();
      expect(gate.shown, isTrue);

      await vm.logout();
      expect(repo.cleared, 1);
      expect(gate.shown, isFalse);
      await vm.loadBoard();
      expect(vm.takeMustReadPrompt(), isTrue);
    },
  );

  test('disposing mid-load does not notify or throw', () async {
    final open = Completer<void>();
    repo.scheduleFn = (_) async {
      await open.future;
      return (data: [_class('x')], savedAt: DateTime(2026), fresh: true);
    };
    final vm = make();
    final f = vm.loadTodaySchedule();
    vm.dispose();
    open.complete();
    await f;
  });

  testWidgets('screen routes a schedule 401 to /login (handleCrmAuthError)', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    repo.scheduleFn = (_) async =>
        throw EmsException('hết phiên', statusCode: 401);
    final vm = make();
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(viewModel: vm),
        routes: {'/login': (_) => const Text('LOGIN PAGE')},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('LOGIN PAGE'), findsOneWidget);
    vm.dispose();
  });
}
