import 'package:flutter/material.dart';

import '../../screens/stale_note.dart';
import '../../theme/vd_tokens.dart';
import 'student_detail_screen.dart';
import 'teacher_students_view_model.dart';
import 'widgets/care_layout.dart';
import 'widgets/care_summary.dart';

/// Level 2: the students of one class, each with a small status.
class ClassStudentsScreen extends StatelessWidget {
  final CareClass careClass;

  /// Set when the list is the last good copy (offline).
  final DateTime? staleSince;
  const ClassStudentsScreen({
    super.key,
    required this.careClass,
    this.staleSince,
  });

  @override
  Widget build(BuildContext context) {
    final c = careClass;
    return Scaffold(
      backgroundColor: context.vd.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            CareBackHeader(
              backLabel: 'Sinh viên của tôi',
              title: c.title,
              subtitle: [
                if (c.code != null && c.code != c.title) c.code!,
                '${c.students.length} sinh viên',
              ].join(' · '),
            ),
            if (staleSince != null) StaleNote(staleSince!),
            const SizedBox(height: 14),
            for (final s in c.students)
              CareRow(
                title: s.name.isEmpty ? s.mssv : s.name,
                meta: s.mssv,
                pills: studentPills(s),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => StudentDetailScreen(
                      student: s,
                      sectionId: c.sectionId,
                      backLabel: c.title,
                      staleSince: staleSince,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
