import 'package:flutter/material.dart';

import '../class_models.dart';
import 'class_card.dart';

/// Count line plus the pull-to-refresh list of class cards.
class ClassList extends StatelessWidget {
  final List<ClassItem> classes;
  final String semTen;
  final Future<void> Function() onRefresh;

  const ClassList({
    super.key,
    required this.classes,
    required this.semTen,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Row(
            children: [
              Text(
                '${classes.length} lớp học',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: onRefresh,
            color: const Color(0xFFE65100),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: classes.length,
              itemBuilder: (context, i) =>
                  ClassCard(item: classes[i], semTen: semTen),
            ),
          ),
        ),
      ],
    );
  }
}
