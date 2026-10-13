import 'package:flutter/material.dart';

import '../../data/teacher_students_repository.dart';
import '../../screens/stale_note.dart';
import '../../services/crm_session_guard.dart';
import '../../theme/vd_tokens.dart';
import 'class_students_screen.dart';
import 'teacher_students_view_model.dart';
import 'widgets/care_layout.dart';
import 'widgets/care_state_views.dart';
import 'widgets/care_summary.dart';

/// "Sinh viên của tôi" — level 1 of the teacher view: the two counts and
/// "Lớp của tôi". Layout only; state lives in [TeacherStudentsViewModel].
class TeacherStudentsScreen extends StatefulWidget {
  /// Tests may inject a view model; otherwise the screen owns its own.
  final TeacherStudentsViewModel? viewModel;
  const TeacherStudentsScreen({super.key, this.viewModel});

  @override
  State<TeacherStudentsScreen> createState() => _TeacherStudentsScreenState();
}

class _TeacherStudentsScreenState extends State<TeacherStudentsScreen> {
  late final TeacherStudentsViewModel _vm;
  late final bool _ownsViewModel;
  bool _authHandled = false;

  @override
  void initState() {
    super.initState();
    _ownsViewModel = widget.viewModel == null;
    _vm =
        widget.viewModel ??
        TeacherStudentsViewModel(const TeacherStudentsRepository());
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

  void _open(CareClass cls) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClassStudentsScreen(
          careClass: cls,
          savedAt: _vm.savedAt,
          staleSince: _vm.staleSince,
        ),
      ),
    );
  }

  List<Widget> _content() {
    if (_vm.loading) return const [CareLoadingView()];
    final error = _vm.error;
    if (error != null && _vm.students.isEmpty) {
      return [CareMessageView(message: error, onRetry: _vm.load)];
    }
    if (_vm.students.isEmpty) {
      return const [
        CareMessageView(
          message: 'Chưa có sinh viên nào trong danh sách theo dõi của bạn.',
        ),
      ];
    }
    return [
      if (error != null) CareMessageView(message: error, onRetry: _vm.load),
      CareSummary(owing: _vm.owingCount, attention: _vm.attentionCount),
      const SizedBox(height: 20),
      const Text(
        'Lớp của tôi',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 10),
      for (final c in _vm.classes)
        CareRow(
          title: c.title,
          meta: [
            if (c.code != null && c.code != c.title) c.code!,
            '${c.students.length} sinh viên',
          ].join(' · '),
          onTap: () => _open(c),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.vd.bg,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _vm,
          builder: (context, _) => RefreshIndicator(
            onRefresh: _vm.load,
            color: context.vd.primary,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              children: [
                const CareBackHeader(
                  backLabel: 'Trang chủ',
                  title: 'Sinh viên của tôi',
                ),
                if (_vm.staleSince != null)
                  StaleNote(_vm.staleSince!, fontSize: 16),
                if (_vm.refreshing && !_vm.loading)
                  const LinearProgressIndicator(),
                const SizedBox(height: 14),
                ..._content(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
