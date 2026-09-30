import 'package:flutter/material.dart';

import '../../data/student_home_repository.dart';
import '../../screens/student_board_screen.dart';
import '../../services/crm_session_guard.dart';
import '../../theme/vd_theme.dart';
import 'student_home_view_model.dart';
import 'widgets/dashboard_tab.dart';
import 'widgets/home_bottom_nav.dart';
import 'widgets/profile_tab.dart';
import 'widgets/qr_tab.dart';

/// Student home ("Trang chủ") with three tabs: dashboard, QR and profile.
/// Layout, navigation and dialogs only; state lives in
/// [StudentHomeViewModel].
class HomeScreen extends StatefulWidget {
  /// Tests may inject a view model; otherwise the screen owns its own.
  final StudentHomeViewModel? viewModel;
  const HomeScreen({super.key, this.viewModel});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late final StudentHomeViewModel _vm;
  late final bool _ownsViewModel;
  int _currentIndex = 0;
  bool _scheduleExpanded = true;
  bool _authHandled = false;

  @override
  void initState() {
    super.initState();
    _ownsViewModel = widget.viewModel == null;
    _vm =
        widget.viewModel ?? StudentHomeViewModel(const StudentHomeRepository());
    _vm.addListener(_onChanged);
    _vm.start();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _vm.removeListener(_onChanged);
    if (_ownsViewModel) _vm.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _vm.loadBoard();
  }

  // A 401 clears the session and returns to the login screen; a pending
  // "must read" prompt pushes the board once, then reloads it.
  void _onChanged() {
    if (_vm.unauthorized) {
      if (!_authHandled && mounted) {
        _authHandled = true;
        handleCrmAuthError(context, _vm.authError!);
      }
    } else {
      _authHandled = false;
    }
    if (_vm.takeMustReadPrompt()) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const StudentBoardScreen()),
        );
        _vm.loadBoard();
      });
    }
  }

  Future<void> _logout() async {
    await _vm.logout();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/');
  }

  Widget _tab() => switch (_currentIndex) {
    0 => DashboardTab(
      vm: _vm,
      scheduleExpanded: _scheduleExpanded,
      onToggleExpanded: () =>
          setState(() => _scheduleExpanded = !_scheduleExpanded),
    ),
    1 => QrTab(vm: _vm),
    _ => ProfileTab(vm: _vm, onLogout: _logout),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VdColors.cream,
      body: ListenableBuilder(listenable: _vm, builder: (_, _) => _tab()),
      bottomNavigationBar: HomeBottomNav(
        currentIndex: _currentIndex,
        onSelect: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}
