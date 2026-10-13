import 'package:flutter/material.dart';

import '../../data/teacher_students_repository.dart';
import '../../models/teacher_care_student.dart';
import '../../screens/stale_note.dart';
import '../../services/crm_session_guard.dart';
import '../../theme/vd_tokens.dart';
import 'care_format.dart';
import 'student_detail_view_model.dart';
import 'widgets/academic_cards.dart';
import 'widgets/care_card.dart';
import 'widgets/care_layout.dart';
import 'widgets/money_card.dart';
import 'widgets/care_state_views.dart';

/// Level 3: one student — grades, attendance and tuition. Paints the row
/// from the list at once, then replaces it with the server's latest copy;
/// if that fails the list copy stays.
class StudentDetailScreen extends StatefulWidget {
  final TeacherCareStudent student;

  /// The class the teacher came from; empty = show every listed class.
  final String sectionId;
  final String backLabel;
  final DateTime? staleSince;
  final DateTime? savedAt;
  final TeacherStudentsRepository repository;

  const StudentDetailScreen({
    super.key,
    required this.student,
    required this.sectionId,
    required this.backLabel,
    this.staleSince,
    this.savedAt,
    this.repository = const TeacherStudentsRepository(),
  });

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  late final StudentDetailViewModel _vm;
  bool _authHandled = false;

  @override
  void initState() {
    super.initState();
    _vm = StudentDetailViewModel(
      widget.repository,
      widget.student,
      savedAt: widget.savedAt,
      staleSince: widget.staleSince,
    );
    _vm.addListener(_onChanged);
    _vm.refresh();
  }

  void _onChanged() {
    if (_vm.authError == null) {
      _authHandled = false;
    } else if (!_authHandled && mounted) {
      _authHandled = true;
      handleCrmAuthError(context, _vm.authError!);
    }
  }

  @override
  void dispose() {
    _vm.removeListener(_onChanged);
    _vm.dispose();
    super.dispose();
  }

  List<Widget> _academic() {
    final student = _vm.student;
    final one = widget.sectionId.isEmpty
        ? null
        : student.section(widget.sectionId);
    final sections = widget.sectionId.isEmpty ? student.sections : [?one];
    if (sections.isEmpty) {
      return const [
        CareCard(
          title: 'Điểm và chuyên cần',
          children: [CareLine('Tình trạng', unknownText)],
        ),
      ];
    }
    final many = widget.sectionId.isEmpty;
    return [
      for (final sec in sections) ...[
        GradesCard(
          section: sec,
          fresh: student.gradesFresh,
          title: many
              ? 'Điểm · ${sec.subjectName ?? sec.sectionCode ?? ''}'
              : 'Điểm môn này',
        ),
        AttendanceCard(
          section: sec,
          fresh: student.attendanceFresh,
          title: many
              ? 'Chuyên cần · ${sec.subjectName ?? sec.sectionCode ?? ''}'
              : 'Chuyên cần',
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.vd.bg,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _vm,
          builder: (context, _) {
            final s = _vm.student;
            return RefreshIndicator(
              onRefresh: _vm.refresh,
              color: context.vd.primary,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                children: [
                  CareBackHeader(
                    backLabel: widget.backLabel,
                    title: _vm.blocked
                        ? 'Hồ sơ sinh viên'
                        : s.name.isEmpty
                        ? s.mssv
                        : s.name,
                    subtitle: _vm.blocked
                        ? null
                        : [s.mssv, ?s.classCode].join(' · '),
                  ),
                  if (_vm.refreshing) const LinearProgressIndicator(),
                  if (_vm.error != null)
                    CareMessageView(message: _vm.error!, onRetry: _vm.refresh),
                  if (!_vm.blocked && _vm.staleSince != null)
                    StaleNote(_vm.staleSince!, fontSize: 16),
                  const SizedBox(height: 14),
                  if (!_vm.blocked) ...[
                    if (s.money.owes) const OweBanner(),
                    ..._academic(),
                    MoneyCard(money: s.money),
                    if (s.needsAttention)
                      CareCard(
                        title: 'Cần chú ý',
                        children: [
                          for (final r in s.attentionReasons)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                r,
                                style: const TextStyle(fontSize: 18),
                              ),
                            ),
                        ],
                      ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
