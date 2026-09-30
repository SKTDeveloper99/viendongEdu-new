import 'package:flutter/material.dart';

import '../class_manager_models.dart';

/// Orange header: back arrow, title, class-count pill and semester dropdown.
class ClassManagerHeader extends StatelessWidget {
  final bool loadingSemesters;
  final bool loadingClasses;
  final int classCount;
  final List<ClassSemester> semesters;
  final ClassSemester? selected;
  final ValueChanged<ClassSemester> onSelected;

  const ClassManagerHeader({
    super.key,
    required this.loadingSemesters,
    required this.loadingClasses,
    required this.classCount,
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
                child: const Icon(
                  Icons.arrow_back_ios,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Quản lý lớp',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              if (!loadingSemesters && !loadingClasses && classCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$classCount lớp',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          if (!loadingSemesters && semesters.isNotEmpty) ...[
            const SizedBox(height: 14),
            _SemesterDropdown(
              semesters: semesters,
              selected: selected,
              onSelected: onSelected,
            ),
          ],
        ],
      ),
    );
  }
}

class _SemesterDropdown extends StatelessWidget {
  final List<ClassSemester> semesters;
  final ClassSemester? selected;
  final ValueChanged<ClassSemester> onSelected;
  const _SemesterDropdown({
    required this.semesters,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 14, right: 6, top: 6, bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
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
            fontWeight: FontWeight.w500,
          ),
          selectedItemBuilder: (_) => semesters
              .map(
                (s) => Center(
                  child: Text(
                    s.ten,
                    style: const TextStyle(
                      color: Color(0xFFE65100),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
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
