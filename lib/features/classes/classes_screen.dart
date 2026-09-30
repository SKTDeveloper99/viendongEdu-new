import 'package:flutter/material.dart';

import '../../components/skeleton.dart';
import '../../data/classes_repository.dart';
import '../../services/crm_session_guard.dart';
import 'classes_view_model.dart';
import 'widgets/class_list.dart';
import 'widgets/classes_header.dart';
import 'widgets/classes_state_views.dart';

/// "Lớp học" — the student's classes per semester (newest first), with
/// scores. Layout only; state lives in [ClassesViewModel].
class ClassesScreen extends StatefulWidget {
  /// Tests may inject a view model; otherwise the screen owns its own.
  final ClassesViewModel? viewModel;
  const ClassesScreen({super.key, this.viewModel});

  @override
  State<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends State<ClassesScreen> {
  late final ClassesViewModel _vm;
  late final bool _ownsViewModel;
  bool _authHandled = false;

  @override
  void initState() {
    super.initState();
    _ownsViewModel = widget.viewModel == null;
    _vm = widget.viewModel ?? ClassesViewModel(const ClassesRepository());
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
    const accent = Color(0xFFE65100);
    if (_vm.loading) return skeletonList(accentColor: accent);
    final error = _vm.error;
    if (error != null) {
      return ClassesErrorView(message: error, onRetry: _vm.fetchSemesters);
    }
    if (_vm.loadingClasses) return skeletonList(accentColor: accent);
    if (_vm.classes.isEmpty) return const ClassesEmptyView();
    return ClassList(
      classes: _vm.classes,
      semTen: _vm.selected?.ten ?? '',
      onRefresh: _vm.refreshSelected,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: _vm,
          builder: (context, _) => Column(
            children: [
              ClassesHeader(
                loading: _vm.loading,
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
