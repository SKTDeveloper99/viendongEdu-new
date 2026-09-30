import 'package:flutter/material.dart';

import '../class_models.dart';
import '../../../theme/vd_tokens.dart';

/// Orange header of the classes list: back arrow, title and the semester
/// dropdown (shown once the semesters have loaded).
class ClassesHeader extends StatelessWidget {
  final bool loading;
  final List<ClassSemester> semesters;
  final ClassSemester? selected;
  final ValueChanged<ClassSemester> onSelected;

  const ClassesHeader({
    super.key,
    required this.loading,
    required this.semesters,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [context.vd.primary, context.vd.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(Icons.arrow_back_ios,
                    color: context.vd.onPrimary, size: 20),
              ),
              const SizedBox(width: 8),
              Text(
                'Lớp học',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: context.vd.onPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const SizedBox(height: 16),
          if (!loading && semesters.isNotEmpty) _dropdown(context),
        ],
      ),
    );
  }

  Widget _dropdown(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 14, right: 6, top: 6, bottom: 6),
      decoration: BoxDecoration(
        color: context.vd.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: context.vd.shadow, blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ClassSemester>(
          value: selected,
          dropdownColor: context.vd.surface,
          borderRadius: BorderRadius.circular(14),
          iconEnabledColor: context.vd.primary,
          icon: const Icon(Icons.expand_more_rounded, size: 20),
          isDense: true,
          style: TextStyle(
              color: context.vd.ink,
              fontSize: 13,
              fontWeight: FontWeight.w500),
          selectedItemBuilder: (_) => semesters
              .map((s) => Center(
                    child: Text(s.ten,
                        style: TextStyle(
                            color: context.vd.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ))
              .toList(),
          items: semesters
              .map((s) => DropdownMenuItem(value: s, child: Text(s.ten)))
              .toList(),
          onChanged: (s) {
            if (s != null) onSelected(s);
          },
        ),
      ),
    );
  }
}
