import 'package:flutter/material.dart';

import '../../data/teacher_students_repository.dart';
import '../../models/teacher_care_student.dart';
import '../../screens/stale_note.dart';
import '../../services/crm_session_guard.dart';
import '../../services/ems_api_service.dart';
import '../../theme/vd_tokens.dart';
import 'care_format.dart';
import 'widgets/academic_cards.dart';
import 'widgets/care_card.dart';
import 'widgets/care_layout.dart';
import 'widgets/money_card.dart';

/// Level 3: one student — grades, attendance and tuition. Paints the row
/// from the list at once, then replaces it with the server's latest copy;
/// if that fails the list copy stays.
class StudentDetailScreen extends StatefulWidget {
  final TeacherCareStudent student;

  /// The class the teacher came from; empty = show every listed class.
  final String sectionId;
  final String backLabel;
  final DateTime? staleSince;
  final TeacherStudentsRepository repository;

  const StudentDetailScreen({
    super.key,
    required this.student,
    required this.sectionId,
    required this.backLabel,
    this.staleSince,
    this.repository = const TeacherStudentsRepository(),
  });

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  late TeacherCareStudent _s = widget.student;
  late DateTime? _staleSince = widget.staleSince;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final fresh = await widget.repository.student(widget.student.mssv);
      if (!mounted || fresh.mssv != widget.student.mssv) return;
      setState(() {
        // The single-student copy keeps the teacher's class list from the
        // list call when it does not carry one.
        _s =
            fresh.mySectionIds.isEmpty && widget.student.mySectionIds.isNotEmpty
            ? TeacherCareStudent.fromJson({
                ...fresh.toJson(),
                'can_review_sections': widget.student.mySectionIds,
              })
            : fresh;
        _staleSince = null;
      });
    } on EmsException catch (e) {
      if (mounted && e.statusCode == 401) await handleCrmAuthError(context, e);
    } catch (_) {
      // Keep the list copy; it is already labelled when it is old.
    }
  }

  List<Widget> _academic() {
    final one = widget.sectionId.isEmpty ? null : _s.section(widget.sectionId);
    final sections = widget.sectionId.isEmpty ? _s.sections : [?one];
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
          fresh: _s.gradesFresh,
          title: many
              ? 'Điểm · ${sec.subjectName ?? sec.sectionCode ?? ''}'
              : 'Điểm môn này',
        ),
        AttendanceCard(
          section: sec,
          fresh: _s.attendanceFresh,
          title: many
              ? 'Chuyên cần · ${sec.subjectName ?? sec.sectionCode ?? ''}'
              : 'Chuyên cần',
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    return Scaffold(
      backgroundColor: context.vd.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: context.vd.primary,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: [
              CareBackHeader(
                backLabel: widget.backLabel,
                title: s.name.isEmpty ? s.mssv : s.name,
                subtitle: [s.mssv, ?s.classCode].join(' · '),
              ),
              if (_staleSince != null) StaleNote(_staleSince!),
              const SizedBox(height: 14),
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
                        child: Text(r, style: const TextStyle(fontSize: 18)),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
