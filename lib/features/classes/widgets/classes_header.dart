import 'package:flutter/material.dart';

import '../class_models.dart';

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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE65100), Color(0xFFFF8C00)],
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
                child: const Icon(Icons.arrow_back_ios,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 8),
              const Text(
                'Lớp học',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const SizedBox(height: 16),
          if (!loading && semesters.isNotEmpty) _dropdown(),
        ],
      ),
    );
  }

  Widget _dropdown() {
    return Container(
      padding: const EdgeInsets.only(left: 14, right: 6, top: 6, bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ClassSemester>(
          value: selected,
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(14),
          iconEnabledColor: const Color(0xFFE65100),
          icon: const Icon(Icons.expand_more_rounded, size: 20),
          isDense: true,
          style: const TextStyle(
              color: Color(0xFF333333),
              fontSize: 13,
              fontWeight: FontWeight.w500),
          selectedItemBuilder: (_) => semesters
              .map((s) => Center(
                    child: Text(s.ten,
                        style: const TextStyle(
                            color: Color(0xFFE65100),
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
