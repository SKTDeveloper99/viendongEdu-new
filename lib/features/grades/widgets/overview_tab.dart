import 'package:flutter/material.dart';
import '../../../components/vd_fade_in.dart';
import '../../../models/crm_student_graduation_summary.dart';
import '../grade_item.dart';
import 'grade_progress.dart';
import 'grade_distribution.dart';
import 'mini_stat.dart';
import '../../../theme/vd_motion.dart';
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
    final tcChuaDiem = ((s?.total ?? 0) - (s?.scored ?? 0)).clamp(0, 1 << 30);
    final tcKhongDat = s?.failed ?? 0;
    final progress = tcTong > 0 ? (tcDat / tcTong).clamp(0.0, 1.0) : 0.0;
    final noCurriculum =
        s != null && !s.hasCurriculum; // progress unknown, not 0/0

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Hero card ──
          VdFadeIn(
            index: 0,
            child: Container(
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
              child: Flex(
                direction:
                    MediaQuery.sizeOf(context).width < 360 ||
                        MediaQuery.textScalerOf(context).scale(1) > 1.2
                    ? Axis.vertical
                    : Axis.horizontal,
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    flex:
                        MediaQuery.sizeOf(context).width < 360 ||
                            MediaQuery.textScalerOf(context).scale(1) > 1.2
                        ? 0
                        : 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ĐTB Tích lũy',
                          style: TextStyle(
                            color: context.vd.onPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(
                            begin: 0,
                            end: tbTichLuy.toDouble(),
                          ),
                          duration: VdMotion.of(context).countUp,
                          curve: VdMotion.curve,
                          builder: (context, v, _) => Text(
                            v.toStringAsFixed(2),
                            style: TextStyle(
                              color: context.vd.onPrimary,
                              fontSize: 52,
                              fontWeight: FontWeight.bold,
                              height: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: context.vd.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Tổng kết: ${tbTichLuy.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: context.vd.onPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Icon(
                              Icons.school_outlined,
                              color: context.vd.onPrimary,
                              size: 14,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                noCurriculum
                                    ? 'Chưa có chương trình đào tạo'
                                    : '$tcDat / $tcTong môn đạt',
                                style: TextStyle(
                                  color: context.vd.onPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Circular progress
                  GradeProgress(progress: progress, noCurriculum: noCurriculum),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── Mini stat row ──
          VdFadeIn(
            index: 1,
            child: Row(
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
          ),
          const SizedBox(height: 16),

          // ── Grade distribution (donut + legend) ──
          VdFadeIn(index: 2, child: GradeDistribution(grades: grades)),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
