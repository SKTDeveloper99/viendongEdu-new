import 'package:animations/animations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../components/home_header_bar.dart';
import '../../components/next_up_card.dart';
import '../../core/crm_web/crm_web_target.dart';
import '../../core/schedule/next_up.dart';
import '../../data/api/teacher_conversations_api.dart';
import '../../data/teacher_home_repository.dart';
import '../../services/app_session.dart';
import '../../services/crm_session_guard.dart';
import '../../services/ems_api_service.dart';
import '../../theme/vd_motion.dart';
import '../../theme/vd_tokens.dart';
import '../bell/bell_screen.dart';
import '../nhom/nhom_screens.dart';
import '../staff_home/staff_home_screen.dart' show AppMeApi;
import '../teacher_attendance/attendance_outbox.dart';
import '../teacher_home/next_up.dart';
import '../teacher_home/teacher_home_view_model.dart';
import '../teacher_home/widgets/gv_bottom_nav.dart';
import '../teacher_home/widgets/profile_tab.dart';
import '../../screens/gv_profile_info_screen.dart';
import '../work/my_work_screen.dart';
import '../work/piece_screen.dart';
import '../work/work_api.dart';
import 'home_prefs.dart';
import 'home_widgets.dart';
import 'hub_screens.dart';

/// One home for teachers, office accounts and accounts that are both
/// (Overlord slice, agreed with the chief of staff 2026-11-16): the header the
/// app already has, one focus card, at most six places, one "+ Giao việc";
/// a two-tab bar (Trang chủ · Cá nhân) unless the debug switch turns it off.
class WorkHomeScreen extends StatefulWidget {
  const WorkHomeScreen({super.key});

  @override
  State<WorkHomeScreen> createState() => _WorkHomeScreenState();
}

class _WorkHomeScreenState extends State<WorkHomeScreen> {
  TeacherHomeViewModel? _vm;
  Map<String, dynamic>? _me;
  int _messages = 0;
  int _tab = 0;
  bool _authHandled = false;

  AppSession get _s => AppSession.instance;
  bool get _teacher => _s.isGiangVien;
  bool get _staff => _s.isStaff;

  @override
  void initState() {
    super.initState();
    HomePrefs.load();
    if (_teacher) {
      _vm = TeacherHomeViewModel(const TeacherHomeRepository())..start();
      _vm!.addListener(_onVm);
      AttendanceOutbox.instance.start();
    }
    _refresh();
  }

  @override
  void dispose() {
    _vm?.removeListener(_onVm);
    _vm?.stopClock();
    if (_vm != null) AttendanceOutbox.instance.stop();
    _vm?.dispose();
    super.dispose();
  }

  void _onVm() {
    final vm = _vm;
    if (vm != null && vm.unauthorized && !_authHandled && mounted) {
      _authHandled = true;
      handleCrmAuthError(context, vm.authError!);
    }
  }

  Future<void> _refresh() async {
    try {
      final me = await AppMeApi.me();
      if (mounted) setState(() => _me = me);
    } on EmsException catch (e) {
      if (mounted && e.statusCode == 401) handleCrmAuthError(context, e);
    } catch (_) {}
    if (_teacher) {
      try {
        final n = await TeacherConversationsApi.unreadCount();
        if (mounted) setState(() => _messages = n);
      } catch (_) {}
    }
  }

  Future<void> _go(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _refresh();
  }

  Future<void> _goNamed(String route) async {
    await Navigator.pushNamed(context, route);
    _refresh();
  }

  Map<String, dynamic>? get _counts =>
      (_me?['counts'] as Map?)?.cast<String, dynamic>();
  Map<String, dynamic> get _can =>
      ((_me?['can'] as Map?) ?? const {}).cast<String, dynamic>();
  int _c(String k) => asInt(_counts?[k]);

  String get _name {
    final vmName = _vm?.displayName;
    if (vmName != null && vmName != '–' && vmName.isNotEmpty) return vmName;
    return _s.fullName ?? '';
  }

  List<String> get _chips => [
    if (_teacher && _vm != null && _vm!.teacherCode != '–')
      'Mã GV: ${_vm!.teacherCode}',
    if (_teacher && _vm?.profile?.isCoHuu == true) 'Cơ hữu',
    if (_staff) 'Văn phòng',
  ];

  // A class in progress or starting within 90 minutes wins the focus card.
  bool _classWins(NextUp n) =>
      n.entry != null &&
      (n.phase == NextUpPhase.ongoing ||
          (n.phase == NextUpPhase.upcoming && n.minutes <= 90));

  String _classLine(NextUp n) => n.entry == null
      ? ''
      : '${n.statusLabel}: ${n.entry!.subject} · ${n.countdown}';

  Future<void> _openWork() async {
    // Việc opens on the tab that waits on the person.
    final tab = _c('to_review') > 0 ? 1 : 0;
    await _go(MyWorkScreen(initialTab: tab));
  }

  Future<void> _openLich() async {
    final vm = _vm;
    if (vm == null) {
      await openWeekPage(context);
      _refresh();
      return;
    }
    final last = _staff ? await HomePrefs.lichLast() : 'teach';
    if (!mounted) return;
    await _go(LichScreen(vm: vm, openWeekFirst: last == 'week'));
  }

  List<HomeTileSpec> get _tiles {
    final lookup = _can['student_lookup'] == true;
    return [
      HomeTileSpec(
        Icons.task_alt,
        'Việc',
        badge: _c('to_review') + _c('received_open'),
        onTap: _openWork,
      ),
      HomeTileSpec(
        Icons.groups_2_outlined,
        'Nhóm',
        onTap: () => _go(const NhomListScreen()),
      ),
      HomeTileSpec(Icons.event_note, 'Lịch', onTap: _openLich),
      if (_teacher)
        HomeTileSpec(
          Icons.class_outlined,
          'Lớp',
          onTap: () => _go(LopScreen(vm: _vm!, studentLookup: lookup)),
        )
      else if (lookup)
        HomeTileSpec(
          Icons.person_search_outlined,
          'Sinh viên',
          onTap: () => _goNamed(const CrmTarget.students().routeName),
        ),
      HomeTileSpec(
        Icons.business_center_outlined,
        'Văn phòng',
        onTap: () => _go(VanPhongScreen(congVan: _can['cong_van'] == true)),
      ),
      HomeTileSpec(
        Icons.more_horiz,
        'Thêm',
        onTap: () => _go(const ThemScreen()),
      ),
    ];
  }

  Widget _focus() {
    final vm = _vm;
    final office = OfficeFocusCard(
      counts: _counts,
      onReview: () => _go(const MyWorkScreen(initialTab: 1)),
      onPiece: (id) => _go(PieceScreen(taskId: id)),
    );
    if (vm == null) return office;
    if (vm.scheduleLoading && !vm.scheduleFailed) {
      return Container(
        height: 120,
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        decoration: BoxDecoration(
          color: context.vd.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
        ),
      );
    }
    final next = vm.upNext;
    final classCard = NextUpCard(
      state: next,
      emptyText: teacherNextUpEmpty,
      showClassCode: true,
      onAttendance: () => _goNamed('/ems_attendance_gv'),
    );
    if (!_staff) return classCard;
    return _classWins(next) ? classCard : office;
  }

  String? _status() {
    final vm = _vm;
    if (vm != null && _staff) {
      // The one that lost the focus card becomes the status line.
      final next = vm.upNext;
      if (_classWins(next)) return OfficeFocusCard.statusOf(_counts);
      return next.entry == null ? null : _classLine(next);
    }
    if (_counts == null) return null;
    final waiting = _c('received_open');
    return waiting > 0 ? '$waiting việc đang chờ bạn' : null;
  }

  Widget _homeBody() {
    final t = context.vd;
    final bar = HomePrefs.bottomBar.value;
    final canGive = _can['give_work'] == true;
    return Column(
      children: [
        HomeHeaderBar(
          now: _vm?.now ?? DateTime.now(),
          name: _name,
          chips: _chips,
          status: _status(),
          unreadCount: _c('bell_work_unread'),
          onBell: () => _go(const BellScreen()),
          actions: [
            if (_teacher)
              HeaderRoundButton(
                icon: Icons.chat_bubble_outline,
                badge: _messages,
                label: 'Tin nhắn',
                onTap: () => _goNamed('/teacher_conversations'),
              ),
            if (!bar)
              HeaderRoundButton(
                initials: initialsOf(_name),
                label: 'Tài khoản',
                onTap: () => _go(_profile(asPage: true)),
              ),
          ],
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await Future.wait([
                _refresh(),
                if (_vm != null) _vm!.loadOverview(),
              ]);
            },
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _focus(),
                if (canGive)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _go(const GiveTaskScreen()),
                        icon: const Icon(Icons.add),
                        label: const Text('Giao việc'),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: HomeTileGrid(tiles: _tiles),
                ),
                if (kDebugMode) _debugSwitch(t, bar),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _debugSwitch(VdTokens t, bool bar) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Container(
      decoration: BoxDecoration(
        border: Border.all(color: t.hairline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SwitchListTile(
        dense: true,
        title: Text(
          'DEBUG · ${bar ? 'Có thanh dưới' : 'Không thanh dưới'}',
          style: TextStyle(color: t.inkMuted, fontSize: 13),
        ),
        value: bar,
        onChanged: (v) async {
          await HomePrefs.setBottomBar(v);
          if (mounted) setState(() => _tab = 0);
        },
      ),
    ),
  );

  String get _kindsLabel =>
      [if (_teacher) 'Giảng viên', if (_staff) 'Văn phòng'].join(' · ');

  Widget _profile({bool asPage = false}) {
    final code = _vm != null && _vm!.teacherCode != '–'
        ? 'Mã GV ${_vm!.teacherCode} · $_kindsLabel'
        : _kindsLabel;
    final tab = ProfileTab(
      name: _name,
      code: code,
      onOpenInfo: _teacher
          ? () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GvProfileInfoScreen(
                  profile: _vm?.profile,
                  fallbackName: _name,
                  teacherCode: _vm?.teacherCode ?? '',
                ),
              ),
            )
          : null,
      onLogout: _logout,
    );
    if (!asPage) return tab;
    return Scaffold(
      appBar: AppBar(title: const Text('Tài khoản')),
      body: tab,
    );
  }

  Future<void> _logout() async {
    if (_vm != null) {
      await _vm!.logout();
    } else {
      await _s.clear();
    }
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final vd = context.vd;
    return ValueListenableBuilder<bool>(
      valueListenable: HomePrefs.bottomBar,
      builder: (context, bar, _) {
        final showProfile = bar && _tab == 1;
        final listen = _vm == null ? null : _vm!;
        Widget body() => showProfile ? _profile() : _homeBody();
        return Scaffold(
          backgroundColor: vd.bg,
          body: PageTransitionSwitcher(
            duration: VdMotion.of(context).standard,
            transitionBuilder: (child, primary, secondary) =>
                FadeThroughTransition(
                  animation: primary,
                  secondaryAnimation: secondary,
                  fillColor: vd.bg,
                  child: child,
                ),
            child: KeyedSubtree(
              key: ValueKey(showProfile),
              child: listen == null
                  ? body()
                  : ListenableBuilder(
                      listenable: listen,
                      builder: (_, _) => body(),
                    ),
            ),
          ),
          bottomNavigationBar: bar
              ? GvBottomNav(
                  currentIndex: _tab,
                  onSelect: (i) => setState(() => _tab = i),
                )
              : null,
        );
      },
    );
  }
}
