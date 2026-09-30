import 'package:flutter/material.dart';

import '../../../models/crm_teacher_class.dart';
import '../../../screens/stale_note.dart';
import 'class_card.dart';

/// Stored-copy note (when set) above the scrolling list of class cards.
class ClassList extends StatelessWidget {
  final List<CrmTeacherClass> classes;
  final DateTime? staleAt;
  final ValueChanged<CrmTeacherClass> onOpen;
  const ClassList({
    super.key,
    required this.classes,
    required this.staleAt,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (staleAt != null) StaleNote(staleAt!),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: classes.length,
            itemBuilder: (ctx, i) =>
                ClassCard(lop: classes[i], onTap: () => onOpen(classes[i])),
          ),
        ),
      ],
    );
  }
}
