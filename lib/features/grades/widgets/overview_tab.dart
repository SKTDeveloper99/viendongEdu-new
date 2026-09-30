import 'package:flutter/material.dart';
import '../../../models/crm_student_graduation_summary.dart';
import '../grade_item.dart';
import 'circular_arc.dart';
import 'grade_distribution.dart';
import 'mini_stat.dart';
import '../../../theme/vd_tokens.dart';

// ── Overview Tab ─────────────────────────────────────────
//
// Every number here comes straight from CrmAcademicSummary
// (GET /api/student/me/graduation-summary → `academic`) — no client-side
// arithmetic. It counts SUBJECTS (grade rows / curriculum rows), not
// tín chỉ: the server's summarizeGrades() never sums `credits`, so "X/Y" is
// môn (subjects), not credit-hours. See
// docs/ims_to_crm_student_academic_map.md.
class OverviewTab extends StatelessWidget {
  final CrmAcademicSummary? stats;
  final List<GradeItem> grades;

  const OverviewTab({super.key, required this.stats, required this.grades});

  @override
  Widget build(BuildContext context) {
    final s = stats;
    final tcDat = s?.requiredPassed ?? 0;
    final tcTong = s?.requiredSubjects ?? 0;
    final tbTichLuy = s?.averageScore ?? 0;
    final tbTongKet = s?.averageScore ?? 0;
    final tcChuaDiem = ((s?.total ?? 0) - (s?.scored ?? 0)).clamp(0, 1 << 30);
    final tcKhongDat = s?.failed ?? 0;
    final progress = tcTong > 0 ? (tcDat / tcTong).clamp(0.0, 1.0) : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Hero card ──
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [context.vd.primary, context.vd.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: context.vd.primary.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ĐTB Tích lũy',
                          style: TextStyle(
                              color: context.vd.onPrimary.withValues(alpha: 0.7),
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text(
                        tbTichLuy.toStringAsFixed(2),
                        style: TextStyle(
                          color: context.vd.onPrimary,
                          fontSize: 52,
                          fontWeight: FontWeight.bold,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: context.vd.onPrimary.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Tổng kết: ${tbTongKet.toStringAsFixed(2)}',
                          style: TextStyle(
                              color: context.vd.onPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Icon(Icons.school_outlined,
                              color: context.vd.onPrimary.withValues(alpha: 0.7), size: 14),
                          const SizedBox(width: 5),
                          Text(
                            '$tcDat / $tcTong môn đạt',
                            style: TextStyle(
                                color: context.vd.onPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Circular progress
                SizedBox(
                  width: 96,
                  height: 96,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularArc(
                        value: progress,
                        size: 96,
                        trackColor: context.vd.onPrimary.withValues(alpha: 0.2),
                        progressColor: context.vd.onPrimary,
                        strokeWidth: 9,
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${(progress * 100).toInt()}%',
                            style: TextStyle(
                              color: context.vd.onPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text('hoàn thành',
                              style: TextStyle(
                                  color: context.vd.onPrimary.withValues(alpha: 0.7), fontSize: 9)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Mini stat row ──
          Row(
            children: [
              MiniStat(
                label: 'Môn đã học',
                value: '${grades.length}',
                icon: Icons.menu_book_outlined,
                color: context.vd.info,
              ),
              const SizedBox(width: 10),
              MiniStat(
                label: 'Không đạt',
                value: '$tcKhongDat môn',
                icon: Icons.cancel_outlined,
                color: context.vd.danger,
              ),
              const SizedBox(width: 10),
              MiniStat(
                label: 'Chưa có điểm',
                value: '$tcChuaDiem môn',
                icon: Icons.hourglass_empty,
                color: context.vd.primary,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Grade distribution (donut + legend) ──
          GradeDistribution(grades: grades),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

