import 'package:flutter/material.dart';
import '../../../theme/vd_motion.dart';
import '../../../theme/vd_tokens.dart';
import 'circular_arc.dart';

/// Server-backed curriculum progress; unknown is never completion.
class CurriculumProgress extends StatelessWidget {
  final double progress;
  final bool known;
  const CurriculumProgress({
    super.key,
    required this.progress,
    required this.known,
  });

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween<double>(begin: 0, end: progress),
    duration: VdMotion.of(context).countUp,
    curve: VdMotion.curve,
    builder: (context, p, _) => SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularArc(
            value: p,
            size: 96,
            trackColor: context.vd.onPrimary.withValues(alpha: 0.2),
            progressColor: context.vd.onPrimary,
            strokeWidth: 9,
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                !known ? '—' : '${(p * 100).toInt()}%',
                style: TextStyle(
                  color: context.vd.onPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'hoàn thành',
                style: TextStyle(
                  color: context.vd.onPrimary.withValues(alpha: 0.7),
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
