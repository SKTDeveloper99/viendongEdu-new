import 'dart:async';
import 'dart:math' as math;

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import '../../components/home_header_bar.dart';
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
import 'app_me_api.dart';
import '../teacher_attendance/attendance_outbox.dart';
import '../teacher_home/next_up.dart';
import '../teacher_home/teacher_home_view_model.dart';
import '../teacher_home/widgets/gv_bottom_nav.dart';
import '../teacher_home/widgets/profile_tab.dart';
import '../../screens/gv_profile_info_screen.dart';
import '../work/my_work_screen.dart';
import '../work/piece_screen.dart';
import '../work/work_api.dart';
import 'day_card.dart';
import 'home_prefs.dart';
import 'home_widgets.dart';
import 'hub_screens.dart';
import '../notices/notice_screens.dart';

part 'work_home_screen_parts_1.dart';
part 'work_home_screen_parts_2.dart';

/// THE SWITCH for the owner's choice (open 2026-11-17): true = a tall phone
/// lists the next few pieces ("Tiếp theo") under the focus card; false =
/// no list, the home is only header, focus card, + Tạo and the tiles.
/// Change the default here (or build with --dart-define=HOME_NEXT_LIST=false).
const bool homeShowsNextList = bool.fromEnvironment(
  'HOME_NEXT_LIST',
  defaultValue: true,
);

/// One home for teachers, office accounts and accounts that are both
/// (Overlord slice, agreed with the chief of staff 2026-11-16): the header the
/// app already has, one focus card, at most six places, one "+ Giao việc";
/// a two-tab bar (Trang chủ · Cá nhân) unless the debug switch turns it off.
class WorkHomeScreen extends StatefulWidget {
  const WorkHomeScreen({super.key});

  @override
  State<WorkHomeScreen> createState() => _WorkHomeScreenState();
}

class _WorkHomeScreenState extends State<WorkHomeScreen>
    with WidgetsBindingObserver {
  TeacherHomeViewModel? _vm;

  Map<String, dynamic>? _me;

  /// My own parts (`GET /v1/tasks/my`): the home counts and lists only what
  /// can still be handed in, as the web does (the server's counts also hold
  /// parts locked under "Không hoàn thành").
  List<Map<String, dynamic>>? _mine;

  int _messages = 0;

  int _tab = 0;

  bool _authHandled = false;
  bool _signingOut = false;

  @override
  void initState() {
    super.initState();
    if (_teacher) {
      _vm = TeacherHomeViewModel(const TeacherHomeRepository())..start();
      _vm!.addListener(_onVm);
      AttendanceOutbox.instance.start();
    }
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  // Back to the front: counts, the next class and the day card are fresh
  // again, as the old teacher home did (review 2026-11-17).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    _refresh();
    _vm?.loadOverview();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _vm?.removeListener(_onVm);
    _vm?.stopClock();
    if (_vm != null) AttendanceOutbox.instance.stop();
    _vm?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vd = context.vd;
    final showProfile = _tab == 1;
    final listen = _vm;
    Widget body() => showProfile ? _profile() : _homeBody();
    return Scaffold(
      backgroundColor: vd.bg,
      body: PageTransitionSwitcher(
        duration: VdMotion.of(context).standard,
        transitionBuilder: (child, primary, secondary) => FadeThroughTransition(
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
      // Owner 2026-11-16: the two-tab bar stays on every home.
      bottomNavigationBar: GvBottomNav(
        currentIndex: _tab,
        onSelect: (i) => setState(() => _tab = i),
      ),
    );
  }

  // Lets the extensions in this library's parts call setState.
  void _set(VoidCallback f) => setState(f);
}
