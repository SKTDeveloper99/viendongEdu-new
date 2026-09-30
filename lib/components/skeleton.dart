import 'package:flutter/material.dart';
import '../theme/vd_tokens.dart';

/// Một ô shimmer đơn lẻ, tự động animate.
class Skeleton extends StatefulWidget {
  final double width;
  final double height;
  final double radius;
  const Skeleton({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.radius = 8,
  });

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _anim = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            begin: Alignment(_anim.value - 1, 0),
            end: Alignment(_anim.value + 1, 0),
            colors: [
              context.vd.hairline,
              context.vd.surfaceAlt,
              context.vd.hairline,
            ],
          ),
        ),
      ),
    );
  }
}

/// Card skeleton dùng cho màn hình danh sách (lớp học, lịch thi, lịch dạy…)
class SkeletonCard extends StatelessWidget {
  final Color? accentColor;
  const SkeletonCard({super.key, this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.vd.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: context.vd.shadow, blurRadius: 6, offset: Offset(0, 3)),
        ],
        border: Border(left: BorderSide(color: (accentColor ?? context.vd.primary).withValues(alpha: 0.3), width: 5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Skeleton(height: 15, radius: 6)),
                const SizedBox(width: 12),
                Skeleton(width: 48, height: 22, radius: 11),
              ],
            ),
            const SizedBox(height: 12),
            Skeleton(height: 12, radius: 6),
            const SizedBox(height: 8),
            Skeleton(width: 180, height: 12, radius: 6),
            const SizedBox(height: 8),
            Skeleton(width: 130, height: 12, radius: 6),
          ],
        ),
      ),
    );
  }
}

/// Chip skeleton dùng cho lịch học hôm nay ở home screen
class SkeletonChip extends StatelessWidget {
  const SkeletonChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.vd.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: context.vd.shadow, blurRadius: 6, offset: Offset(0, 3)),
        ],
        border: Border(
            left: BorderSide(color: context.vd.hairline, width: 5)),
      ),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Skeleton(width: 36, height: 16, radius: 6),
              const SizedBox(height: 4),
              Skeleton(width: 36, height: 13, radius: 6),
            ],
          ),
          const SizedBox(width: 14),
          Container(width: 1, height: 44, color: context.vd.hairline),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(height: 15, radius: 6),
                const SizedBox(height: 8),
                Skeleton(width: 160, height: 12, radius: 6),
                const SizedBox(height: 6),
                Skeleton(width: 220, height: 12, radius: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dùng để build nhanh danh sách skeleton cards
Widget skeletonList({int count = 4, Color? accentColor}) {
  return ListView.builder(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
    itemCount: count,
    itemBuilder: (_, __) => SkeletonCard(accentColor: accentColor),
  );
}
