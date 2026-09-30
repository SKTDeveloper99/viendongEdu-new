import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import '../../data/teacher_home_repository.dart';
import '../../screens/gv_profile_info_screen.dart';
import '../../services/crm_session_guard.dart';
import 'teacher_home_view_model.dart';
import 'widgets/gv_bottom_nav.dart';
import 'widgets/home_tab.dart';
import 'widgets/profile_tab.dart';
import '../../theme/vd_motion.dart';
import '../../theme/vd_tokens.dart';

/// Teacher home ("/gv_home") with two tabs: home and profile. Layout,
/// navigation and dialogs only; state lives in [TeacherHomeViewModel].
class GvHomeScreen extends StatefulWidget {
  /// Tests may inject a view model; otherwise the screen owns its own.
  final TeacherHomeViewModel? viewModel;
  const GvHomeScreen({super.key, this.viewModel});

  @override
  State<GvHomeScreen> createState() => _GvHomeScreenState();
}

class _GvHomeScreenState extends State<GvHomeScreen> {
  late final TeacherHomeViewModel _vm;
  late final bool _ownsViewModel;
  int _currentIndex = 0;
  bool _scheduleExpanded = true;
  bool _authHandled = false;

  @override
  void initState() {
    super.initState();
    _ownsViewModel = widget.viewModel == null;
    _vm =
        widget.viewModel ?? TeacherHomeViewModel(const TeacherHomeRepository());
    _vm.addListener(_onChanged);
    _vm.start();
  }

  @override
  void dispose() {
    _vm.removeListener(_onChanged);
    if (_ownsViewModel) _vm.dispose();
    super.dispose();
  }

  // A 401 clears the session and returns to the login screen.
  void _onChanged() {
    if (_vm.unauthorized) {
      if (!_authHandled && mounted) {
        _authHandled = true;
        handleCrmAuthError(context, _vm.authError!);
      }
    } else {
      _authHandled = false;
    }
  }

  Future<void> _logout() async {
    await _vm.logout();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/');
  }

  Future<void> _openBell() async {
    await Navigator.pushNamed(context, '/notifications');
    _vm.loadUnreadCount();
  }

  Future<void> _openProfileInfo() async {
    final name = _vm.displayName;
    final code = _vm.teacherCode;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GvProfileInfoScreen(
          profile: _vm.profile,
          fallbackName: name == '–' ? '' : name,
          teacherCode: code == '–' ? '' : code,
        ),
      ),
    );
    // Sửa hồ sơ (ProfileEditScreen) trả về true khi có thay đổi đã lưu — tải
    // lại overview để phần "Liên hệ" khớp dữ liệu mới.
    if (result == true) _vm.loadOverview();
  }

  Widget _tab() => switch (_currentIndex) {
    0 => HomeTab(
      vm: _vm,
      scheduleExpanded: _scheduleExpanded,
      onToggleExpanded: () =>
          setState(() => _scheduleExpanded = !_scheduleExpanded),
      onBell: _openBell,
    ),
    _ => ProfileTab(
      name: _vm.displayName,
      code: _vm.teacherCode,
      onOpenInfo: _openProfileInfo,
      onLogout: _logout,
    ),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.vd.bg,
      body: PageTransitionSwitcher(
        duration: VdMotion.of(context).standard,
        transitionBuilder: (child, primary, secondary) => FadeThroughTransition(
          animation: primary,
          secondaryAnimation: secondary,
          fillColor: context.vd.bg,
          child: child,
        ),
        child: KeyedSubtree(
          key: ValueKey<int>(_currentIndex),
          child: ListenableBuilder(listenable: _vm, builder: (_, _) => _tab()),
        ),
      ),
      bottomNavigationBar: GvBottomNav(
        currentIndex: _currentIndex,
        onSelect: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}
