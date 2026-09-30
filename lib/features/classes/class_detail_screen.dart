import 'package:flutter/material.dart';

import '../../data/classes_repository.dart';
import '../../services/crm_session_guard.dart';
import 'class_detail_view_model.dart';
import 'class_models.dart';
import 'widgets/attendance_card.dart';
import 'widgets/class_detail_header.dart';
import 'widgets/class_grade_card.dart';
import 'widgets/class_info_card.dart';
import 'widgets/session_list_card.dart';
import '../../theme/vd_tokens.dart';

/// Detail page of one class: info, scores and EMS attendance. Layout only;
/// attendance state lives in [ClassDetailViewModel].
class ClassDetailScreen extends StatefulWidget {
  final ClassItem item;
  final String semTen;

  /// Tests may inject a view model; otherwise the screen owns its own.
  final ClassDetailViewModel? viewModel;
  const ClassDetailScreen(
      {super.key, required this.item, required this.semTen, this.viewModel});

  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen> {
  late final ClassDetailViewModel _vm;
  late final bool _ownsViewModel;
  bool _authHandled = false;

  @override
  void initState() {
    super.initState();
    _ownsViewModel = widget.viewModel == null;
    _vm = widget.viewModel ??
        ClassDetailViewModel(const ClassesRepository(),
            sectionCode: widget.item.lmhma);
    _vm.addListener(_onChanged);
    _vm.load();
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
    if (_vm.loading) {
      return Center(
          child: CircularProgressIndicator(color: context.vd.primary));
    }
    final item = widget.item;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          ClassInfoCard(item: item),
          const SizedBox(height: 16),
          if (item.hasGrades) ...[
            ClassGradeCard(item: item),
            const SizedBox(height: 16),
          ],
          if (_vm.sessions.isNotEmpty) ...[
            AttendanceCard(
              total: _vm.sessions.length,
              present: _vm.present,
              absent: _vm.absent,
              pending: _vm.pending,
            ),
            const SizedBox(height: 16),
            SessionListCard(sessions: _vm.sessions),
          ],
        ],
      ),
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
            ClassDetailHeader(title: widget.item.mhten, semTen: widget.semTen),
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
