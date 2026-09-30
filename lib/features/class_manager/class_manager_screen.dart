import 'package:flutter/material.dart';

import '../../components/skeleton.dart';
import '../../data/class_manager_repository.dart';
import '../../services/crm_session_guard.dart';
import 'class_manager_view_model.dart';
import 'widgets/class_detail_sheet.dart';
import 'widgets/class_list.dart';
import 'widgets/class_manager_header.dart';
import 'widgets/class_manager_state_views.dart';
import '../../theme/vd_tokens.dart';

/// Teacher "Quản lý lớp" (read-only): classes per semester with a detail
/// sheet (info / students / attendance). Layout only; state lives in
/// [ClassManagerViewModel].
class GvQuanLyLopScreen extends StatefulWidget {
  /// Tests may inject a view model; otherwise the screen owns its own.
  final ClassManagerViewModel? viewModel;
  const GvQuanLyLopScreen({super.key, this.viewModel});

  @override
  State<GvQuanLyLopScreen> createState() => _GvQuanLyLopScreenState();
}

class _GvQuanLyLopScreenState extends State<GvQuanLyLopScreen> {
  late final ClassManagerViewModel _vm;
  late final bool _ownsViewModel;
  bool _authHandled = false;

  @override
  void initState() {
    super.initState();
    _ownsViewModel = widget.viewModel == null;
    _vm =
        widget.viewModel ??
        ClassManagerViewModel(const ClassManagerRepository());
    _vm.addListener(_onChanged);
    _vm.fetchSemesters();
  }

  @override
  void dispose() {
    _vm.removeListener(_onChanged);
    if (_ownsViewModel) _vm.dispose();
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
    if (_vm.loadingSemesters) return skeletonList();
    final error = _vm.error;
    if (error != null) {
      return ClassManagerErrorView(message: error, onRetry: _vm.retry);
    }
    if (_vm.loadingClasses) return skeletonList();
    if (_vm.classes.isEmpty) return const ClassManagerEmptyView();
    return ClassList(
      classes: _vm.classes,
      staleAt: _vm.staleAt,
      onOpen: (lop) => showClassDetailSheet(
        context,
        repository: _vm.repository,
        lop: lop,
        lmhId: _vm.lmhIdOf(lop),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.vd.bg,
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: _vm,
          builder: (context, _) => Column(
            children: [
              ClassManagerHeader(
                loadingSemesters: _vm.loadingSemesters,
                loadingClasses: _vm.loadingClasses,
                classCount: _vm.classes.length,
                semesters: _vm.semesters,
                selected: _vm.selected,
                onSelected: _vm.selectSemester,
              ),
              Expanded(child: _content()),
            ],
          ),
        ),
      ),
    );
  }
}
