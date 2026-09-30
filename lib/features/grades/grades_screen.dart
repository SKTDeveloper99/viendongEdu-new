import 'package:flutter/material.dart';

import '../../data/grades_repository.dart';
import '../../services/crm_session_guard.dart';
import 'grades_view_model.dart';
import 'widgets/detail_tab.dart';
import 'widgets/grades_error_view.dart';
import 'widgets/grades_header.dart';
import 'widgets/overview_tab.dart';
import 'widgets/subjects_tab.dart';
import '../../theme/vd_tokens.dart';

/// "Bảng điểm" — read-only grades: overview, per-subject detail, subjects
/// still to study. Layout only; state lives in [GradesViewModel].
class GradesScreen extends StatefulWidget {
  /// Tests may inject a view model; otherwise the screen owns its own.
  final GradesViewModel? viewModel;
  const GradesScreen({super.key, this.viewModel});

  @override
  State<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends State<GradesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final GradesViewModel _vm;
  late final bool _ownsViewModel;
  bool _authHandled = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _ownsViewModel = widget.viewModel == null;
    _vm = widget.viewModel ?? GradesViewModel(const GradesRepository());
    _vm.addListener(_onChanged);
    _vm.refresh();
  }

  @override
  void dispose() {
    _vm.removeListener(_onChanged);
    if (_ownsViewModel) _vm.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // A 401 clears the session and returns to the login screen.
  void _onChanged() {
    if (!_vm.unauthorized) {
      _authHandled = false;
      return;
    }
    if (_authHandled || !mounted) return;
    _authHandled = true;
    handleCrmAuthError(context, _vm.authError!);
  }

  Widget _content() {
    if (_vm.loading) {
      return Center(
          child: CircularProgressIndicator(color: context.vd.primary));
    }
    final error = _vm.error;
    if (error != null) {
      return GradesErrorView(message: error, onRetry: _vm.refresh);
    }
    return TabBarView(
      controller: _tabController,
      children: [
        OverviewTab(stats: _vm.stats, grades: _vm.grades),
        DetailTab(grades: _vm.grades),
        SubjectsTab(chuaDiem: _vm.ungraded, chuaHoc: _vm.remaining),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.vd.bg,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            GradesHeader(controller: _tabController),
            Expanded(
              child: ListenableBuilder(
                listenable: _vm,
                builder: (context, _) => _content(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
