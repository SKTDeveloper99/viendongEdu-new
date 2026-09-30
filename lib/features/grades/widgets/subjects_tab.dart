import 'package:flutter/material.dart';
import '../grade_item.dart';
import 'remaining_subjects_tab.dart';
import 'unscored_subjects_tab.dart';
import '../../../theme/vd_tokens.dart';

// ── Môn học Tab (gộp Chưa có điểm + Chưa học) ────────────
class SubjectsTab extends StatefulWidget {
  final List<GradeItem> chuaDiem;
  final List<RemainingSubjectItem> chuaHoc;
  const SubjectsTab({super.key, required this.chuaDiem, required this.chuaHoc});

  @override
  State<SubjectsTab> createState() => _SubjectsTabState();
}

class _SubjectsTabState extends State<SubjectsTab> {
  int _selected = 0; // 0 = Chưa có điểm, 1 = Chưa học

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Toggle chips
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: SubjectFilterChip(
                  label: 'Chưa có điểm',
                  count: widget.chuaDiem.length,
                  selected: _selected == 0,
                  onTap: () => setState(() => _selected = 0),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SubjectFilterChip(
                  label: 'Chưa học',
                  count: widget.chuaHoc.length,
                  selected: _selected == 1,
                  onTap: () => setState(() => _selected = 1),
                ),
              ),
            ],
          ),
        ),
        // Content
        Expanded(
          child: _selected == 0
              ? UnscoredSubjectsTab(items: widget.chuaDiem)
              : RemainingSubjectsTab(items: widget.chuaHoc),
        ),
      ],
    );
  }
}

class SubjectFilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  const SubjectFilterChip({super.key, required this.label, required this.count, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = context.vd.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : context.vd.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : context.vd.hairline),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? context.vd.onPrimary : context.vd.inkMuted,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: selected ? context.vd.onPrimary.withValues(alpha: 0.25) : context.vd.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: selected ? context.vd.onPrimary : context.vd.inkMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

